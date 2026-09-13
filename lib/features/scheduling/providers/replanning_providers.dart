import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../calendar/models/availability_summary.dart';
import '../../calendar/models/calendar_busy_event.dart';
import '../../calendar/providers/calendar_providers.dart';
import '../../projects/providers/project_providers.dart';
import '../../settings/providers/user_settings_providers.dart';
import '../../tasks/providers/task_providers.dart';
import '../data/adaptive_replanning_engine.dart';
import '../models/replanning_overview.dart';
import '../models/scheduling_preferences.dart';
import 'scheduling_providers.dart';

final adaptiveReplanningEngineProvider = Provider<AdaptiveReplanningEngine>((
  ref,
) {
  return const AdaptiveReplanningEngine();
});

/// Reviews the next seven calendar days for schedule drift.
///
/// This provider is advisory only. It never changes a schedule block or an
/// external calendar event. Actions are applied explicitly by the Plan UI.
final adaptiveReplanningProvider =
    FutureProvider.family<ReplanningOverview, DateTime>((
      ref,
      requestedNow,
    ) async {
      final now = requestedNow;
      final settings = await ref.watch(currentUserSettingsProvider.future);
      final preferences =
          settings?.schedulingPreferences ?? SchedulingPreferences.defaults();
      final blocks = await ref.watch(scheduleBlocksStreamProvider.future);
      final tasks = ref.watch(tasksProvider);
      final projects = await ref.watch(projectsStreamProvider.future);

      final firstDay = DateTime(now.year, now.month, now.day);
      final lastDay = firstDay.add(const Duration(days: 6));
      final horizonEnd = preferences.isConfigured
          ? preferences.endFor(lastDay)
          : DateTime(lastDay.year, lastDay.month, lastDay.day, 23, 59, 59);

      if (!preferences.isConfigured) {
        return ReplanningOverview(
          generatedAt: now,
          horizonEnd: horizonEnd,
          issues: const [],
          calendarConflictsChecked: false,
        );
      }

      final calendarService = ref.watch(deviceCalendarReadServiceProvider);
      final calendarSupported = calendarService.isSupported;
      final calendarAccess =
          !calendarSupported || await calendarService.hasAccess();
      final calendarConflictsChecked = calendarSupported && calendarAccess;
      var externalBusy = const <CalendarBusyEvent>[];
      if (calendarConflictsChecked) {
        externalBusy = await calendarService.readBusyEvents(
          start: preferences.startFor(firstDay),
          end: horizonEnd,
        );
      }

      final summaries = <AvailabilitySummary>[];
      for (var offset = 0; offset < 7; offset += 1) {
        final date = firstDay.add(Duration(days: offset));
        if (!preferences.isEnabledOn(date)) {
          continue;
        }

        var windowStart = preferences.startFor(date);
        final windowEnd = preferences.endFor(date);
        if (_sameDay(now, date) && now.isAfter(windowStart)) {
          windowStart = _ceilToFiveMinutes(now);
        }
        if (!windowEnd.isAfter(windowStart)) {
          summaries.add(
            AvailabilitySummary(
              windowStart: windowEnd,
              windowEnd: windowEnd,
              busyMinutes: 0,
              freeMinutes: 0,
              freeSlots: const [],
            ),
          );
          continue;
        }

        final busyEvents = externalBusy
            .where(
              (event) =>
                  event.startsAt.isBefore(windowEnd) &&
                  event.endsAt.isAfter(windowStart),
            )
            .toList();
        if (preferences.protectLunch) {
          busyEvents.add(
            CalendarBusyEvent(
              id: 'jotcue-protected-lunch-${date.millisecondsSinceEpoch}',
              title: 'Protected lunch',
              startsAt: preferences.lunchStartFor(date),
              endsAt: preferences.lunchEndFor(date),
            ),
          );
        }
        for (final block in blocks) {
          if (!block.occupiesTime || !_sameDay(block.startsAt, date)) {
            continue;
          }
          busyEvents.add(
            CalendarBusyEvent(
              id: 'jotcue-block-${block.id}',
              title: block.title,
              startsAt: block.startsAt,
              endsAt: block.endsAt,
            ),
          );
        }

        summaries.add(
          ref
              .read(availabilityEngineProvider)
              .calculate(
                windowStart: windowStart,
                windowEnd: windowEnd,
                busyEvents: busyEvents,
                minimumSlot: Duration(minutes: preferences.minimumBlockMinutes),
              ),
        );
      }

      return ref
          .read(adaptiveReplanningEngineProvider)
          .build(
            now: now,
            preferences: preferences,
            blocks: blocks,
            tasks: tasks,
            projects: projects,
            calendarBusyEvents: externalBusy,
            horizonAvailability: summaries,
            calendarConflictsChecked: calendarConflictsChecked,
          );
    });

DateTime _ceilToFiveMinutes(DateTime value) {
  final truncated = DateTime(
    value.year,
    value.month,
    value.day,
    value.hour,
    value.minute,
  );
  final remainder = truncated.minute % 5;
  final rounded = remainder == 0
      ? truncated
      : truncated.add(Duration(minutes: 5 - remainder));
  return rounded.isBefore(value)
      ? rounded.add(const Duration(minutes: 5))
      : rounded;
}

bool _sameDay(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}
