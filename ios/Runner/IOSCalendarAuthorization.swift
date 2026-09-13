import EventKit
import Foundation

/// Centralizes EventKit access semantics across all JotCue calendar bridges.
/// Read access requires full calendar access on iOS 17+, so managed writes also
/// request full access to keep ownership verification fail-closed.
enum IOSCalendarAuthorization {
  static func hasFullAccess() -> Bool {
    let status = EKEventStore.authorizationStatus(for: .event)
    if #available(iOS 17.0, *) {
      return status == .fullAccess
    }
    return status == .authorized
  }

  static func requestFullAccess(
    store: EKEventStore,
    completion: @escaping (Bool, Error?) -> Void
  ) {
    if #available(iOS 17.0, *) {
      store.requestFullAccessToEvents { granted, error in
        DispatchQueue.main.async { completion(granted, error) }
      }
      return
    }
    store.requestAccess(to: .event) { granted, error in
      DispatchQueue.main.async { completion(granted, error) }
    }
  }
}
