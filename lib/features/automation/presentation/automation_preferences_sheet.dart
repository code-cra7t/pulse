import 'package:flutter/material.dart';

import '../../../core/services/app_theme.dart';
import '../models/automation_preferences.dart';

Future<AutomationPreferences?> showAutomationPreferencesSheet({
  required BuildContext context,
  required AutomationPreferences initial,
}) {
  return showModalBottomSheet<AutomationPreferences>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _AutomationPreferencesSheet(initial: initial),
  );
}

class _AutomationPreferencesSheet extends StatefulWidget {
  const _AutomationPreferencesSheet({required this.initial});

  final AutomationPreferences initial;

  @override
  State<_AutomationPreferencesSheet> createState() =>
      _AutomationPreferencesSheetState();
}

class _AutomationPreferencesSheetState
    extends State<_AutomationPreferencesSheet> {
  late AutomationLevel _level;

  @override
  void initState() {
    super.initState();
    _level = widget.initial.level;
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.lg + bottomInset,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Assistant permissions',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Choose how far JotCue may go when it notices something that could be adjusted.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.lg),
          ...AutomationLevel.values.map(
            (level) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: ListTile(
                key: ValueKey('automation-level-${level.name}'),
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  _level == level
                      ? Icons.check_circle_rounded
                      : Icons.circle_outlined,
                ),
                title: Text(_title(level)),
                subtitle: Text(_description(level)),
                onTap: () => setState(() => _level = level),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          DecoratedBox(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Padding(
              padding: EdgeInsets.all(AppSpacing.md),
              child: Text(
                'Safety boundary: calendar writes, creating captured content, and deciding whether work was completed or missed always require your approval. Patch 15 stores the permission policy; it does not add background automation.',
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => Navigator.of(
                context,
              ).pop(AutomationPreferences(level: _level)),
              child: const Text('Save permissions'),
            ),
          ),
        ],
      ),
    );
  }
}

String _title(AutomationLevel level) => switch (level) {
  AutomationLevel.observe => 'Observe',
  AutomationLevel.suggest => 'Suggest',
  AutomationLevel.approval => 'Act with approval',
  AutomationLevel.trusted => 'Trusted',
};

String _description(AutomationLevel level) => switch (level) {
  AutomationLevel.observe =>
    'Surface facts and conflicts without preparing assistant-initiated changes.',
  AutomationLevel.suggest =>
    'Recommend what could change. You remain the one who starts every action.',
  AutomationLevel.approval =>
    'JotCue may prepare a concrete change, but must ask before applying it.',
  AutomationLevel.trusted =>
    'Allow future low-risk local automation only where JotCue explicitly supports trusted execution.',
};
