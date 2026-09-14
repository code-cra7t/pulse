import '../models/ask_jotcue.dart';
import 'ask_jotcue_engine.dart';

/// Builds a bounded multi-step plan exclusively from existing deterministic
/// Ask JotCue action proposals.
///
/// Patch 31 deliberately requires explicit sequence wording ("First …, then
/// …") so ordinary notes, captures, or prose containing "then" are not
/// reinterpreted as autonomous plans.
class AskJotCuePlanBuilder {
  const AskJotCuePlanBuilder({required this.engine});

  static const int maxSteps = 5;

  final AskJotCueEngine engine;

  AskJotCueAnswer? build({
    required String query,
    required AskJotCueContext context,
  }) {
    final body = _explicitPlanBody(query);
    if (body == null) return null;

    final parts = body
        .split(RegExp(r'\s+(?:and\s+)?then\s+', caseSensitive: false))
        .map(_cleanStep)
        .where((part) => part.isNotEmpty)
        .toList(growable: false);

    if (parts.length < 2) {
      return _clarification(
        'Use at least two explicit steps separated by “then”.',
      );
    }
    if (parts.length > maxSteps) {
      return _clarification(
        'A single plan can contain at most $maxSteps steps. Split this into smaller plans.',
      );
    }

    final proposals = <AskJotCueActionProposal>[];
    final seenIds = <String>{};
    String? userId;

    for (var index = 0; index < parts.length; index++) {
      final answer = engine.answer(query: parts[index], context: context);
      final proposal = answer.actionProposal;
      if (proposal == null || answer.actionPlan != null) {
        return _clarification(
          'Step ${index + 1} could not be prepared as one safe local action. '
          'Make each step an explicit supported change and name its target clearly.',
        );
      }
      if (!seenIds.add(proposal.id)) {
        return _clarification(
          'Step ${index + 1} duplicates an earlier change. Remove the duplicate before applying a plan.',
        );
      }
      if (proposal.userId.trim().isEmpty) {
        return _clarification(
          'Step ${index + 1} is missing a signed-in owner, so the plan cannot be prepared safely.',
        );
      }
      userId ??= proposal.userId;
      if (proposal.userId != userId) {
        return _clarification(
          'All steps in one plan must belong to the same signed-in account.',
        );
      }
      proposals.add(proposal);
    }

    final plan = AskJotCueActionPlan(
      id: 'plan:${proposals.map((proposal) => proposal.id).join('|')}',
      steps: List<AskJotCueActionProposal>.unmodifiable(proposals),
      previewTitle: '${proposals.length}-step plan',
      previewText:
          'Runs in order and stops on the first failure. Earlier successful steps are not automatically rolled back.',
    );
    return AskJotCueAnswer(
      intent: AskJotCueIntent.action,
      title: 'Multi-step plan preview',
      text:
          'I prepared ${proposals.length} explicit local changes. Review every step before applying the plan.',
      actionPlan: plan,
    );
  }

  String? _explicitPlanBody(String query) {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return null;

    final first = RegExp(r'^first[\s,:-]+', caseSensitive: false);
    if (first.hasMatch(trimmed)) {
      return trimmed.replaceFirst(first, '').trim();
    }

    final doThese = RegExp(
      r'^do\s+(?:these|the\s+following)(?:\s+changes)?\s*:\s*',
      caseSensitive: false,
    );
    if (doThese.hasMatch(trimmed)) {
      return trimmed.replaceFirst(doThese, '').trim();
    }

    final makeThese = RegExp(
      r'^make\s+these\s+changes\s*:\s*',
      caseSensitive: false,
    );
    if (makeThese.hasMatch(trimmed)) {
      return trimmed.replaceFirst(makeThese, '').trim();
    }

    return null;
  }

  String _cleanStep(String value) {
    var step = value.trim();
    step = step.replaceFirst(
      RegExp(r'^(?:next|finally)[\s,:-]+', caseSensitive: false),
      '',
    );
    step = step.replaceFirst(RegExp(r'[\s,;.!]+$'), '');
    return step.trim();
  }

  AskJotCueAnswer _clarification(String message) {
    return AskJotCueAnswer(
      intent: AskJotCueIntent.action,
      title: 'Plan needs clarification',
      text: '$message Nothing has changed.',
    );
  }
}
