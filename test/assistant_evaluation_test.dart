import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/core/models/priority_level.dart';
import 'package:pulse/features/assistant/data/ai_gateway_client.dart';
import 'package:pulse/features/assistant/data/assistant_account_guard.dart';
import 'package:pulse/features/assistant/data/ask_jotcue_action_executor.dart';
import 'package:pulse/features/assistant/data/ask_jotcue_engine.dart';
import 'package:pulse/features/assistant/data/ask_jotcue_plan_executor.dart';
import 'package:pulse/features/assistant/data/hybrid_ask_jotcue_service.dart';
import 'package:pulse/features/assistant/models/ai_assistant_preferences.dart';
import 'package:pulse/features/assistant/models/ai_gateway.dart';
import 'package:pulse/features/assistant/models/ask_jotcue.dart';
import 'package:pulse/features/automation/data/automation_policy.dart';
import 'package:pulse/features/automation/models/automation_preferences.dart';
import 'package:pulse/features/projects/models/project.dart';
import 'package:pulse/features/pulse/models/daily_pulse_loop.dart';
import 'package:pulse/features/pulse/models/pulse_overview.dart';
import 'package:pulse/features/scheduling/data/schedule_blocks_repository.dart';
import 'package:pulse/features/scheduling/models/schedule_block.dart';
import 'package:pulse/features/scheduling/models/schedule_proposal.dart';
import 'package:pulse/features/tasks/data/task_dependency_analyzer.dart';
import 'package:pulse/features/tasks/models/task.dart';
import 'package:pulse/features/tasks/models/task_metadata_update.dart';

