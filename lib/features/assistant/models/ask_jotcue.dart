import '../../../core/models/priority_level.dart';
import '../../capture/models/capture_draft.dart';
import '../../personal_graph/models/personal_graph.dart';
import '../../projects/models/project.dart';
import '../../pulse/models/daily_pulse_loop.dart';
import '../../pulse/models/pulse_overview.dart';
import '../../scheduling/models/replanning_overview.dart';
import '../../scheduling/models/schedule_block.dart';
import '../../scheduling/models/scheduling_day_state.dart';
import '../../tasks/models/task.dart';
import '../../tasks/models/task_action_cue.dart';
import '../../tasks/models/task_metadata_update.dart';

enum AskJotCueIntent {
  action,
  focusNow,
  dueSoon,
  overdue,
  capacityToday,
  scheduleToday,
  nextBlock,
  projects,
  needsAttention,
  help,
  unknown,
}

enum AskJotCueActionKind {
  taskCompletion,
  taskPriority,
  taskMetadata,
  scheduleMove,
  structuredCapture,
  noteCreate,
}

class AskJotCueContext {
  const AskJotCueContext({
    required this.now,
    this.userId,
    required this.pulse,
    required this.dailyLoop,
    required this.tasks,
    required this.projects,
    required this.blocks,
    this.scheduling,
    this.replanning,
    this.dependencyAnalysis,
    this.personalGraph,
  });

  final DateTime now;
  final String? userId;
  final PulseOverview pulse;
  final DailyPulseLoop dailyLoop;
  final List<Task> tasks;
  final List<Project> projects;
  final List<ScheduleBlock> blocks;
  final SchedulingDayState? scheduling;
  final ReplanningOverview? replanning;
  final TaskDependencyAnalysis? dependencyAnalysis;
  final PersonalGraph? personalGraph;

  AskJotCueContext copyWith({
    PulseOverview? pulse,
    DailyPulseLoop? dailyLoop,
    List<Task>? tasks,
    List<Project>? projects,
    List<ScheduleBlock>? blocks,
    Object? scheduling = _unchanged,
    Object? replanning = _unchanged,
    Object? dependencyAnalysis = _unchanged,
    Object? personalGraph = _unchanged,
  }) {
    return AskJotCueContext(
      now: now,
      userId: userId,
      pulse: pulse ?? this.pulse,
      dailyLoop: dailyLoop ?? this.dailyLoop,
      tasks: tasks ?? this.tasks,
      projects: projects ?? this.projects,
      blocks: blocks ?? this.blocks,
      scheduling: identical(scheduling, _unchanged)
          ? this.scheduling
          : scheduling as SchedulingDayState?,
      replanning: identical(replanning, _unchanged)
          ? this.replanning
          : replanning as ReplanningOverview?,
      dependencyAnalysis: identical(dependencyAnalysis, _unchanged)
          ? this.dependencyAnalysis
          : dependencyAnalysis as TaskDependencyAnalysis?,
      personalGraph: identical(personalGraph, _unchanged)
          ? this.personalGraph
          : personalGraph as PersonalGraph?,
    );
  }
}

class AskJotCueActionProposal {
  const AskJotCueActionProposal({
    required this.id,
    required this.kind,
    required this.userId,
    this.taskId = '',
    this.taskTitle = '',
    required this.previewTitle,
    required this.previewText,
    this.sourceNoteId,
    this.targetCompletion,
    this.targetPriority,
    this.metadataUpdate,
    this.blockId,
    this.fromStartsAt,
    this.fromEndsAt,
    this.toStartsAt,
    this.toEndsAt,
    this.captureDraft,
    this.noteText,
  });

  final String id;
  final AskJotCueActionKind kind;
  final String userId;
  final String taskId;
  final String taskTitle;
  final String previewTitle;
  final String previewText;
  final String? sourceNoteId;
  final bool? targetCompletion;
  final PriorityLevel? targetPriority;
  final TaskMetadataUpdate? metadataUpdate;
  final String? blockId;
  final DateTime? fromStartsAt;
  final DateTime? fromEndsAt;
  final DateTime? toStartsAt;
  final DateTime? toEndsAt;
  final CaptureDraft? captureDraft;
  final String? noteText;
}

class AskJotCueAnswer {
  const AskJotCueAnswer({
    required this.intent,
    required this.text,
    this.title,
    this.actionProposal,
    this.usedRemoteAi = false,
  });

  final AskJotCueIntent intent;
  final String? title;
  final String text;
  final AskJotCueActionProposal? actionProposal;
  final bool usedRemoteAi;
}

class AskJotCueMessage {
  const AskJotCueMessage({
    required this.text,
    required this.isUser,
    this.actionProposal,
    this.usedRemoteAi = false,
  });

  final String text;
  final bool isUser;
  final AskJotCueActionProposal? actionProposal;
  final bool usedRemoteAi;
}

const _unchanged = Object();
