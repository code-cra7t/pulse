import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/offline/offline_ai_assistant_store.dart';
import '../../automation/providers/automation_providers.dart';
import '../../calendar/providers/calendar_providers.dart';
import '../../capture/providers/capture_providers.dart';
import '../../scheduling/providers/scheduling_providers.dart';
import '../../tasks/providers/task_providers.dart';
import '../data/ai_gateway_client.dart';
import '../data/ask_jotcue_action_executor.dart';
import '../data/ask_jotcue_engine.dart';
import '../data/ask_jotcue_plan_executor.dart';
import '../data/hybrid_ask_jotcue_service.dart';
import '../models/ai_assistant_preferences.dart';

const _gatewayUrl = String.fromEnvironment('JOTCUE_AI_GATEWAY_URL');

final offlineAiAssistantStoreProvider = Provider<OfflineAiAssistantStore>((
  ref,
) {
  final store = OfflineAiAssistantStore();
  ref.onDispose(() => unawaited(store.dispose()));
  return store;
});

final aiAssistantPreferencesProvider = StreamProvider<AiAssistantPreferences>((
  ref,
) {
  return ref.watch(offlineAiAssistantStoreProvider).watchPreferences();
});

final aiGatewayClientProvider = Provider<AiGatewayClient>((ref) {
  if (_gatewayUrl.trim().isEmpty) return const DisabledAiGatewayClient();
  final client = HttpAiGatewayClient(endpoint: _gatewayUrl);
  ref.onDispose(client.close);
  return client;
});

final askJotCueEngineProvider = Provider<AskJotCueEngine>((ref) {
  return const AskJotCueEngine();
});

final hybridAskJotCueServiceProvider = Provider<HybridAskJotCueService>((ref) {
  return HybridAskJotCueService(
    localEngine: ref.watch(askJotCueEngineProvider),
    gateway: ref.watch(aiGatewayClientProvider),
  );
});

final askJotCueActionExecutorProvider = Provider<AskJotCueActionExecutor>((
  ref,
) {
  final taskService = ref.watch(taskServiceProvider);
  final scheduleBlocks = ref.watch(scheduleBlocksRepositoryProvider);
  final calendar = ref.watch(deviceScheduleCalendarServiceProvider);
  final capture = ref.watch(captureServiceProvider);
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
    createStructuredCapture: ({required userId, required draft}) {
      return capture.createStructured(userId: userId, draft: draft);
    },
    saveCaptureAsNote: ({required userId, required rawText}) {
      return capture.saveAsNote(userId: userId, rawText: rawText);
    },
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

final askJotCuePlanExecutorProvider = Provider<AskJotCuePlanExecutor>((ref) {
  return AskJotCuePlanExecutor(
    actionExecutor: ref.watch(askJotCueActionExecutorProvider),
  );
});