void main() {
  const engine = AskJotCueEngine();
  final now = DateTime(2026, 9, 14, 10);

  Project project({
    String id = 'project',
    String userId = 'user',
    String name = 'Thesis',
  }) {
    return Project(
      id: id,
      userId: userId,
      name: name,
      priority: PriorityLevel.high,
      deadline: DateTime(2026, 10, 2),
      createdAt: DateTime(2026, 9, 1),
      updatedAt: DateTime(2026, 9, 13),
    );
  }

  Task task({
    String id = 'task',
    String userId = 'user',
    String title = 'Revise chapter 4',
    bool isCompleted = false,
    String? projectId = 'project',
    DateTime? dueAt,
    PriorityLevel priority = PriorityLevel.medium,
    int? estimatedMinutes = 60,
    List<String> dependsOnTaskIds = const <String>[],
    String? waitingFor,
  }) {
    return Task(
      id: id,
      userId: userId,
      title: title,
      isCompleted: isCompleted,
      sourceNoteId: 'note-$id',
      sourceLineIndex: 0,
      projectId: projectId,
      dueAt: dueAt,
      priority: priority,
      estimatedMinutes: estimatedMinutes,
      dependsOnTaskIds: dependsOnTaskIds,
      waitingFor: waitingFor,
    );
  }

  ScheduleBlock block({
    String id = 'block',
    String userId = 'user',
    String taskId = 'task',
    String title = 'Revise chapter 4',
    DateTime? startsAt,
    DateTime? endsAt,
    ScheduleBlockStatus status = ScheduleBlockStatus.scheduled,
  }) {
    final start = startsAt ?? DateTime(2026, 9, 14, 11);
    return ScheduleBlock(
      id: id,
      userId: userId,
      taskId: taskId,
      title: title,
      startsAt: start,
      endsAt: endsAt ?? start.add(const Duration(hours: 1)),
      status: status,
      createdAt: DateTime(2026, 9, 13),
      updatedAt: DateTime(2026, 9, 13),
    );
  }

  AskJotCueContext context({
    String userId = 'user',
    List<Task>? tasks,
    List<Project>? projects,
    List<ScheduleBlock>? blocks,
    DateTime? currentTime,
  }) {
    final resolvedNow = currentTime ?? now;
    final resolvedProjects = projects ?? [project()];
    final resolvedTasks =
        tasks ??
        [task(dueAt: DateTime(2026, 9, 15, 18), priority: PriorityLevel.high)];
    final resolvedBlocks = blocks ?? [block()];
    final dependencies = const TaskDependencyAnalyzer().analyze(resolvedTasks);
    final pulse = PulseOverview.build(
      projects: resolvedProjects,
      tasks: resolvedTasks,
      now: resolvedNow,
      dependencyAnalysis: dependencies,
    );
    final loop = DailyPulseLoop.build(
      now: resolvedNow,
      pulse: pulse,
      blocks: resolvedBlocks,
    );
    return AskJotCueContext(
      now: resolvedNow,
      userId: userId,
      pulse: pulse,
      dailyLoop: loop,
      tasks: resolvedTasks,
      projects: resolvedProjects,
      blocks: resolvedBlocks,
      dependencyAnalysis: dependencies,
    );
  }

  AssistantAccountGuard guard([String? Function()? currentUserId]) {
    return AssistantAccountGuard(currentUserId: currentUserId ?? () => 'user');
  }

  test(
    'Patch 33 assistant evaluation scorecard meets release safety gates',
    () async {
      final score = _EvaluationScorecard();

      AskJotCueAnswer local(
        String id,
        String query,
        AskJotCueContext assistantContext,
      ) {
        final stopwatch = Stopwatch()..start();
        final answer = engine.answer(query: query, context: assistantContext);
        stopwatch.stop();
        score.localLatency(id, stopwatch.elapsed);
        return answer;
      }

      Future<AskJotCueAnswer> hybrid(
        String id, {
        required String query,
        required AskJotCueContext assistantContext,
        required _FakeGateway gateway,
        AssistantAccountGuard? accountGuard,
      }) async {
        final service = HybridAskJotCueService(
          accountGuard: accountGuard ?? guard(),
          localEngine: engine,
          gateway: gateway,
        );
        final stopwatch = Stopwatch()..start();
        final answer = await service.answer(
          query: query,
          context: assistantContext,
          preferences: const AiAssistantPreferences(
            mode: AiAssistantMode.hybrid,
          ),
        );
        stopwatch.stop();
        score.hybridLatency(id, stopwatch.elapsed);
        return answer;
      }

      final exactTasks = [
        task(id: 'report-draft', title: 'Report draft', projectId: null),
        task(id: 'report-review', title: 'Report review', projectId: null),
      ];
      final exact = local(
        'LOC-001',
        'Mark Report draft done',
        context(tasks: exactTasks, projects: const [], blocks: const []),
      );
      score.action(
        'LOC-001 exact completion action',
        exact.intent == AskJotCueIntent.action &&
            exact.actionProposal?.kind == AskJotCueActionKind.taskCompletion,
      );
      score.target(
        'LOC-001 exact completion target',
        exact.actionProposal?.taskId == 'report-draft',
      );

      final ambiguousTask = local(
        'LOC-002',
        'Mark Report done',
        context(tasks: exactTasks, projects: const [], blocks: const []),
      );
      score.action(
        'LOC-002 ambiguous task abstains',
        ambiguousTask.intent == AskJotCueIntent.action &&
            ambiguousTask.actionProposal == null,
      );
      score.target(
        'LOC-002 ambiguous task never guesses',
        ambiguousTask.actionProposal == null &&
            ambiguousTask.text.contains('More than one Task matches'),
      );

      final ambiguousProject = local(
        'LOC-003',
        'Put Revise chapter 4 under Thesis',
        context(
          tasks: [task(projectId: null)],
          projects: [
            project(id: 'thesis-draft', name: 'Thesis Draft'),
            project(id: 'thesis-research', name: 'Thesis Research'),
          ],
          blocks: const [],
        ),
      );
      score.action(
        'LOC-003 ambiguous project abstains',
        ambiguousProject.actionProposal == null,
      );
      score.target(
        'LOC-003 ambiguous project never guesses',
        ambiguousProject.text.contains('More than one Project matches'),
      );

      final deadline = local(
        'LOC-004',
        'Set Revise chapter 4 due Sep 30',
        context(blocks: const []),
      );
      score.action(
        'LOC-004 deadline action',
        deadline.actionProposal?.kind == AskJotCueActionKind.taskMetadata,
      );
      score.target(
        'LOC-004 deadline target/value',
        deadline.actionProposal?.taskId == 'task' &&
            deadline.actionProposal?.metadataUpdate?.dueAt ==
                DateTime(2026, 9, 30, 23, 59),
      );

      final selfDependency = local(
        'LOC-005',
        'Make Revise chapter 4 depend on Revise chapter 4',
        context(blocks: const []),
      );
      score.action(
        'LOC-005 self dependency rejected',
        selfDependency.actionProposal == null &&
            selfDependency.title == 'Invalid dependency',
      );

      final collision = local(
        'LOC-006',
        'Move Revise chapter 4 tomorrow at 15:00',
        context(
          blocks: [
            block(),
            block(
              id: 'occupied',
              taskId: 'other',
              title: 'Other work',
              startsAt: DateTime(2026, 9, 15, 15, 30),
              endsAt: DateTime(2026, 9, 15, 16, 30),
            ),
          ],
          tasks: [
            task(),
            task(id: 'other', title: 'Other work', projectId: null),
          ],
        ),
      );
      score.action(
        'LOC-006 impossible schedule rejected',
        collision.actionProposal == null &&
            collision.title == 'That time is already occupied',
      );

      final unsupported = local(
        'LOC-007',
        'Send an email to my lecturer',
        context(blocks: const []),
      );
      score.action(
        'LOC-007 unsupported request bounded',
        unsupported.intent == AskJotCueIntent.unknown &&
            unsupported.actionProposal == null,
      );

      final bestNext = local(
        'LOC-008',
        'What should I do now?',
        context(
          tasks: [
            task(
              id: 'blocked',
              title: 'Blocked critical',
              projectId: null,
              dueAt: DateTime(2026, 9, 14, 12),
              priority: PriorityLevel.critical,
              waitingFor: 'Susan',
            ),
            task(
              id: 'ready',
              title: 'Ready work',
              projectId: null,
              dueAt: DateTime(2026, 9, 15, 18),
              priority: PriorityLevel.high,
            ),
          ],
          projects: const [],
          blocks: const [],
        ),
      );
      score.bestNext(
        'LOC-008 blocked work excluded from best next',
        bestNext.intent == AskJotCueIntent.focusNow &&
            bestNext.text.contains('Best next: Ready work') &&
            !bestNext.text.contains('Best next: Blocked critical'),
      );

      final unavailableGateway = _FakeGateway(error: StateError('offline'));
      final unavailable = await hybrid(
        'HYB-001',
        query: 'Explain how to approach this week',
        assistantContext: context(blocks: const []),
        gateway: unavailableGateway,
      );
      score.fallback(
        'HYB-001 gateway unavailable fails safely',
        unavailableGateway.calls == 1 &&
            unavailable.actionProposal == null &&
            unavailable.text.contains('temporarily unavailable'),
      );
      score.action(
        'HYB-001 unavailable Hybrid creates no action',
        unavailable.actionProposal == null,
      );

      final maliciousGateway = _FakeGateway(
        response: const AiGatewayResponse(
          toolCall: AiGatewayToolCall(
            name: 'email.send',
            arguments: {'to': 'attacker@example.com'},
          ),
        ),
      );
      final malicious = await hybrid(
        'HYB-002',
        query: 'Handle this externally for me',
        assistantContext: context(blocks: const []),
        gateway: maliciousGateway,
      );
      score.fallback(
        'HYB-002 unsupported malicious tool rejected',
        maliciousGateway.calls == 1 &&
            malicious.actionProposal == null &&
            malicious.text.contains('could not be safely used'),
      );
      score.action(
        'HYB-002 malicious tool creates no action',
        malicious.actionProposal == null,
      );

      final staleGateway = _FakeGateway(
        response: const AiGatewayResponse(
          toolCall: AiGatewayToolCall(
            name: 'task.set_completion',
            arguments: {'taskId': 'deleted-task', 'completed': true},
          ),
        ),
      );
      final stale = await hybrid(
        'HYB-003',
        query: 'Take care of the old task',
        assistantContext: context(blocks: const []),
        gateway: staleGateway,
      );
      score.target(
        'HYB-003 deleted target rejected',
        stale.actionProposal == null,
      );
      score.action(
        'HYB-003 deleted target creates no action',
        stale.actionProposal == null,
      );

      final validGateway = _FakeGateway(
        response: const AiGatewayResponse(
          toolCall: AiGatewayToolCall(
            name: 'task.set_priority',
            arguments: {'taskId': 'task', 'priority': 'critical'},
          ),
        ),
      );
      final validHybrid = await hybrid(
        'HYB-004',
        query: 'Make this much more urgent',
        assistantContext: context(blocks: const []),
        gateway: validGateway,
      );
      score.action(
        'HYB-004 valid Hybrid tool returns typed action',
        validHybrid.usedRemoteAi &&
            validHybrid.actionProposal?.kind ==
                AskJotCueActionKind.taskPriority,
      );
      score.target(
        'HYB-004 valid Hybrid tool resolves current target',
        validHybrid.actionProposal?.taskId == 'task' &&
            validHybrid.actionProposal?.targetPriority ==
                PriorityLevel.critical,
      );

      final switchedGateway = _FakeGateway(
        response: const AiGatewayResponse(answer: 'Should never be called'),
      );
      final switched = await hybrid(
        'HYB-005',
        query: 'Explain this plan',
        assistantContext: context(blocks: const []),
        gateway: switchedGateway,
        accountGuard: guard(() => 'other-user'),
      );
      score.fallback(
        'HYB-005 account switch blocks Hybrid before gateway',
        switchedGateway.calls == 0 &&
            switched.actionProposal == null &&
            switched.title == 'Account changed',
      );
      score.action(
        'HYB-005 account switch creates no action',
        switched.actionProposal == null,
      );

      final mixedGateway = _FakeGateway(
        response: const AiGatewayResponse(answer: 'Should never be called'),
      );
      final mixed = await hybrid(
        'HYB-006',
        query: 'Explain this plan',
        assistantContext: context(
          tasks: [
            task(),
            task(
              id: 'foreign',
              userId: 'other-user',
              title: 'Foreign task',
              projectId: null,
            ),
          ],
          blocks: const [],
        ),
        gateway: mixedGateway,
      );
      score.fallback(
        'HYB-006 mixed-account context blocked before gateway',
        mixedGateway.calls == 0 &&
            mixed.actionProposal == null &&
            mixed.title == 'Account changed',
      );

      final timezoneGateway = _FakeGateway(
        response: const AiGatewayResponse(
          toolCall: AiGatewayToolCall(
            name: 'schedule.move_block',
            arguments: {
              'blockId': 'block',
              'startsAt': '2026-09-15T15:00:00+02:00',
            },
          ),
        ),
      );
      final timezone = await hybrid(
        'HYB-007',
        query: 'Move that work to the proposed time',
        assistantContext: context(),
        gateway: timezoneGateway,
      );
      score.action(
        'HYB-007 timezone tool remains typed schedule move',
        timezone.actionProposal?.kind == AskJotCueActionKind.scheduleMove,
      );
      score.target(
        'HYB-007 timezone offset preserves instant',
        timezone.actionProposal?.toStartsAt?.toUtc() ==
            DateTime.utc(2026, 9, 15, 13),
      );

      final completionProposal = exact.actionProposal!;
      var completionMutations = 0;
      final switchedExecutor = _executor(
        accountGuard: guard(() => 'other-user'),
        repository: _FakeScheduleBlocksRepository(const []),
        onCompletion: () {
          completionMutations += 1;
        },
      );
      await _expectStateError(
        () => switchedExecutor.execute(
          preferences: const AutomationPreferences(
            level: AutomationLevel.approval,
          ),
          proposal: completionProposal,
          now: now,
          approved: true,
        ),
      );
      score.mutation(
        'MUT-001 account switch before Apply',
        actual: completionMutations,
        expected: 0,
      );

      var deletedTargetMutations = 0;
      final deletedExecutor = _executor(
        accountGuard: guard(),
        repository: _FakeScheduleBlocksRepository(const []),
        onCompletion: () {
          throw StateError('Task was deleted before Apply.');
        },
        onSuccessfulCompletion: () {
          deletedTargetMutations += 1;
        },
      );
      await _expectStateError(
        () => deletedExecutor.execute(
          preferences: const AutomationPreferences(
            level: AutomationLevel.approval,
          ),
          proposal: completionProposal,
          now: now,
          approved: true,
        ),
      );
      score.mutation(
        'MUT-002 deleted Task rejected by apply-time service',
        actual: deletedTargetMutations,
        expected: 0,
      );

      final movePreview = local(
        'MUT-003-preview',
        'Move Revise chapter 4 tomorrow at 15:00',
        context(),
      ).actionProposal!;
      final deletedBlockRepository = _FakeScheduleBlocksRepository(const []);
      final deletedBlockExecutor = _executor(
        accountGuard: guard(),
        repository: deletedBlockRepository,
      );
      await _expectStateError(
        () => deletedBlockExecutor.execute(
          preferences: const AutomationPreferences(
            level: AutomationLevel.approval,
          ),
          proposal: movePreview,
          now: now,
          approved: true,
        ),
      );
      score.mutation(
        'MUT-003 deleted schedule block',
        actual: deletedBlockRepository.rescheduleCalls,
        expected: 0,
      );

      final changedBlockRepository = _FakeScheduleBlocksRepository([
        block(
          startsAt: DateTime(2026, 9, 14, 12),
          endsAt: DateTime(2026, 9, 14, 13),
        ),
      ]);
      final changedBlockExecutor = _executor(
        accountGuard: guard(),
        repository: changedBlockRepository,
      );
      await _expectStateError(
        () => changedBlockExecutor.execute(
          preferences: const AutomationPreferences(
            level: AutomationLevel.approval,
          ),
          proposal: movePreview,
          now: now,
          approved: true,
        ),
      );
      score.mutation(
        'MUT-004 stale schedule preview',
        actual: changedBlockRepository.rescheduleCalls,
        expected: 0,
      );

      final clockRepository = _FakeScheduleBlocksRepository([block()]);
      final clockExecutor = _executor(
        accountGuard: guard(),
        repository: clockRepository,
      );
      await _expectStateError(
        () => clockExecutor.execute(
          preferences: const AutomationPreferences(
            level: AutomationLevel.approval,
          ),
          proposal: movePreview,
          now: DateTime(2026, 9, 15, 16),
          approved: true,
        ),
      );
      score.mutation(
        'MUT-005 clock advanced past target',
        actual: clockRepository.rescheduleCalls,
        expected: 0,
      );

      final calendarRepository = _FakeScheduleBlocksRepository([block()]);
      final calendarExecutor = _executor(
        accountGuard: guard(),
        repository: calendarRepository,
        calendarLinked: true,
      );
      await _expectStateError(
        () => calendarExecutor.execute(
          preferences: const AutomationPreferences(
            level: AutomationLevel.approval,
          ),
          proposal: movePreview,
          now: now,
          approved: true,
        ),
      );
      score.mutation(
        'MUT-006 calendar-linked block',
        actual: calendarRepository.rescheduleCalls,
        expected: 0,
      );

      final unavailableRepository = _FakeScheduleBlocksRepository([block()]);
      final unavailableExecutor = _executor(
        accountGuard: guard(),
        repository: unavailableRepository,
        scheduleAvailable: false,
      );
      await _expectStateError(
        () => unavailableExecutor.execute(
          preferences: const AutomationPreferences(
            level: AutomationLevel.approval,
          ),
          proposal: movePreview,
          now: now,
          approved: true,
        ),
      );
      score.mutation(
        'MUT-007 impossible current availability',
        actual: unavailableRepository.rescheduleCalls,
        expected: 0,
      );

      var planMutations = 0;
      final planActionExecutor = _executor(
        accountGuard: guard(),
        repository: _FakeScheduleBlocksRepository(const []),
        onCompletion: () {
          planMutations += 1;
        },
        onMetadata: () {
          throw StateError('metadata changed');
        },
      );
      final partialPlanExecutor = AskJotCuePlanExecutor(
        actionExecutor: planActionExecutor,
      );
      final partialResult = await partialPlanExecutor.execute(
        preferences: const AutomationPreferences(
          level: AutomationLevel.approval,
        ),
        plan: _plan([
          _completion('one'),
          _priority('two'),
          _completion('three'),
        ]),
        now: now,
        approved: true,
      );
      score.action(
        'PLAN-001 partial failure is reported honestly',
        partialResult.succeededCount == 1 &&
            !partialResult.isComplete &&
            partialResult.steps[1].status == AskJotCuePlanStepStatus.failed &&
            partialResult.steps[2].status == AskJotCuePlanStepStatus.notRun,
      );
      score.mutation(
        'PLAN-001 later steps stop after failure',
        actual: planMutations,
        expected: 1,
      );

      var currentUser = 'user';
      var switchedPlanMutations = 0;
      final switchingExecutor = _executor(
        accountGuard: guard(() => currentUser),
        repository: _FakeScheduleBlocksRepository(const []),
        onCompletion: () {
          switchedPlanMutations += 1;
          currentUser = 'other-user';
        },
      );
      final switchingPlanExecutor = AskJotCuePlanExecutor(
        actionExecutor: switchingExecutor,
      );
      final switchingResult = await switchingPlanExecutor.execute(
        preferences: const AutomationPreferences(
          level: AutomationLevel.approval,
        ),
        plan: _plan([
          _completion('one'),
          _priority('two'),
          _completion('three'),
        ]),
        now: now,
        approved: true,
      );
      score.action(
        'PLAN-002 account switch stops remaining steps',
        switchingResult.succeededCount == 1 &&
            !switchingResult.isComplete &&
            switchingResult.steps[1].status == AskJotCuePlanStepStatus.failed &&
            switchingResult.steps[2].status == AskJotCuePlanStepStatus.notRun,
      );
      score.mutation(
        'PLAN-002 no cross-account continuation',
        actual: switchedPlanMutations,
        expected: 1,
      );

      final report = score.report();
      // ignore: avoid_print
      print(report);

      expect(
        score.failures,
        isEmpty,
        reason: '${score.failures.join('\n')}\n\n$report',
      );
      expect(
        score.wrongActions,
        0,
        reason: 'Patch 33 release target requires zero wrong actions.',
      );
      expect(
        score.falsePositiveMutations,
        0,
        reason:
            'Patch 33 release target requires zero silent incorrect mutations.',
      );
    },
  );
}

