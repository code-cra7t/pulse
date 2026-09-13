import EventKit
import Flutter
import Foundation

/// Manages only calendar events JotCue explicitly linked to a saved reminder.
final class IOSReminderCalendarBridge {
  private static let linksKey = "jotcue_reminder_links"
  private static let pendingRemovalKey = "jotcue_pending_reminder_removals"

  private let store = EKEventStore()
  private let defaults = UserDefaults.standard
  private let channel: FlutterMethodChannel
  private var permissionCall: (FlutterMethodCall, FlutterResult)?

  init(messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(
      name: "com.tori.pulse/calendar",
      binaryMessenger: messenger
    )
    channel.setMethodCallHandler { [weak self] call, result in
      self?.handle(call: call, result: result)
    }
  }

  private func handle(call: FlutterMethodCall, result: @escaping FlutterResult) {
    if call.method == "retryPendingRemovals" {
      guard IOSCalendarAuthorization.hasFullAccess() else {
        result(nil)
        return
      }
      do {
        try retryPendingRemovals()
        result(nil)
      } catch {
        fail(result, error)
      }
      return
    }

    guard ["upsert", "updateLinked", "remove"].contains(call.method) else {
      result(FlutterMethodNotImplemented)
      return
    }
    guard let reminderId = stringArgument(call, "reminderId"), !reminderId.isEmpty else {
      result(FlutterError(
        code: "INVALID_REMINDER",
        message: "A saved reminder is required.",
        details: nil
      ))
      return
    }

    if call.method != "upsert" && link(for: reminderId) == nil {
      result(nil)
      return
    }
    if call.method == "remove" {
      var pending = pendingRemovals()
      pending.insert(reminderId)
      savePendingRemovals(pending)
    }

    guard IOSCalendarAuthorization.hasFullAccess() else {
      if call.method != "upsert" {
        result(FlutterError(
          code: "CALENDAR_PERMISSION",
          message: "Calendar access is disabled. The linked entry could not be updated.",
          details: nil
        ))
        return
      }
      if permissionCall != nil {
        result(FlutterError(
          code: "CALENDAR_BUSY",
          message: "Finish the current calendar request first.",
          details: nil
        ))
        return
      }
      permissionCall = (call, result)
      IOSCalendarAuthorization.requestFullAccess(store: store) { [weak self] granted, error in
        guard let self else { return }
        guard let pending = self.permissionCall else { return }
        self.permissionCall = nil
        guard error == nil, granted, IOSCalendarAuthorization.hasFullAccess() else {
          pending.1(FlutterError(
            code: "CALENDAR_PERMISSION",
            message: error?.localizedDescription ?? "Allow calendar access to link and remove completed entries.",
            details: nil
          ))
          return
        }
        self.execute(call: pending.0, result: pending.1)
      }
      return
    }
    execute(call: call, result: result)
  }

  private func execute(call: FlutterMethodCall, result: @escaping FlutterResult) {
    do {
      try retryPendingRemovals()
      guard let reminderId = stringArgument(call, "reminderId") else {
        throw CalendarBridgeError.invalid("A saved reminder is required.")
      }
      if let savedLink = link(for: reminderId), let event = ownedEvent(for: savedLink) {
        switch call.method {
        case "remove":
          try store.remove(event, span: removalSpan(for: event), commit: true)
          removeLink(for: reminderId)
          var pending = pendingRemovals()
          pending.remove(reminderId)
          savePendingRemovals(pending)
        default:
          try populate(event: event, from: call, marker: savedLink.marker)
          try store.save(event, span: saveSpan(for: event), commit: true)
        }
        result(nil)
        return
      }

      removeLink(for: reminderId)
      if call.method == "upsert" {
        let event = EKEvent(eventStore: store)
        let marker = "jotcue://reminders/\(UUID().uuidString)"
        guard let calendar = store.defaultCalendarForNewEvents else {
          throw CalendarBridgeError.invalid(
            "No writable calendar is available. Add a calendar account first."
          )
        }
        event.calendar = calendar
        try populate(event: event, from: call, marker: marker)
        try store.save(event, span: .thisEvent, commit: true)
        guard let eventIdentifier = event.eventIdentifier else {
          try? store.remove(event, span: .thisEvent, commit: true)
          throw CalendarBridgeError.invalid("Calendar did not return an event identifier.")
        }
        saveLink(
          CalendarLink(eventIdentifier: eventIdentifier, marker: marker),
          for: reminderId
        )
      }
      result(nil)
    } catch {
      fail(result, error)
    }
  }

