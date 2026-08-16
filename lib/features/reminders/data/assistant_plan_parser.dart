/// Detects simple written plans that JotCue can safely turn into task bullets.
///
/// This stays deliberately conservative: only clear numbered or sequenced
/// steps are suggested, and the user confirms the conversion.
class AssistantPlanParser {
  static final RegExp _numberedStep = RegExp(r'^\s*\d+[.)]\s*(.+)$');
  static final RegExp _sequencedStep = RegExp(
    r'^\s*(?:first|then|next|after that|finally)[:,]?\s*(.+)$',
    caseSensitive: false,
  );

  PlanSuggestion? parse(String content) {
    final steps = <PlanStep>[];
    for (final entry in content.split('\n').indexed) {
      final line = entry.$2;
      final match =
          _numberedStep.firstMatch(line) ?? _sequencedStep.firstMatch(line);
      final text = (match?.group(1) ?? '').trim();
      if (text.isNotEmpty) {
        steps.add(PlanStep(lineIndex: entry.$1, text: text));
      }
    }

    if (steps.length < 2) {
      return null;
    }
    return PlanSuggestion(steps: steps);
  }
}

class PlanSuggestion {
  const PlanSuggestion({required this.steps});

  final List<PlanStep> steps;

  String get key =>
      steps.map((step) => '${step.lineIndex}:${step.text}').join('|');
}

class PlanStep {
  const PlanStep({required this.lineIndex, required this.text});

  final int lineIndex;
  final String text;
}
