import EventKit
import Flutter
import Foundation

/// Read-only EventKit bridge used by JotCue's deterministic availability model.
final class IOSCalendarReadBridge {
  private static let maxQueryRange: TimeInterval = 31 * 24 * 60 * 60

  private let store = EKEventStore()
  private let channel: FlutterMethodChannel
  private var permissionResult: FlutterResult?

  init(messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(
      name: "com.tori.pulse/calendar_read",
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
    case "listEvents":
      listEvents(call: call, result: result)
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
        message: "Finish the current calendar request first.",
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

  private func listEvents(call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard IOSCalendarAuthorization.hasFullAccess() else {
      result(FlutterError(
        code: "CALENDAR_PERMISSION",
        message: "Calendar read access is disabled.",
        details: nil
      ))
      return
    }
    guard
      let arguments = call.arguments as? [String: Any],
      let startMillis = milliseconds(arguments["startAt"]),
      let endMillis = milliseconds(arguments["endAt"]),
      endMillis > startMillis
    else {
      result(FlutterError(
        code: "INVALID_RANGE",
        message: "Choose a valid calendar range.",
        details: nil
      ))
      return
    }

    let start = Date(timeIntervalSince1970: startMillis / 1000)
    let end = Date(timeIntervalSince1970: endMillis / 1000)
    guard end.timeIntervalSince(start) <= Self.maxQueryRange else {
      result(FlutterError(
        code: "RANGE_TOO_LARGE",
        message: "Calendar reads are limited to 31 days.",
        details: nil
      ))
      return
    }

    let predicate = store.predicateForEvents(withStart: start, end: end, calendars: nil)
    let events = store.events(matching: predicate)
      .filter { event in
        event.status != .canceled && event.availability != .free && event.endDate > event.startDate
      }
      .map { event -> [String: Any] in
        let startMs = Int64(event.startDate.timeIntervalSince1970 * 1000)
        let identifier = event.eventIdentifier ?? event.calendarItemIdentifier
        return [
          "id": "\(identifier):\(startMs)",
          "title": event.title ?? "",
          "startsAt": startMs,
          "endsAt": Int64(event.endDate.timeIntervalSince1970 * 1000),
          "isAllDay": event.isAllDay,
        ]
      }
      .sorted { lhs, rhs in
        (lhs["startsAt"] as? Int64 ?? 0) < (rhs["startsAt"] as? Int64 ?? 0)
      }
    result(events)
  }

  private func milliseconds(_ value: Any?) -> Double? {
    if let number = value as? NSNumber { return number.doubleValue }
    if let value = value as? Double { return value }
    if let value = value as? Int64 { return Double(value) }
    if let value = value as? Int { return Double(value) }
    return nil
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
