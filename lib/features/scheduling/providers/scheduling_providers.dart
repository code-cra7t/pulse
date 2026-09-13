import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/offline/offline_schedule_block_store.dart';
import '../../auth/providers/auth_providers.dart';
import '../../calendar/models/availability_summary.dart';
import '../../calendar/models/calendar_busy_event.dart';
import '../../calendar/providers/calendar_providers.dart';
import '../../projects/providers/project_providers.dart';
import '../../settings/providers/user_settings_providers.dart';
import '../../tasks/providers/task_providers.dart';
import '../data/local_schedule_blocks_repository.dart';
import '../data/schedule_blocks_repository.dart';
import '../data/scheduling_proposal_engine.dart';
import '../models/schedule_block.dart';
import '../models/scheduling_day_state.dart';
import '../models/scheduling_preferences.dart';

final offlineScheduleBlockStoreProvider = Provider<OfflineScheduleBlockStore>((
  ref,
) {
  final store = OfflineScheduleBlockStore();
  ref.onDispose(() => unawaited(store.dispose()));
  return store;
});

final scheduleBlocksRepositoryProvider = Provider<ScheduleBlocksRepository>((
  ref,
) {
  return LocalScheduleBlocksRepository(
    ref.watch(offlineScheduleBlockStoreProvider),
  );
});

final scheduleBlocksStreamProvider = StreamProvider<List<ScheduleBlock>>((ref) {
  final authState = ref.watch(authStateChangesProvider);
  final repository = ref.watch(scheduleBlocksRepositoryProvider);
  return authState.when(
    data: (user) {
      if (user == null) {
        return Stream.value(const <ScheduleBlock>[]);
      }
      return repository.watchBlocks(user.uid);
    },
    loading: () => Stream.value(const <ScheduleBlock>[]),
    error: (_, _) => Stream.value(const <ScheduleBlock>[]),
  );
});

final schedulingProposalEngineProvider = Provider<SchedulingProposalEngine>((
  ref,
) {
  return const SchedulingProposalEngine();
});

final schedulingDayProvider =
    FutureProvider.family<SchedulingDayState, DateTime>((
      ref,
      requestedDate,
    ) async {
      final date = DateTime(
        requestedDate.year,
        requestedDate.month,
        requestedDate.day,
      );
      final settings = await ref.watch(currentUserSettingsProvider.future);
      final preferences =
          settings?.schedulingPreferences ?? SchedulingPreferences.defaults();
      final allBlocks = await ref.watch(scheduleBlocksStreamProvider.future);
      final tasks = ref.watch(tasksProvider);
      final projects = await ref.watch(projectsStreamProvider.future);
      final acceptedBlocks = allBlocks
          .where(
            (block) => block.occupiesTime && _sameDay(block.startsAt, date),
          )
          .toList(growable: false);
      final calendarService = ref.watch(deviceCalendarReadServiceProvider);
      final calendarSupported = calendarService.isSupported;

      if (!preferences.isConfigured || !preferences.isEnabledOn(date)) {
        return SchedulingDayState(
          date: date,
          preferences: preferences,
          calendarSupported: calendarSupported,
          calendarAccess: false,
          acceptedBlocks: acceptedBlocks,
        );
      }

      final calendarAccess =
          !calendarSupported || await calendarService.hasAccess();
      if (calendarSupported && !calendarAccess) {
        return SchedulingDayState(
          date: date,
          preferences: preferences,
          calendarSupported: true,
          calendarAccess: false,
          acceptedBlocks: acceptedBlocks,
        );
      }

      var windowStart = preferences.startFor(date);
      final windowEnd = preferences.endFor(date);
      final now = DateTime.now();
      if (_sameDay(now, date) && now.isAfter(windowStart)) {
        windowStart = _ceilToFiveMinutes(now);
      }
      if (!windowEnd.isAfter(windowStart)) {
        final availability = AvailabilitySummary(
          windowStart: windowEnd,
          windowEnd: windowEnd,
          busyMinutes: 0,
          freeMinutes: 0,
          freeSlots: const [],
        );
        return SchedulingDayState(
          date: date,
          preferences: preferences,
          calendarSupported: calendarSupported,
          calendarAccess: calendarAccess,
          acceptedBlocks: acceptedBlocks,
          availability: availability,
          proposal: null,
        );
      }

      final busyEvents = <CalendarBusyEvent>[];
      if (calendarSupported) {
        busyEvents.addAll(
          await calendarService.readBusyEvents(
            start: windowStart,
            end: windowEnd,
          ),
        );
      }
      if (preferences.protectLunch) {
        busyEvents.add(
          CalendarBusyEvent(
            id: 'jotcue-protected-lunch',
            title: 'Protected lunch',
            startsAt: preferences.lunchStartFor(date),
            endsAt: preferences.lunchEndFor(date),
          ),
        );
      }
      for (final block in acceptedBlocks) {
        busyEvents.add(
          CalendarBusyEvent(
            id: 'jotcue-block-${block.id}',
            title: block.title,
            startsAt: block.startsAt,
            endsAt: block.endsAt,
          ),
        );
      }

      final availability = ref
          .read(availabilityEngineProvider)
          .calculate(
            windowStart: windowStart,
            windowEnd: windowEnd,
            busyEvents: busyEvents,
            minimumSlot: Duration(minutes: preferences.minimumBlockMinutes),
          );
      final proposal = ref
          .read(schedulingProposalEngineProvider)
          .build(
            now: now,
            date: date,
            preferences: preferences,
            availability: availability,
            tasks: tasks,
            projects: projects,
            existingBlocks: allBlocks,
          );

      return SchedulingDayState(
        date: date,
        preferences: preferences,
        calendarSupported: calendarSupported,
        calendarAccess: calendarAccess,
        acceptedBlocks: acceptedBlocks,
        availability: availability,
        proposal: proposal,
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
