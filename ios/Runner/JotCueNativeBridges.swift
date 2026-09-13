import Flutter
import Foundation

/// Retains all iOS platform-channel bridges for the lifetime of the implicit
/// Flutter engine.
final class JotCueNativeBridges {
  private let calendarRead: IOSCalendarReadBridge
  private let reminderCalendar: IOSReminderCalendarBridge
  private let scheduleCalendar: IOSScheduleCalendarBridge
  private let share: IOSShareBridge

  init(messenger: FlutterBinaryMessenger) {
    calendarRead = IOSCalendarReadBridge(messenger: messenger)
    reminderCalendar = IOSReminderCalendarBridge(messenger: messenger)
    scheduleCalendar = IOSScheduleCalendarBridge(messenger: messenger)
    share = IOSShareBridge(messenger: messenger)
  }

  deinit {
    calendarRead.dispose()
    reminderCalendar.dispose()
    scheduleCalendar.dispose()
    share.dispose()
  }
}
