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
              Text('Effective September 8, 2026'),
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
                title: 'Assistant permissions and automation',
                body:
                    'JotCue lets you choose how far the assistant may go when it notices something that could be adjusted: Observe, Suggest, Act with approval, or Trusted. This preference is stored with your app settings. Trusted is a permission boundary, not unlimited control. Calendar writes, creating structured content from capture, and deciding whether work was completed or missed remain approval-only. This version does not add background automation; future automation features must respect the stored permission policy before they can act.',
              ),
              _PolicySection(
                title: 'Service providers and security',
                body:
                    'JotCue uses Google Firebase for authentication, database storage, and uploaded-file storage. Data is encrypted in transit. Access controls limit cloud content to the signed-in account.',
              ),
              _PolicySection(
                title: 'Notifications and calendar',
                body:
                    'Reminder notifications are scheduled on your device after you grant permission. Calendar linking is optional. On Android, JotCue requests calendar access to list writable calendars and create, verify, update or remove entries linked to your reminders. Those links stay on this device; JotCue does not upload your calendar contents. Your chosen calendar account may synchronize exported entries through its own provider. On other supported platforms, calendar exports use the device calendar flow and are managed separately. Phone alarms are confirmed and managed in the Clock app.',
              ),
              _PolicySection(
                title: 'Deletion and retention',
                body:
                    'You can permanently delete your account and associated cloud and local app data from Settings > Account > Delete account. Scheduled JotCue notifications are also canceled. JotCue attempts to remove linked calendar entries on this Android device; if calendar access is unavailable, pending cleanup links are retained locally for retry. Entries on other devices, old unlinked exports and phone Clock alarms may need manual removal. You can access the same account deletion flow through the JotCue web app.',
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
