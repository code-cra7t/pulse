import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../notes/models/note.dart';
import '../../notes/providers/notes_providers.dart';
import '../../projects/models/project.dart';
import '../../projects/providers/project_providers.dart';
import '../../scheduling/models/schedule_block.dart';
import '../../scheduling/providers/scheduling_providers.dart';
import '../../tasks/providers/task_providers.dart';
import '../data/personal_graph_builder.dart';
import '../models/personal_graph.dart';

final personalGraphBuilderProvider = Provider<PersonalGraphBuilder>((ref) {
  return const PersonalGraphBuilder();
});

final personalGraphProvider = Provider<PersonalGraph>((ref) {
  final notes = ref.watch(notesStreamProvider).asData?.value ?? const <Note>[];
  final tasks = ref.watch(tasksProvider);
  final projects =
      ref.watch(projectsStreamProvider).asData?.value ?? const <Project>[];
  final blocks =
      ref.watch(scheduleBlocksStreamProvider).asData?.value ??
      const <ScheduleBlock>[];

  return ref
      .watch(personalGraphBuilderProvider)
      .build(
        notes: notes,
        tasks: tasks,
        projects: projects,
        scheduleBlocks: blocks,
      );
});

final taskGraphContextProvider =
    Provider.family<PersonalGraphTaskContext?, String>(
      (ref, taskId) => ref.watch(personalGraphProvider).taskContext(taskId),
    );
