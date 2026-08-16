import 'package:flutter/material.dart';

import '../../../core/services/app_theme.dart';
import '../../../core/widgets/pulse_components.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Privacy policy')),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: const [
              Text('Effective August 6, 2026'),
              SizedBox(height: AppSpacing.lg),
              _PolicySection(
                title: 'Information JotCue handles',
                body:
                    'JotCue stores the email address used for your account, your display name and optional profile photo, plus the notes, tasks, reminders, settings, and images you choose to create. A local copy of notes and pending changes is kept on your device so the app can work offline.',
              ),
              _PolicySection(
                title: 'How information is used',
                body:
                    'This information is used only to provide account access, synchronize your content, show reminders, save your preferences, and support the features you request. JotCue does not sell personal information and does not include advertising SDKs.',
              ),
              _PolicySection(
                title: 'Service providers and security',
                body:
                    'JotCue uses Google Firebase for authentication, database storage, and uploaded-file storage. Data is encrypted in transit. Access controls limit cloud content to the signed-in account.',
              ),
              _PolicySection(
                title: 'Notifications and calendar',
                body:
                    'Reminder notifications are scheduled on your device after you grant permission. Adding a reminder to your calendar opens the device calendar flow and happens only when you request it; JotCue does not read your calendar.',
              ),
              _PolicySection(
                title: 'Deletion and retention',
                body:
                    'You can permanently delete your account and associated cloud and local app data from Settings > Account > Delete account. Scheduled JotCue notifications are also canceled. You can access the same deletion flow through the JotCue web app.',
              ),
              _PolicySection(
                title: 'Privacy requests',
                body:
                    'For privacy questions or requests, use the developer contact shown on the JotCue Google Play listing. The public policy and deletion instructions are hosted at pulsenotes-c8d82.web.app/privacy.html and pulsenotes-c8d82.web.app/account-deletion.html.',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PolicySection extends StatelessWidget {
  const _PolicySection({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: AppSpacing.xs),
            SelectableText(body),
          ],
        ),
      ),
    );
  }
}
