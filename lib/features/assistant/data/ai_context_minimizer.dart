import '../models/ask_jotcue.dart';

/// Builds the smallest structured planning snapshot needed by the optional
/// remote assistant gateway.
///
/// Intentionally excluded: account identity, source Note IDs/line indexes,
/// Note bodies, reminder text, external calendar events, automation audit data,
/// notification history, and raw Personal Graph payloads.
class AiContextMinimizer {
  const AiContextMinimizer();

  Map<String, Object?> build(AskJotCueContext context) {
    return <String, Object?>{
      'now': context.now.toIso8601String(),
      'tasks': [
        for (final task in context.tasks.take(200))
          <String, Object?>{
            'id': task.id,
            'title': task.title,
            'completed': task.isCompleted,
            'projectId': task.projectId,
            'dueAt': task.dueAt?.toIso8601String(),
            'priority': task.priority.name,
            'estimatedMinutes': task.estimatedMinutes,
            'flexible': task.isFlexible,
            'dependsOnTaskIds': task.dependsOnTaskIds,
            'hasWaitingFor': task.waitingFor?.trim().isNotEmpty ?? false,
          },
      ],
      'projects': [
        for (final project in context.projects.take(100))
          <String, Object?>{
            'id': project.id,
            'name': project.name,
            'deadline': project.deadline?.toIso8601String(),
            'priority': project.priority.name,
          },
      ],
      'scheduleBlocks': [
        for (final block in context.blocks.take(200))
          <String, Object?>{
            'id': block.id,
            'taskId': block.taskId,
            'startsAt': block.startsAt.toIso8601String(),
            'endsAt': block.endsAt.toIso8601String(),
            'status': block.status.name,
            'source': block.source.name,
          },
      ],
      'summary': <String, Object?>{
        'openTaskCount': context.pulse.openTaskCount,
        'overdueCount': context.pulse.overdueCount,
        'dueTodayCount': context.pulse.dueTodayCount,
        'taskCount': context.tasks.length,
        'projectCount': context.projects.length,
        'scheduleBlockCount': context.blocks.length,
        'truncated':
            context.tasks.length > 200 ||
            context.projects.length > 100 ||
            context.blocks.length > 200,
      },
    };
  }
}
