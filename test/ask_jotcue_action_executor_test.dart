import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/core/models/priority_level.dart';
import 'package:pulse/features/assistant/data/ask_jotcue_action_executor.dart';
import 'package:pulse/features/assistant/models/ask_jotcue.dart';
import 'package:pulse/features/automation/data/automation_policy.dart';
import 'package:pulse/features/automation/models/automation_preferences.dart';
import 'package:pulse/features/capture/models/capture_draft.dart';
import 'package:pulse/features/scheduling/data/schedule_blocks_repository.dart';
import 'package:pulse/features/scheduling/models/schedule_block.dart';
import 'package:pulse/features/scheduling/models/schedule_proposal.dart';
import 'package:pulse/features/tasks/models/task_metadata_update.dart';

void main() {
  final now = DateTime(2026, 9, 13, 10);

  AskJotCueActionProposal completionProposal({bool completed = true}) {
    return AskJotCueActionProposal(
      id: 'completion:task:$completed',
      kind: AskJotCueActionKind.taskCompletion,
      userId: 'user',
      taskId: 'task',
      taskTitle: 'Revise chapter 4',
      sourceNoteId: 'note',
      targetCompletion: completed,
      previewTitle: 'Mark complete',
      previewText: 'Preview',
    );
  }

  AskJotCueActionProposal priorityProposal() {
    return const AskJotCueActionProposal(
      id: 'priority:task:critical',
      kind: AskJotCueActionKind.taskPriority,
      userId: 'user',
      taskId: 'task',
      taskTitle: 'Revise chapter 4',
      sourceNoteId: 'note',
      targetPriority: PriorityLevel.critical,
      previewTitle: 'Change priority',
      previewText: 'Preview',
    );
  }

  ScheduleBlock scheduledBlock({DateTime? startsAt, DateTime? endsAt}) {
    return ScheduleBlock(
      id: 'block',
      userId: 'user',
      taskId: 'task',
      title: 'Revise chapter 4',
      startsAt: startsAt ?? DateTime(2026, 9, 13, 11),
      endsAt: endsAt ?? DateTime(2026, 9, 13, 12),
      createdAt: DateTime(2026, 9, 12),
      updatedAt: DateTime(2026, 9, 12),
    );
  }

  AskJotCueActionProposal moveProposal() {
    return AskJotCueActionProposal(
      id: 'move:block',
      kind: AskJotCueActionKind.scheduleMove,
      userId: 'user',
      taskId: 'task',
      taskTitle: 'Revise chapter 4',
      blockId: 'block',
      fromStartsAt: DateTime(2026, 9, 13, 11),
      fromEndsAt: DateTime(2026, 9, 13, 12),
      toStartsAt: DateTime(2026, 9, 14, 15),
      toEndsAt: DateTime(2026, 9, 14, 16),
      previewTitle: 'Move scheduled block',
      previewText: 'Preview',
    );
  }

  test('suggest mode never executes a completion mutation', () async {
    var completionCalls = 0;
    final executor = AskJotCueActionExecutor(
      policy: const AutomationPolicy(),
      setTaskCompletion:
          ({
            required userId,
            required noteId,
            required taskId,
            required isCompleted,
          }) async {
            completionCalls += 1;
          },
      updateTaskMetadata:
          ({
            required userId,
            required noteId,
            required taskId,
            required update,
          }) async {},
      scheduleBlocks: _FakeScheduleBlocksRepository([]),
      isCalendarLinked: (_) async => false,
      isScheduleMoveAvailable:
          ({required blockId, required startsAt, required endsAt}) async =>
              true,
    );

    await expectLater(
      executor.execute(
        preferences: const AutomationPreferences(
          level: AutomationLevel.suggest,
        ),
        proposal: completionProposal(),
        now: now,
        approved: true,
      ),
      throwsA(isA<StateError>()),
    );
    expect(completionCalls, 0);
  });

  test(
    'approval mode executes completion only after explicit approval',
    () async {
      bool? target;
      final executor = AskJotCueActionExecutor(
        policy: const AutomationPolicy(),
        setTaskCompletion:
            ({
              required userId,
              required noteId,
              required taskId,
              required isCompleted,
            }) async {
              target = isCompleted;
            },
        updateTaskMetadata:
            ({
              required userId,
              required noteId,
              required taskId,
              required update,
            }) async {},
        scheduleBlocks: _FakeScheduleBlocksRepository([]),
        isCalendarLinked: (_) async => false,
        isScheduleMoveAvailable:
            ({required blockId, required startsAt, required endsAt}) async =>
                true,
      );

      await expectLater(
        executor.execute(
          preferences: const AutomationPreferences(
            level: AutomationLevel.approval,
          ),
          proposal: completionProposal(),
          now: now,
          approved: false,
        ),
        throwsA(isA<StateError>()),
      );
      expect(target, isNull);

      final result = await executor.execute(
        preferences: const AutomationPreferences(
          level: AutomationLevel.approval,
        ),
        proposal: completionProposal(),
        now: now,
        approved: true,
      );
      expect(target, isTrue);
      expect(result, contains('Marked'));
    },
  );

  test('trusted completion remains approval-gated by policy', () {
    final executor = AskJotCueActionExecutor(
      policy: const AutomationPolicy(),
      setTaskCompletion:
          ({
            required userId,
            required noteId,
            required taskId,
            required isCompleted,
          }) async {},
      updateTaskMetadata:
          ({
            required userId,
            required noteId,
            required taskId,
            required update,
          }) async {},
      scheduleBlocks: _FakeScheduleBlocksRepository([]),
      isCalendarLinked: (_) async => false,
      isScheduleMoveAvailable:
          ({required blockId, required startsAt, required endsAt}) async =>
              true,
    );

    expect(
      executor.decisionFor(
        preferences: const AutomationPreferences(
          level: AutomationLevel.trusted,
        ),
        proposal: completionProposal(),
      ),
      AutomationDecision.requiresApproval,
    );
  });

  test(
    'priority update is approval-gated and uses task metadata service',
    () async {
      TaskMetadataUpdate? captured;
      final executor = AskJotCueActionExecutor(
        policy: const AutomationPolicy(),
        setTaskCompletion:
            ({
              required userId,
              required noteId,
              required taskId,
              required isCompleted,
            }) async {},
        updateTaskMetadata:
            ({
              required userId,
              required noteId,
              required taskId,
              required update,
            }) async {
              captured = update;
            },
        scheduleBlocks: _FakeScheduleBlocksRepository([]),
        isCalendarLinked: (_) async => false,
        isScheduleMoveAvailable:
            ({required blockId, required startsAt, required endsAt}) async =>
                true,
      );

      await executor.execute(
        preferences: const AutomationPreferences(
          level: AutomationLevel.approval,
        ),
        proposal: priorityProposal(),
        now: now,
        approved: true,
      );

      expect(captured?.priority, PriorityLevel.critical);
    },
  );

  test(
    'trusted local schedule move still waits for the Ask JotCue Apply tap',
    () async {
      final repository = _FakeScheduleBlocksRepository([scheduledBlock()]);
      final executor = AskJotCueActionExecutor(
        policy: const AutomationPolicy(),
        setTaskCompletion:
            ({
              required userId,
              required noteId,
              required taskId,
              required isCompleted,
            }) async {},
        updateTaskMetadata:
            ({
              required userId,
              required noteId,
              required taskId,
              required update,
            }) async {},
        scheduleBlocks: repository,
        isCalendarLinked: (_) async => false,
        isScheduleMoveAvailable:
            ({required blockId, required startsAt, required endsAt}) async =>
                true,
      );

      await expectLater(
        executor.execute(
          preferences: const AutomationPreferences(
            level: AutomationLevel.trusted,
          ),
          proposal: moveProposal(),
          now: now,
          approved: false,
        ),
        throwsA(isA<StateError>()),
      );
      expect(repository.rescheduleCalls, 0);

      await executor.execute(
        preferences: const AutomationPreferences(
          level: AutomationLevel.trusted,
        ),
        proposal: moveProposal(),
        now: now,
        approved: true,
      );
      expect(repository.rescheduleCalls, 1);
      expect(repository.blocks.single.startsAt, DateTime(2026, 9, 14, 15));
    },
  );

  test('stale schedule preview fails closed', () async {
    final repository = _FakeScheduleBlocksRepository([
      scheduledBlock(
        startsAt: DateTime(2026, 9, 13, 12),
        endsAt: DateTime(2026, 9, 13, 13),
      ),
    ]);
    final executor = AskJotCueActionExecutor(
      policy: const AutomationPolicy(),
      setTaskCompletion:
          ({
            required userId,
            required noteId,
            required taskId,
            required isCompleted,
          }) async {},
      updateTaskMetadata:
          ({
            required userId,
            required noteId,
            required taskId,
            required update,
          }) async {},
      scheduleBlocks: repository,
      isCalendarLinked: (_) async => false,
      isScheduleMoveAvailable:
          ({required blockId, required startsAt, required endsAt}) async =>
              true,
    );

    await expectLater(
      executor.execute(
        preferences: const AutomationPreferences(
          level: AutomationLevel.approval,
        ),
        proposal: moveProposal(),
        now: now,
        approved: true,
      ),
      throwsA(isA<StateError>()),
    );
    expect(repository.rescheduleCalls, 0);
  });

  test(
    'calendar-linked move is refused without changing local schedule',
    () async {
      final repository = _FakeScheduleBlocksRepository([scheduledBlock()]);
      final executor = AskJotCueActionExecutor(
        policy: const AutomationPolicy(),
        setTaskCompletion:
            ({
              required userId,
              required noteId,
              required taskId,
              required isCompleted,
            }) async {},
        updateTaskMetadata:
            ({
              required userId,
              required noteId,
              required taskId,
              required update,
            }) async {},
        scheduleBlocks: repository,
        isCalendarLinked: (_) async => true,
        isScheduleMoveAvailable:
            ({required blockId, required startsAt, required endsAt}) async =>
                true,
      );

      await expectLater(
        executor.execute(
          preferences: const AutomationPreferences(
            level: AutomationLevel.approval,
          ),
          proposal: moveProposal(),
          now: now,
          approved: true,
        ),
        throwsA(isA<StateError>()),
      );
      expect(repository.rescheduleCalls, 0);
    },
  );

  test(
    'schedule move fails closed when deterministic availability rejects target',
    () async {
      final repository = _FakeScheduleBlocksRepository([scheduledBlock()]);
      final executor = AskJotCueActionExecutor(
        policy: const AutomationPolicy(),
        setTaskCompletion:
            ({
              required userId,
              required noteId,
              required taskId,
              required isCompleted,
            }) async {},
        updateTaskMetadata:
            ({
              required userId,
              required noteId,
              required taskId,
              required update,
            }) async {},
        scheduleBlocks: repository,
        isCalendarLinked: (_) async => false,
        isScheduleMoveAvailable:
            ({required blockId, required startsAt, required endsAt}) async =>
                false,
      );

      await expectLater(
        executor.execute(
          preferences: const AutomationPreferences(
            level: AutomationLevel.approval,
          ),
          proposal: moveProposal(),
          now: now,
          approved: true,
        ),
        throwsA(isA<StateError>()),
      );
      expect(repository.rescheduleCalls, 0);
    },
  );

  test(
    'structured capture requires approval and then uses capture service path',
    () async {
      var calls = 0;
      final draft = CaptureDraft(
        kind: CaptureDraftKind.task,
        rawText: 'Add task Buy groceries',
        tasks: const ['Buy groceries'],
      );
      final proposal = AskJotCueActionProposal(
        id: 'capture:task',
        kind: AskJotCueActionKind.structuredCapture,
        userId: 'user',
        previewTitle: 'Create task',
        previewText: '• Buy groceries',
        captureDraft: draft,
      );
      final executor = AskJotCueActionExecutor(
        policy: const AutomationPolicy(),
        setTaskCompletion:
            ({
              required userId,
              required noteId,
              required taskId,
              required isCompleted,
            }) async {},
        updateTaskMetadata:
            ({
              required userId,
              required noteId,
              required taskId,
              required update,
            }) async {},
        scheduleBlocks: _FakeScheduleBlocksRepository([]),
        isCalendarLinked: (_) async => false,
        isScheduleMoveAvailable:
            ({required blockId, required startsAt, required endsAt}) async =>
                true,
        createStructuredCapture: ({required userId, required draft}) async {
          calls += 1;
          expect(userId, 'user');
          expect(draft.tasks, ['Buy groceries']);
          return const CaptureResult(noteId: 'note', taskCount: 1);
        },
      );

      await expectLater(
        executor.execute(
          preferences: const AutomationPreferences(
            level: AutomationLevel.trusted,
          ),
          proposal: proposal,
          now: now,
          approved: false,
        ),
        throwsA(isA<StateError>()),
      );
      expect(calls, 0);

      final result = await executor.execute(
        preferences: const AutomationPreferences(
          level: AutomationLevel.trusted,
        ),
        proposal: proposal,
        now: now,
        approved: true,
      );
      expect(calls, 1);
      expect(result, '1 task captured.');
    },
  );

  test(
    'note capture uses the existing note capture callback after approval',
    () async {
      var saved = '';
      final executor = AskJotCueActionExecutor(
        policy: const AutomationPolicy(),
        setTaskCompletion:
            ({
              required userId,
              required noteId,
              required taskId,
              required isCompleted,
            }) async {},
        updateTaskMetadata:
            ({
              required userId,
              required noteId,
              required taskId,
              required update,
            }) async {},
        scheduleBlocks: _FakeScheduleBlocksRepository([]),
        isCalendarLinked: (_) async => false,
        isScheduleMoveAvailable:
            ({required blockId, required startsAt, required endsAt}) async =>
                true,
        saveCaptureAsNote: ({required userId, required rawText}) async {
          saved = rawText;
          return const CaptureResult(noteId: 'note', taskCount: 0);
        },
      );
      const proposal = AskJotCueActionProposal(
        id: 'note:1',
        kind: AskJotCueActionKind.noteCreate,
        userId: 'user',
        previewTitle: 'Save note',
        previewText: 'Preview',
        noteText: 'Sarah moved the meeting to Friday',
      );

      final result = await executor.execute(
        preferences: const AutomationPreferences(
          level: AutomationLevel.approval,
        ),
        proposal: proposal,
        now: now,
        approved: true,
      );
      expect(saved, 'Sarah moved the meeting to Friday');
      expect(result, 'Capture saved as a note.');
    },
  );
}

class _FakeScheduleBlocksRepository implements ScheduleBlocksRepository {
  _FakeScheduleBlocksRepository(this.blocks);

  final List<ScheduleBlock> blocks;
  int rescheduleCalls = 0;

  @override
  Stream<List<ScheduleBlock>> watchBlocks(String userId) {
    return Stream.value(List<ScheduleBlock>.from(blocks));
  }

  @override
  Future<List<ScheduleBlock>> readBlocks(String userId) async {
    return List<ScheduleBlock>.from(blocks);
  }

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
  }) async {
    rescheduleCalls += 1;
    final updated = block.copyWith(
      startsAt: startsAt,
      endsAt: endsAt,
      updatedAt: DateTime(2026, 9, 13, 10),
    );
    final index = blocks.indexWhere((item) => item.id == block.id);
    blocks[index] = updated;
    return updated;
  }

  @override
  Future<void> deleteBlock(String userId, String blockId) {
    throw UnimplementedError();
  }

  @override
  Future<void> clearUser(String userId) async {
    blocks.clear();
  }
}
