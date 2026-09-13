import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../automation/providers/automation_providers.dart';
import '../../calendar/providers/calendar_providers.dart';
import '../../scheduling/providers/scheduling_providers.dart';
import '../../tasks/providers/task_providers.dart';
import '../data/ask_jotcue_action_executor.dart';
import '../data/ask_jotcue_engine.dart';

final askJotCueEngineProvider = Provider<AskJotCueEngine>((ref) {
  return const AskJotCueEngine();
});

final askJotCueActionExecutorProvider = Provider<AskJotCueActionExecutor>((
  ref,
) {
  final taskService = ref.watch(taskServiceProvider);
  final scheduleBlocks = ref.watch(scheduleBlocksRepositoryProvider);
  final calendar = ref.watch(deviceScheduleCalendarServiceProvider);
  return AskJotCueActionExecutor(
    policy: ref.watch(automationPolicyProvider),
    setTaskCompletion:
        ({
          required userId,
          required noteId,
          required taskId,
          required isCompleted,
        }) {
          return taskService.setCompletion(
            userId: userId,
            noteId: noteId,
            taskId: taskId,
            isCompleted: isCompleted,
          );
        },
    updateTaskMetadata:
        ({required userId, required noteId, required taskId, required update}) {
          return taskService.updateMetadata(
            userId: userId,
            noteId: noteId,
            taskId: taskId,
            update: update,
          );
        },
    scheduleBlocks: scheduleBlocks,
    isCalendarLinked: calendar.isLinked,
    isScheduleMoveAvailable:
        ({required blockId, required startsAt, required endsAt}) async {
          final date = DateTime(startsAt.year, startsAt.month, startsAt.day);
          final state = await ref.read(schedulingDayProvider(date).future);
          final availability = state.availability;
          if (!state.isConfigured ||
              !state.isEnabledDay ||
              state.needsCalendarAccess ||
              availability == null) {
            return false;
          }
          return availability.freeSlots.any(
            (slot) =>
                !startsAt.isBefore(slot.startsAt) &&
                !endsAt.isAfter(slot.endsAt),
          );
        },
  );
});
