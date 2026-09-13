import EventKit
import Flutter
import Foundation

/// Manages only external calendar copies explicitly created from JotCue blocks.
final class IOSScheduleCalendarBridge {
  private static let linksKey = "jotcue_schedule_calendar_links"

  private let store = EKEventStore()
  private let defaults = UserDefaults.standard
  private let channel: FlutterMethodChannel
  private var permissionResult: FlutterResult?

  init(messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(
      name: "com.tori.pulse/calendar_schedule",
      binaryMessenger: messenger
    )
    channel.setMethodCallHandler { [weak self] call, result in
      self?.handle(call: call, result: result)
    }
  }

  private func handle(call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "hasAccess":
      result(IOSCalendarAuthorization.hasFullAccess())
    case "requestAccess":
      requestAccess(result: result)
    case "isLinked":
      isLinked(call: call, result: result)
    case "upsert":
      upsert(call: call, result: result)
    case "remove":
      remove(call: call, result: result)
    case "detach":
      guard let blockId = blockId(call: call, result: result) else { return }
      removeLink(for: blockId)
      result(nil)
    case "detachAll":
      defaults.removeObject(forKey: Self.linksKey)
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func requestAccess(result: @escaping FlutterResult) {
    if IOSCalendarAuthorization.hasFullAccess() {
      result(true)
      return
    }
    if permissionResult != nil {
      result(FlutterError(
        code: "CALENDAR_BUSY",
        message: "Finish the current calendar permission request first.",
        details: nil
      ))
      return
    }
    permissionResult = result
    IOSCalendarAuthorization.requestFullAccess(store: store) { [weak self] granted, error in
      guard let self else { return }
      let pending = self.permissionResult
      self.permissionResult = nil
      if let error {
        pending?(FlutterError(
          code: "CALENDAR_PERMISSION",
          message: error.localizedDescription,
          details: nil
        ))
      } else {
        pending?(granted && IOSCalendarAuthorization.hasFullAccess())
      }
    }
  }

  private func isLinked(call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let blockId = blockId(call: call, result: result) else { return }
    guard let savedLink = link(for: blockId) else {
      result(false)
      return
    }
    guard IOSCalendarAuthorization.hasFullAccess() else {
      // Preserve fail-closed behavior when calendar access has been revoked.
      result(true)
      return
    }
    let linked = ownedEvent(for: savedLink) != nil
    if !linked { removeLink(for: blockId) }
    result(linked)
  }

  private func upsert(call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let blockId = blockId(call: call, result: result) else { return }
    guard IOSCalendarAuthorization.hasFullAccess() else {
      result(FlutterError(
        code: "CALENDAR_PERMISSION",
        message: "Calendar write access is required before adding a planned block.",
        details: nil
      ))
      return
    }

    do {
      if let savedLink = link(for: blockId), let event = ownedEvent(for: savedLink) {
        try populate(event: event, from: call, marker: savedLink.marker)
        try store.save(event, span: .thisEvent, commit: true)
        result(nil)
        return
      }
      removeLink(for: blockId)
      guard let calendar = store.defaultCalendarForNewEvents else {
        throw ScheduleCalendarError.invalid(
          "No writable calendar is available. Add a calendar account first."
        )
      }
      let marker = "jotcue://schedule-blocks/\(UUID().uuidString)"
      let event = EKEvent(eventStore: store)
      event.calendar = calendar
      try populate(event: event, from: call, marker: marker)
      try store.save(event, span: .thisEvent, commit: true)
      guard let eventIdentifier = event.eventIdentifier else {
        try? store.remove(event, span: .thisEvent, commit: true)
        throw ScheduleCalendarError.invalid("Calendar did not return an event identifier.")
      }
      saveLink(
        ScheduleCalendarLink(eventIdentifier: eventIdentifier, marker: marker),
        for: blockId
      )
      result(nil)
    } catch {
      fail(result, error)
    }
  }

  private func remove(call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let blockId = blockId(call: call, result: result) else { return }
    guard let savedLink = link(for: blockId) else {
      result(nil)
      return
    }
    guard IOSCalendarAuthorization.hasFullAccess() else {
      result(FlutterError(
        code: "CALENDAR_PERMISSION",
        message: "Calendar write access is required to remove the linked entry.",
        details: nil
      ))
      return
    }
    do {
      if let event = ownedEvent(for: savedLink) {
        try store.remove(event, span: .thisEvent, commit: true)
      }
      removeLink(for: blockId)
      result(nil)
    } catch {
      fail(result, error)
    }
  }

  private func populate(event: EKEvent, from call: FlutterMethodCall, marker: String) throws {
    guard
      let arguments = call.arguments as? [String: Any],
      let startsMillis = number(arguments["startsAt"]),
      let endsMillis = number(arguments["endsAt"]),
      endsMillis > startsMillis
    else {
      throw ScheduleCalendarError.invalid(
        "The planned block must end after it starts."
      )
    }
    event.title = (arguments["title"] as? String) ?? "JotCue focus block"
    event.notes = (arguments["description"] as? String)
      ?? "Planned with JotCue. Calendar edits are not automatically synced back to JotCue."
    event.startDate = Date(timeIntervalSince1970: startsMillis / 1000)
    event.endDate = Date(timeIntervalSince1970: endsMillis / 1000)
    event.timeZone = .current
    event.url = URL(string: marker)
    event.availability = .busy
  }

  private func ownedEvent(for link: ScheduleCalendarLink) -> EKEvent? {
    guard let event = store.event(withIdentifier: link.eventIdentifier) else { return nil }
    guard event.url?.absoluteString == link.marker else { return nil }
    return event
  }

  private func blockId(call: FlutterMethodCall, result: FlutterResult) -> String? {
    let id = (call.arguments as? [String: Any])?["blockId"] as? String
    guard let id, !id.isEmpty else {
      result(FlutterError(
        code: "INVALID_BLOCK",
        message: "A saved JotCue planning block is required.",
        details: nil
      ))
      return nil
    }
    return id
  }

  private func links() -> [String: [String: String]] {
    defaults.dictionary(forKey: Self.linksKey) as? [String: [String: String]] ?? [:]
  }

  private func link(for blockId: String) -> ScheduleCalendarLink? {
    guard let raw = links()[blockId] else { return nil }
    return ScheduleCalendarLink(raw)
  }

  private func saveLink(_ link: ScheduleCalendarLink, for blockId: String) {
    var values = links()
    values[blockId] = link.dictionary
    defaults.set(values, forKey: Self.linksKey)
  }

  private func removeLink(for blockId: String) {
    var values = links()
    values.removeValue(forKey: blockId)
    defaults.set(values, forKey: Self.linksKey)
  }

  private func number(_ value: Any?) -> Double? {
    if let number = value as? NSNumber { return number.doubleValue }
    if let value = value as? Double { return value }
    if let value = value as? Int64 { return Double(value) }
    if let value = value as? Int { return Double(value) }
    return nil
  }

  private func fail(_ result: FlutterResult, _ error: Error) {
    result(FlutterError(
      code: "CALENDAR_FAILED",
      message: error.localizedDescription,
      details: nil
    ))
  }

  func dispose() {
    channel.setMethodCallHandler(nil)
    permissionResult?(FlutterError(
      code: "CALENDAR_CANCELLED",
      message: "Calendar permission request was closed.",
      details: nil
    ))
    permissionResult = nil
  }
}

private struct ScheduleCalendarLink {
  let eventIdentifier: String
  let marker: String

  init(eventIdentifier: String, marker: String) {
    self.eventIdentifier = eventIdentifier
    self.marker = marker
  }

  init?(_ value: [String: String]) {
    guard
      let eventIdentifier = value["eventIdentifier"], !eventIdentifier.isEmpty,
      let marker = value["marker"], !marker.isEmpty
    else { return nil }
    self.eventIdentifier = eventIdentifier
    self.marker = marker
  }

  var dictionary: [String: String] {
    ["eventIdentifier": eventIdentifier, "marker": marker]
  }
}

private enum ScheduleCalendarError: LocalizedError {
  case invalid(String)

  var errorDescription: String? {
    switch self {
    case .invalid(let message): return message
    }
  }
}