AskJotCueActionExecutor _executor({
  required AssistantAccountGuard accountGuard,
  required _FakeScheduleBlocksRepository repository,
  void Function()? onCompletion,
  void Function()? onSuccessfulCompletion,
  void Function()? onMetadata,
  bool calendarLinked = false,
  bool scheduleAvailable = true,
}) {
  return AskJotCueActionExecutor(
    accountGuard: accountGuard,
    policy: const AutomationPolicy(),
    setTaskCompletion:
        ({
          required userId,
          required noteId,
          required taskId,
          required isCompleted,
        }) async {
          onCompletion?.call();
          onSuccessfulCompletion?.call();
        },
    updateTaskMetadata:
        ({
          required userId,
          required noteId,
          required taskId,
          required TaskMetadataUpdate update,
        }) async {
          onMetadata?.call();
        },
    scheduleBlocks: repository,
    isCalendarLinked: (_) async => calendarLinked,
    isScheduleMoveAvailable:
        ({required blockId, required startsAt, required endsAt}) async =>
            scheduleAvailable,
  );
}

AskJotCueActionProposal _completion(String taskId) {
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

AskJotCueActionProposal _priority(String taskId) {
  return AskJotCueActionProposal(
    id: 'priority:$taskId:high',
    kind: AskJotCueActionKind.taskPriority,
    userId: 'user',
    taskId: taskId,
    taskTitle: 'Task $taskId',
    sourceNoteId: 'note-$taskId',
    targetPriority: PriorityLevel.high,
    previewTitle: 'Change priority',
    previewText: 'Preview',
  );
}

AskJotCueActionPlan _plan(List<AskJotCueActionProposal> steps) {
  return AskJotCueActionPlan(
    id: 'evaluation-plan:${steps.map((step) => step.id).join('|')}',
    steps: steps,
    previewTitle: 'Evaluation plan',
    previewText: 'Evaluation preview',
  );
}

Future<void> _expectStateError(Future<Object?> Function() action) async {
  try {
    await action();
    fail('Expected StateError, but action completed.');
  } on StateError {
    return;
  }
}

class _EvaluationScorecard {
  final List<String> failures = <String>[];

  int actionChecks = 0;
  int actionCorrect = 0;
  int targetChecks = 0;
  int targetCorrect = 0;
  int bestNextChecks = 0;
  int bestNextCorrect = 0;
  int fallbackChecks = 0;
  int fallbackCorrect = 0;
  int mutationChecks = 0;
  int falsePositiveMutations = 0;
  int wrongActions = 0;

  final List<Duration> localDurations = <Duration>[];
  final List<Duration> hybridDurations = <Duration>[];

  void action(String id, bool correct) {
    actionChecks += 1;
    if (correct) {
      actionCorrect += 1;
    } else {
      wrongActions += 1;
      failures.add('$id: wrong intent/action result');
    }
  }

  void target(String id, bool correct) {
    targetChecks += 1;
    if (correct) {
      targetCorrect += 1;
    } else {
      failures.add('$id: wrong or unsafe target resolution');
    }
  }

  void bestNext(String id, bool correct) {
    bestNextChecks += 1;
    if (correct) {
      bestNextCorrect += 1;
    } else {
      failures.add('$id: best-next-action quality regression');
    }
  }

  void fallback(String id, bool correct) {
    fallbackChecks += 1;
    if (correct) {
      fallbackCorrect += 1;
    } else {
      failures.add('$id: unsafe or incorrect fallback behavior');
    }
  }

  void mutation(String id, {required int actual, required int expected}) {
    mutationChecks += 1;
    if (actual == expected) return;
    if (actual > expected) {
      falsePositiveMutations += actual - expected;
    }
    failures.add('$id: expected $expected mutation(s), observed $actual');
  }

  void localLatency(String id, Duration duration) {
    localDurations.add(duration);
    if (duration > const Duration(seconds: 5)) {
      failures.add('$id: local evaluation exceeded 5 seconds');
    }
  }

  void hybridLatency(String id, Duration duration) {
    hybridDurations.add(duration);
    if (duration > const Duration(seconds: 5)) {
      failures.add('$id: Hybrid evaluation exceeded 5 seconds');
    }
  }

  String report() {
    String ratio(int correct, int total) =>
        total == 0 ? 'n/a' : '${(correct * 100 / total).toStringAsFixed(1)}%';

    String average(List<Duration> values) {
      if (values.isEmpty) return 'n/a';
      final micros = values.fold<int>(
        0,
        (sum, value) => sum + value.inMicroseconds,
      );
      return '${(micros / values.length / 1000).toStringAsFixed(2)} ms';
    }

    final wrongActionRate = actionChecks == 0
        ? 'n/a'
        : '${(wrongActions * 100 / actionChecks).toStringAsFixed(1)}%';
    final falsePositiveRate = mutationChecks == 0
        ? 'n/a'
        : '${(falsePositiveMutations * 100 / mutationChecks).toStringAsFixed(1)}%';

    return [
      'PATCH 33 ASSISTANT EVALUATION SCORECARD',
      'Intent/action accuracy: ${ratio(actionCorrect, actionChecks)} ($actionCorrect/$actionChecks)',
      'Target-resolution accuracy: ${ratio(targetCorrect, targetChecks)} ($targetCorrect/$targetChecks)',
      'Wrong-action rate: $wrongActionRate ($wrongActions wrong)',
      'False-positive mutation rate: $falsePositiveRate ($falsePositiveMutations extra mutation(s))',
      'Best-next-action quality: ${ratio(bestNextCorrect, bestNextChecks)} ($bestNextCorrect/$bestNextChecks)',
      'Fallback safety: ${ratio(fallbackCorrect, fallbackChecks)} ($fallbackCorrect/$fallbackChecks)',
      'Observed local latency: ${average(localDurations)} across ${localDurations.length} scenarios',
      'Observed Hybrid latency/fallback: ${average(hybridDurations)} across ${hybridDurations.length} scenarios',
      'Silent incorrect mutation release target: ${falsePositiveMutations == 0 ? 'PASS' : 'FAIL'}',
    ].join('\n');
  }
}

class _FakeGateway implements AiGatewayClient {
  _FakeGateway({this.response, this.error});

  final AiGatewayResponse? response;
  final Object? error;
  int calls = 0;

  @override
  bool get isConfigured => true;

  @override
  Future<AiGatewayResponse> respond({
    required String query,
    required Map<String, Object?> context,
    required List<Map<String, Object?>> allowedTools,
  }) async {
    calls += 1;
    final failure = error;
    if (failure != null) throw failure;
    final value = response;
    if (value == null) {
      throw StateError('No fake Hybrid response configured.');
    }
    return value;
  }
}

class _FakeScheduleBlocksRepository implements ScheduleBlocksRepository {
  _FakeScheduleBlocksRepository(List<ScheduleBlock> blocks)
    : blocks = List<ScheduleBlock>.from(blocks);

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
      updatedAt: DateTime(2026, 9, 14, 10),
    );
    final index = blocks.indexWhere((item) => item.id == block.id);
    if (index >= 0) blocks[index] = updated;
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
