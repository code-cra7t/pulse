import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/features/assistant/data/ai_tool_proposal_adapter.dart';
import 'package:pulse/features/assistant/models/ai_gateway.dart';
import 'package:pulse/features/assistant/models/ask_jotcue.dart';
import 'package:pulse/features/projects/models/project.dart';
import 'package:pulse/features/pulse/models/daily_pulse_loop.dart';
import 'package:pulse/features/pulse/models/pulse_overview.dart';
import 'package:pulse/features/scheduling/models/schedule_block.dart';
import 'package:pulse/features/tasks/models/task.dart';

void main() {
  final now = DateTime(2026, 9, 13, 10);
  const pulse = PulseOverview(
    focusItems: [],
    cues: [],
    upcomingProjects: [],
    openTaskCount: 1,
    overdueCount: 0,
    dueTodayCount: 0,
    focusEstimatedMinutes: 0,
  );
  final task = Task(
    id: 'task',
    userId: 'user',
    title: 'Revise chapter 4',
    isCompleted: false,
    sourceNoteId: 'note',
    sourceLineIndex: 0,
  );
  final prerequisite = Task(
    id: 'prereq',
    userId: 'user',
    title: 'Finish CV',
    isCompleted: false,
    sourceNoteId: 'note-prereq',
    sourceLineIndex: 0,
  );
  final project = Project(
    id: 'project',
    userId: 'user',
    name: 'Applications',
    createdAt: now,
    updatedAt: now,
  );
  final block = ScheduleBlock(
    id: 'block',
    userId: 'user',
    taskId: 'task',
    title: 'Revise chapter 4',
    startsAt: DateTime(2026, 9, 13, 11),
    endsAt: DateTime(2026, 9, 13, 12),
    createdAt: now,
    updatedAt: now,
  );
  late final context = AskJotCueContext(
    now: now,
    userId: 'user',
    pulse: pulse,
    dailyLoop: DailyPulseLoop.build(now: now, pulse: pulse, blocks: [block]),
    tasks: [task, prerequisite],
    projects: [project],
    blocks: [block],
  );
  const adapter = AiToolProposalAdapter();

  test(
    'completion tool resolves current local task into standard proposal',
    () {
      final proposal = adapter.adapt(
        const AiGatewayToolCall(
          name: 'task.set_completion',
          arguments: {'taskId': 'task', 'completed': true},
        ),
        context,
      );
      expect(proposal?.kind, AskJotCueActionKind.taskCompletion);
      expect(proposal?.sourceNoteId, 'note');
      expect(proposal?.targetCompletion, isTrue);
    },
  );

  test('priority tool rejects unknown priority and stale task IDs', () {
    expect(
      adapter.adapt(
        const AiGatewayToolCall(
          name: 'task.set_priority',
          arguments: {'taskId': 'missing', 'priority': 'critical'},
        ),
        context,
      ),
      isNull,
    );
    expect(
      adapter.adapt(
        const AiGatewayToolCall(
          name: 'task.set_priority',
          arguments: {'taskId': 'task', 'priority': 'super'},
        ),
        context,
      ),
      isNull,
    );
  });

  test('deadline tool rebuilds a local metadata proposal', () {
    final proposal = adapter.adapt(
      const AiGatewayToolCall(
        name: 'task.set_deadline',
        arguments: {'taskId': 'task', 'dueAt': '2026-09-30', 'clear': false},
      ),
      context,
    );

    expect(proposal?.kind, AskJotCueActionKind.taskMetadata);
    expect(proposal?.metadataUpdate?.dueAt, DateTime(2026, 9, 30, 23, 59));
  });

  test('project tool resolves project ID against current local state', () {
    final proposal = adapter.adapt(
      const AiGatewayToolCall(
        name: 'task.assign_project',
        arguments: {'taskId': 'task', 'projectId': 'project', 'clear': false},
      ),
      context,
    );

    expect(proposal?.metadataUpdate?.projectId, 'project');
    expect(
      adapter.adapt(
        const AiGatewayToolCall(
          name: 'task.assign_project',
          arguments: {'taskId': 'task', 'projectId': 'missing', 'clear': false},
        ),
        context,
      ),
      isNull,
    );
  });

  test('dependency tool rejects self and stale IDs', () {
    final proposal = adapter.adapt(
      const AiGatewayToolCall(
        name: 'task.set_dependencies',
        arguments: {
          'taskId': 'task',
          'dependsOnTaskIds': ['prereq'],
        },
      ),
      context,
    );
    expect(proposal?.metadataUpdate?.dependsOnTaskIds, ['prereq']);

    expect(
      adapter.adapt(
        const AiGatewayToolCall(
          name: 'task.set_dependencies',
          arguments: {
            'taskId': 'task',
            'dependsOnTaskIds': ['task'],
          },
        ),
        context,
      ),
      isNull,
    );
    expect(
      adapter.adapt(
        const AiGatewayToolCall(
          name: 'task.set_dependencies',
          arguments: {
            'taskId': 'task',
            'dependsOnTaskIds': ['missing'],
          },
        ),
        context,
      ),
      isNull,
    );
  });

  test('waiting-for tool enforces bounded explicit text', () {
    final proposal = adapter.adapt(
      const AiGatewayToolCall(
        name: 'task.set_waiting_for',
        arguments: {
          'taskId': 'task',
          'waitingFor': 'supervisor feedback',
          'clear': false,
        },
      ),
      context,
    );
    expect(proposal?.metadataUpdate?.waitingFor, 'supervisor feedback');
  });

  test('schedule tool preserves current block duration', () {
    final proposal = adapter.adapt(
      const AiGatewayToolCall(
        name: 'schedule.move_block',
        arguments: {'blockId': 'block', 'startsAt': '2026-09-14T15:00:00'},
      ),
      context,
    );
    expect(proposal?.kind, AskJotCueActionKind.scheduleMove);
    expect(proposal?.toStartsAt, DateTime(2026, 9, 14, 15));
    expect(proposal?.toEndsAt, DateTime(2026, 9, 14, 16));
  });

  test('capture tool is reparsed locally before producing a proposal', () {
    final proposal = adapter.adapt(
      const AiGatewayToolCall(
        name: 'capture.create',
        arguments: {'text': 'Submit HPC report by Sep 30'},
      ),
      context,
    );

    expect(proposal?.kind, AskJotCueActionKind.structuredCapture);
    expect(proposal?.captureDraft?.tasks, ['Submit HPC report']);
    expect(proposal?.captureDraft?.deadline, DateTime(2026, 9, 30, 23, 59));
  });

  test('note tool only previews explicit note text', () {
    final proposal = adapter.adapt(
      const AiGatewayToolCall(
        name: 'note.save',
        arguments: {'text': 'Sarah moved the meeting to Friday'},
      ),
      context,
    );

    expect(proposal?.kind, AskJotCueActionKind.noteCreate);
    expect(proposal?.noteText, 'Sarah moved the meeting to Friday');
  });

  test('unknown remote tools never produce a proposal', () {
    expect(
      adapter.adapt(
        const AiGatewayToolCall(
          name: 'calendar.delete_everything',
          arguments: {'taskId': 'task'},
        ),
        context,
      ),
      isNull,
    );
  });
}
