import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/core/models/priority_level.dart';
import 'package:pulse/features/assistant/data/ask_jotcue_action_executor.dart';
import 'package:pulse/features/assistant/data/assistant_account_guard.dart';
import 'package:pulse/features/assistant/data/ask_jotcue_plan_executor.dart';
import 'package:pulse/features/assistant/models/ask_jotcue.dart';
import 'package:pulse/features/automation/data/automation_policy.dart';
import 'package:pulse/features/automation/models/automation_preferences.dart';
import 'package:pulse/features/scheduling/data/schedule_blocks_repository.dart';
import 'package:pulse/features/scheduling/models/schedule_block.dart';
import 'package:pulse/features/scheduling/models/schedule_proposal.dart';

void main() {
  final now = DateTime(2026, 9, 14, 10);

  AskJotCueActionProposal completion(String taskId) {
    return AskJotCueActionProposal(
      id: 'completion:$taskId:true',
      kind: AskJotCueActionKind.taskCompletion,
      userId: 'user',
      taskId: taskId,
      taskTitle: 'Task $taskId',
      sourceNoteId: 'note-$taskId',
      targetCompletion: true,
      previewTitle: 'Mark complete',
      previewText: 'Preview',
    );
  }

  AskJotCueActionProposal priority() {
    return const AskJotCueActionProposal(
      id: 'priority:two:high',
      kind: AskJotCueActionKind.taskPriority,
      userId: 'user',
      taskId: 'two',
      taskTitle: 'Task two',
      sourceNoteId: 'note-two',
      targetPriority: PriorityLevel.high,
      previewTitle: 'Change priority',
      previewText: 'Preview',
    );
  }

  AskJotCueActionPlan plan(List<AskJotCueActionProposal> steps) {
    return AskJotCueActionPlan(
      id: 'plan:test',
      steps: steps,
      previewTitle: 'Plan',
      previewText: 'Preview',
    );
  }

  AskJotCueActionExecutor actionExecutor({
    required List<String> calls,
    bool failMetadata = false,
    String? Function()? currentUserId,
    void Function()? afterCompletion,
  }) {
    return AskJotCueActionExecutor(
      accountGuard: AssistantAccountGuard(
        currentUserId: currentUserId ?? () => 'user',
      ),
      policy: const AutomationPolicy(),
      setTaskCompletion:
          ({
            required userId,
            required noteId,
            required taskId,
            required isCompleted,
          }) async {
            calls.add('completion:$taskId');
            afterCompletion?.call();
          },
      updateTaskMetadata:
          ({
            required userId,
            required noteId,
            required taskId,
            required update,
          }) async {
            calls.add('metadata:$taskId');
            if (failMetadata) {
              throw StateError('metadata changed');
            }
          },
      scheduleBlocks: _FakeScheduleBlocksRepository(),
      isCalendarLinked: (_) async => false,
      isScheduleMoveAvailable:
          ({required blockId, required startsAt, required endsAt}) async =>
              true,
    );
  }

  test('suggest mode preflight prevents every step from executing', () async {
    final calls = <String>[];
    final executor = AskJotCuePlanExecutor(
      actionExecutor: actionExecutor(calls: calls),
    );

    await expectLater(
      executor.execute(
        preferences: const AutomationPreferences(
          level: AutomationLevel.suggest,
        ),
        plan: plan([completion('one'), priority()]),
        now: now,
        approved: true,
      ),
      throwsA(isA<StateError>()),
    );
    expect(calls, isEmpty);
  });

  test('explicit approval is required before step one', () async {
    final calls = <String>[];
    final executor = AskJotCuePlanExecutor(
      actionExecutor: actionExecutor(calls: calls),
    );

    await expectLater(
      executor.execute(
        preferences: const AutomationPreferences(
          level: AutomationLevel.approval,
        ),
        plan: plan([completion('one'), priority()]),
        now: now,
        approved: false,
      ),
      throwsA(isA<StateError>()),
    );
    expect(calls, isEmpty);
  });

  test('approved plan executes typed actions in order', () async {
    final calls = <String>[];
    final executor = AskJotCuePlanExecutor(
      actionExecutor: actionExecutor(calls: calls),
    );

    final result = await executor.execute(
      preferences: const AutomationPreferences(level: AutomationLevel.approval),
      plan: plan([completion('one'), priority()]),
      now: now,
      approved: true,
    );

    expect(calls, ['completion:one', 'metadata:two']);
    expect(result.isComplete, isTrue);
    expect(result.succeededCount, 2);
    expect(result.summary, contains('Applied all 2'));
  });

  test('failure stops later steps and reports partial execution', () async {
    final calls = <String>[];
    final executor = AskJotCuePlanExecutor(
      actionExecutor: actionExecutor(calls: calls, failMetadata: true),
    );

    final result = await executor.execute(
      preferences: const AutomationPreferences(level: AutomationLevel.approval),
      plan: plan([completion('one'), priority(), completion('three')]),
      now: now,
      approved: true,
    );

    expect(calls, ['completion:one', 'metadata:two']);
    expect(result.isComplete, isFalse);
    expect(result.succeededCount, 1);
    expect(result.steps[1].status, AskJotCuePlanStepStatus.failed);
    expect(result.steps[2].status, AskJotCuePlanStepStatus.notRun);
    expect(result.summary, contains('Step 2 failed'));
    expect(result.summary, contains('Ask again before retrying'));
  });

  test('duplicate actions are rejected before execution', () async {
    final calls = <String>[];
    final executor = AskJotCuePlanExecutor(
      actionExecutor: actionExecutor(calls: calls),
    );
    final duplicate = completion('one');

    await expectLater(
      executor.execute(
        preferences: const AutomationPreferences(
          level: AutomationLevel.approval,
        ),
        plan: plan([duplicate, duplicate]),
        now: now,
        approved: true,
      ),
      throwsA(isA<StateError>()),
    );
    expect(calls, isEmpty);
  });
  test('account switch preflight prevents every plan step', () async {
    final calls = <String>[];
    final executor = AskJotCuePlanExecutor(
      actionExecutor: actionExecutor(
        calls: calls,
        currentUserId: () => 'other-user',
      ),
    );

    await expectLater(
      executor.execute(
        preferences: const AutomationPreferences(
          level: AutomationLevel.approval,
        ),
        plan: plan([completion('one'), priority()]),
        now: now,
        approved: true,
      ),
      throwsA(isA<StateError>()),
    );
    expect(calls, isEmpty);
  });

  test('account switch between steps stops the remaining plan', () async {
    final calls = <String>[];
    var currentUserId = 'user';
    final executor = AskJotCuePlanExecutor(
      actionExecutor: actionExecutor(
        calls: calls,
        currentUserId: () => currentUserId,
        afterCompletion: () {
          currentUserId = 'other-user';
        },
      ),
    );

    final result = await executor.execute(
      preferences: const AutomationPreferences(level: AutomationLevel.approval),
      plan: plan([completion('one'), priority(), completion('three')]),
      now: now,
      approved: true,
    );

    expect(calls, ['completion:one']);
    expect(result.isComplete, isFalse);
    expect(result.succeededCount, 1);
    expect(result.steps[1].status, AskJotCuePlanStepStatus.failed);
    expect(result.steps[1].message, contains('signed-in account changed'));
    expect(result.steps[2].status, AskJotCuePlanStepStatus.notRun);
  });
}

class _FakeScheduleBlocksRepository implements ScheduleBlocksRepository {
  @override
  Stream<List<ScheduleBlock>> watchBlocks(String userId) =>
      Stream.value(const <ScheduleBlock>[]);

  @override
  Future<List<ScheduleBlock>> readBlocks(String userId) async =>
      const <ScheduleBlock>[];

  @override
  Future<ScheduleBlock> acceptProposal({
    required String userId,
    required ScheduleProposal proposal,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<void> updateStatus({
    required ScheduleBlock block,
    required ScheduleBlockStatus status,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<ScheduleBlock> rescheduleBlock({
    required ScheduleBlock block,
    required DateTime startsAt,
    required DateTime endsAt,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<void> deleteBlock(String userId, String blockId) {
    throw UnimplementedError();
  }

  @override
  Future<void> clearUser(String userId) async {}
}