  private func retryPendingRemovals() throws {
    var pending = pendingRemovals()
    guard !pending.isEmpty else { return }
    var processed = Set<String>()
    for reminderId in pending {
      if let savedLink = link(for: reminderId), let event = ownedEvent(for: savedLink) {
        try store.remove(event, span: removalSpan(for: event), commit: true)
      }
      removeLink(for: reminderId)
      processed.insert(reminderId)
    }
    pending.subtract(processed)
    savePendingRemovals(pending)
  }

  private func populate(event: EKEvent, from call: FlutterMethodCall, marker: String) throws {
    guard
      let arguments = call.arguments as? [String: Any],
      let scheduledMillis = number(arguments["scheduledAt"])
    else {
      throw CalendarBridgeError.invalid("Choose a reminder time first.")
    }
    let repeatValue = (arguments["repeat"] as? String) ?? "none"
    let recurrenceRules: [EKRecurrenceRule]?
    switch repeatValue {
    case "none":
      recurrenceRules = nil
    case "daily":
      recurrenceRules = [EKRecurrenceRule(
        recurrenceWith: .daily,
        interval: 1,
        end: nil
      )]
    case "weekly":
      recurrenceRules = [EKRecurrenceRule(
        recurrenceWith: .weekly,
        interval: 1,
        end: nil
      )]
    case "interval":
      throw CalendarBridgeError.unsupported(
        "Custom repeat calendar entries are not supported by iOS Calendar."
      )
    default:
      throw CalendarBridgeError.invalid("Unsupported repeat schedule.")
    }

    let start = Date(timeIntervalSince1970: scheduledMillis / 1000)
    event.title = (arguments["title"] as? String) ?? "Review note"
    event.notes = (arguments["body"] as? String) ?? ""
    event.startDate = start
    event.endDate = start.addingTimeInterval(30 * 60)
    event.timeZone = .current
    event.url = URL(string: marker)
    event.recurrenceRules = recurrenceRules
    event.availability = .busy
  }

  private func ownedEvent(for link: CalendarLink) -> EKEvent? {
    guard let event = store.event(withIdentifier: link.eventIdentifier) else { return nil }
    guard event.url?.absoluteString == link.marker else { return nil }
    return event
  }

  private func removalSpan(for event: EKEvent) -> EKSpan {
    (event.recurrenceRules?.isEmpty == false) ? .futureEvents : .thisEvent
  }

  private func saveSpan(for event: EKEvent) -> EKSpan {
    (event.recurrenceRules?.isEmpty == false) ? .futureEvents : .thisEvent
  }

  private func links() -> [String: [String: String]] {
    defaults.dictionary(forKey: Self.linksKey) as? [String: [String: String]] ?? [:]
  }

  private func link(for reminderId: String) -> CalendarLink? {
    guard let raw = links()[reminderId] else { return nil }
    return CalendarLink(raw)
  }

  private func saveLink(_ link: CalendarLink, for reminderId: String) {
    var values = links()
    values[reminderId] = link.dictionary
    defaults.set(values, forKey: Self.linksKey)
  }

  private func removeLink(for reminderId: String) {
    var values = links()
    values.removeValue(forKey: reminderId)
    defaults.set(values, forKey: Self.linksKey)
  }

  private func pendingRemovals() -> Set<String> {
    Set(defaults.stringArray(forKey: Self.pendingRemovalKey) ?? [])
  }

  private func savePendingRemovals(_ values: Set<String>) {
    defaults.set(Array(values).sorted(), forKey: Self.pendingRemovalKey)
  }

  private func stringArgument(_ call: FlutterMethodCall, _ key: String) -> String? {
    (call.arguments as? [String: Any])?[key] as? String
  }

  private func number(_ value: Any?) -> Double? {
    if let number = value as? NSNumber { return number.doubleValue }
    if let value = value as? Double { return value }
    if let value = value as? Int64 { return Double(value) }
    if let value = value as? Int { return Double(value) }
    return nil
  }

  private func fail(_ result: FlutterResult, _ error: Error) {
    if case CalendarBridgeError.unsupported(let message) = error {
      result(FlutterError(code: "CALENDAR_UNSUPPORTED", message: message, details: nil))
      return
    }
    result(FlutterError(
      code: "CALENDAR_FAILED",
      message: error.localizedDescription,
      details: nil
    ))
  }

  func dispose() {
    channel.setMethodCallHandler(nil)
    permissionCall?.1(FlutterError(
      code: "CALENDAR_CANCELLED",
      message: "Calendar permission request was closed.",
      details: nil
    ))
    permissionCall = nil
  }
}

private struct CalendarLink {
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

private enum CalendarBridgeError: LocalizedError {
  case invalid(String)
  case unsupported(String)

  var errorDescription: String? {
    switch self {
    case .invalid(let message), .unsupported(let message):
      return message
    }
  }
}
