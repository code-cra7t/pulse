import '../../personal_graph/models/personal_graph.dart';
import '../models/ask_jotcue.dart';

typedef CurrentAssistantUserId = String? Function();

class AssistantAccountGuard {
  const AssistantAccountGuard({required CurrentAssistantUserId currentUserId})
    : _currentUserId = currentUserId;

  final CurrentAssistantUserId _currentUserId;

  String requireCurrentUserId() {
    final userId = _currentUserId()?.trim();
    if (userId == null || userId.isEmpty) {
      throw StateError(
        'Ask JotCue requires the same signed-in account that created this preview. Sign in and ask again.',
      );
    }
    return userId;
  }

  void validateContext(AskJotCueContext context) {
    final userId = requireCurrentUserId();
    final contextUserId = context.userId?.trim();

    if (contextUserId == null ||
        contextUserId.isEmpty ||
        contextUserId != userId ||
        context.tasks.any((task) => task.userId.trim() != userId) ||
        context.projects.any((project) => project.userId.trim() != userId) ||
        context.blocks.any((block) => block.userId.trim() != userId) ||
        context.pulse.focusItems.any(
          (item) =>
              item.task.userId.trim() != userId ||
              (item.project != null && item.project!.userId.trim() != userId),
        ) ||
        context.pulse.upcomingProjects.any(
          (project) => project.userId.trim() != userId,
        ) ||
        _hasForeignLoopBlock(context, userId) ||
        _hasForeignSchedulingBlock(context, userId) ||
        !_dependencyAnalysisMatches(context, userId) ||
        !_personalGraphMatches(context)) {
      throw StateError(
        'Ask JotCue context belongs to a different or stale account. Refresh and ask again.',
      );
    }
  }

  void validateProposal(AskJotCueActionProposal proposal) {
    final userId = requireCurrentUserId();
    final proposalUserId = proposal.userId.trim();
    if (proposalUserId.isEmpty || proposalUserId != userId) {
      throw StateError(
        'The signed-in account changed after this preview. Refresh Ask JotCue and ask again.',
      );
    }
  }

  bool _hasForeignLoopBlock(AskJotCueContext context, String userId) {
    final upNext = context.dailyLoop.upNextBlock;
    return context.dailyLoop.todayBlocks.any(
          (block) => block.userId.trim() != userId,
        ) ||
        context.dailyLoop.completedBlocks.any(
          (block) => block.userId.trim() != userId,
        ) ||
        context.dailyLoop.missedBlocks.any(
          (block) => block.userId.trim() != userId,
        ) ||
        context.dailyLoop.unresolvedPastBlocks.any(
          (block) => block.userId.trim() != userId,
        ) ||
        context.dailyLoop.upcomingBlocks.any(
          (block) => block.userId.trim() != userId,
        ) ||
        (upNext != null && upNext.userId.trim() != userId);
  }

  bool _hasForeignSchedulingBlock(AskJotCueContext context, String userId) {
    final scheduling = context.scheduling;
    if (scheduling == null) return false;
    return scheduling.acceptedBlocks.any(
      (block) => block.userId.trim() != userId,
    );
  }

  bool _dependencyAnalysisMatches(AskJotCueContext context, String userId) {
    final analysis = context.dependencyAnalysis;
    if (analysis == null) return true;

    final taskIds = context.tasks.map((task) => task.id).toSet();
    final projectIds = context.projects.map((project) => project.id).toSet();

    if (!analysis.taskCues.keys.every(taskIds.contains) ||
        !analysis.projectCues.keys.every(projectIds.contains) ||
        !analysis.cycleTaskIds.every(taskIds.contains)) {
      return false;
    }

    for (final cue in analysis.taskCues.values) {
      if (cue.task.userId.trim() != userId) return false;
    }
    for (final cue in analysis.projectCues.values) {
      final nextTask = cue.nextTask;
      if (nextTask != null && nextTask.userId.trim() != userId) return false;
    }
    return true;
  }

  bool _personalGraphMatches(AskJotCueContext context) {
    final graph = context.personalGraph;
    if (graph == null) return true;

    final taskIds = context.tasks.map((task) => task.id).toSet();
    final projectIds = context.projects.map((project) => project.id).toSet();
    final blockIds = context.blocks.map((block) => block.id).toSet();

    for (final node in graph.nodes.values) {
      switch (node.type) {
        case PersonalGraphNodeType.task:
          if (!taskIds.contains(node.entityId)) return false;
          break;
        case PersonalGraphNodeType.project:
          if (!projectIds.contains(node.entityId)) return false;
          break;
        case PersonalGraphNodeType.scheduleBlock:
          if (!blockIds.contains(node.entityId)) return false;
          break;
        case PersonalGraphNodeType.note:
        case PersonalGraphNodeType.deadline:
        case PersonalGraphNodeType.person:
        case PersonalGraphNodeType.decision:
        case PersonalGraphNodeType.event:
          break;
      }
    }
    return true;
  }
}
