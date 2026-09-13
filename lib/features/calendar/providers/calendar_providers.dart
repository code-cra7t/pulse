import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/availability_engine.dart';
import '../data/device_calendar_read_service.dart';
import '../data/device_schedule_calendar_service.dart';
import '../models/calendar_busy_event.dart';
import '../models/calendar_query_range.dart';

final deviceCalendarReadServiceProvider = Provider<DeviceCalendarReadService>((
  ref,
) {
  return DeviceCalendarReadService();
});

final deviceScheduleCalendarServiceProvider =
    Provider<DeviceScheduleCalendarService>((ref) {
      return DeviceScheduleCalendarService();
    });

final availabilityEngineProvider = Provider<AvailabilityEngine>((ref) {
  return const AvailabilityEngine();
});

final calendarReadAccessProvider = FutureProvider<bool>((ref) {
  return ref.watch(deviceCalendarReadServiceProvider).hasAccess();
});

final calendarBusyEventsProvider =
    FutureProvider.family<List<CalendarBusyEvent>, CalendarQueryRange>((
      ref,
      range,
    ) {
      if (!range.isValid) {
        return Future.value(const <CalendarBusyEvent>[]);
      }
      return ref
          .watch(deviceCalendarReadServiceProvider)
          .readBusyEvents(start: range.start, end: range.end);
    });
