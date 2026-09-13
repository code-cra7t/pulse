import '../../projects/models/project.dart';
import '../../pulse/models/daily_pulse_loop.dart';
import '../../pulse/models/pulse_overview.dart';
import '../../scheduling/models/replanning_overview.dart';
import '../../scheduling/models/schedule_block.dart';
import '../../scheduling/models/scheduling_day_state.dart';
import '../../tasks/models/task.dart';

enum AskJotCueIntent {
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
}

class AskJotCueAnswer {
  const AskJotCueAnswer({required this.intent, required this.text, this.title});

  final AskJotCueIntent intent;
  final String? title;
  final String text;
}

class AskJotCueMessage {
  const AskJotCueMessage({required this.text, required this.isUser});

  final String text;
  final bool isUser;
}
