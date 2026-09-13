import '../../../core/models/priority_level.dart';
import '../../projects/models/project.dart';
import '../../pulse/models/daily_pulse_loop.dart';
import '../../pulse/models/pulse_overview.dart';
import '../../scheduling/models/replanning_overview.dart';
import '../../scheduling/models/schedule_block.dart';
import '../../scheduling/models/scheduling_day_state.dart';
import '../../tasks/models/task.dart';

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

enum AskJotCueActionKind { taskCompletion, taskPriority, scheduleMove }

class AskJotCueContext {
  const AskJotCueContext({
    required this.now,
    required this.pulse,
    required this.dailyLoop,
    required this.tasks,
    required this.projects,
    required this.blocks,
    this.scheduling,
    this.replanning,
  });

  final DateTime now;
  final PulseOverview pulse;
  final DailyPulseLoop dailyLoop;
  final List<Task> tasks;
  final List<Project> projects;
  final List<ScheduleBlock> blocks;
  final SchedulingDayState? scheduling;
  final ReplanningOverview? replanning;

  AskJotCueContext copyWith({
    PulseOverview? pulse,
    DailyPulseLoop? dailyLoop,
    List<Task>? tasks,
    List<Project>? projects,
    List<ScheduleBlock>? blocks,
    Object? scheduling = _unchanged,
    Object? replanning = _unchanged,
  }) {
    return AskJotCueContext(
      now: now,
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
    );
  }
}

class AskJotCueActionProposal {
  const AskJotCueActionProposal({
    required this.id,
    required this.kind,
    required this.userId,
    required this.taskId,
    required this.taskTitle,
    required this.previewTitle,
    required this.previewText,
    this.sourceNoteId,
    this.targetCompletion,
    this.targetPriority,
    this.blockId,
    this.fromStartsAt,
    this.fromEndsAt,
    this.toStartsAt,
    this.toEndsAt,
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
  final String? blockId;
  final DateTime? fromStartsAt;
  final DateTime? fromEndsAt;
  final DateTime? toStartsAt;
  final DateTime? toEndsAt;
}

class AskJotCueAnswer {
  const AskJotCueAnswer({
    required this.intent,
    required this.text,
    this.title,
    this.actionProposal,
  });

  final AskJotCueIntent intent;
  final String? title;
  final String text;
  final AskJotCueActionProposal? actionProposal;
}

class AskJotCueMessage {
  const AskJotCueMessage({
    required this.text,
    required this.isUser,
    this.actionProposal,
  });

  final String text;
  final bool isUser;
  final AskJotCueActionProposal? actionProposal;
}

const _unchanged = Object();
