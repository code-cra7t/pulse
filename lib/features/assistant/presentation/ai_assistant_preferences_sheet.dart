import 'package:flutter/material.dart';

import '../../../core/services/app_theme.dart';
import '../models/ai_assistant_preferences.dart';

Future<AiAssistantPreferences?> showAiAssistantPreferencesSheet({
  required BuildContext context,
  required AiAssistantPreferences initial,
  required bool gatewayConfigured,
}) {
  return showModalBottomSheet<AiAssistantPreferences>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => _AiAssistantPreferencesSheet(
      initial: initial,
      gatewayConfigured: gatewayConfigured,
    ),
  );
}

class _AiAssistantPreferencesSheet extends StatefulWidget {
  const _AiAssistantPreferencesSheet({
    required this.initial,
    required this.gatewayConfigured,
  });

  final AiAssistantPreferences initial;
  final bool gatewayConfigured;

  @override
  State<_AiAssistantPreferencesSheet> createState() =>
      _AiAssistantPreferencesSheetState();
}

class _AiAssistantPreferencesSheetState
    extends State<_AiAssistantPreferencesSheet> {
  late AiAssistantMode _mode;

  @override
  void initState() {
    super.initState();
    _mode = widget.initial.mode;
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.md,
          AppSpacing.md,
          AppSpacing.md + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'AI assistance',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Local deterministic reasoning always runs first. Hybrid mode may send your typed question plus a minimized structured planning snapshot to the configured JotCue AI gateway.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.md),
            ListTile(
              key: const ValueKey('ai-mode-localOnly'),
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                _mode == AiAssistantMode.localOnly
                    ? Icons.check_circle_rounded
                    : Icons.circle_outlined,
              ),
              title: const Text('Local only'),
              subtitle: const Text('No Ask JotCue content leaves this device.'),
              onTap: () => setState(() => _mode = AiAssistantMode.localOnly),
            ),
            ListTile(
              key: const ValueKey('ai-mode-hybrid'),
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                _mode == AiAssistantMode.hybrid
                    ? Icons.check_circle_rounded
                    : Icons.circle_outlined,
              ),
              title: const Text('Hybrid'),
              subtitle: Text(
                widget.gatewayConfigured
                    ? 'Use the configured gateway only when local reasoning cannot safely answer.'
                    : 'No gateway is configured in this build, so local fallback will remain active.',
              ),
              onTap: () => setState(() => _mode = AiAssistantMode.hybrid),
            ),
            const SizedBox(height: AppSpacing.sm),
            DecoratedBox(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Padding(
                padding: EdgeInsets.all(AppSpacing.sm),
                child: Text(
                  'May be sent in Hybrid mode: your typed question, Task IDs/titles and planning metadata, Project IDs/names, accepted JotCue block IDs/times, and summary counts. Never sent: Note bodies, source Note IDs or line indexes, account identity, reminder text, external calendar event contents, automation audit history, or notification history. Remote tool suggestions still require local validation and the same Apply/permission checks as local Ask JotCue actions.',
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            FilledButton(
              onPressed: () => Navigator.of(
                context,
              ).pop(AiAssistantPreferences(mode: _mode)),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}
