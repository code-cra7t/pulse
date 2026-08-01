import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/app_theme.dart';
import '../../../core/services/firebase_providers.dart';
import '../../../core/widgets/pulse_components.dart';
import '../../auth/providers/auth_providers.dart';
import '../../notes/models/note_category.dart';
import '../../profile/providers/user_profile_providers.dart';
import '../models/user_settings.dart';
import '../providers/user_settings_providers.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({
    super.key,
    required this.onOpenProfile,
    this.embedded = false,
  });

  final VoidCallback onOpenProfile;
  final bool embedded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(firebaseAuthProvider).currentUser;
    final profile = ref.watch(currentUserProfileProvider).asData?.value;
    final settingsAsync = ref.watch(currentUserSettingsProvider);

    return Scaffold(
      backgroundColor: embedded ? Colors.transparent : null,
      appBar: embedded
          ? null
          : AppBar(
              title: const Text('Settings'),
              leading: IconButton(
                onPressed: () => Navigator.of(context).maybePop(),
                icon: const Icon(Icons.arrow_back_rounded),
              ),
            ),
      body: settingsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => EmptyState(
          icon: Icons.settings_suggest_outlined,
          title: 'Could not load settings',
          message: '$error',
          actionLabel: 'Retry',
          onAction: () => ref.invalidate(currentUserSettingsProvider),
        ),
        data: (settings) {
          if (user == null) {
            return const EmptyState(
              icon: Icons.lock_outline_rounded,
              title: 'Signed out',
              message: 'Sign in again to update settings.',
            );
          }

          final effectiveSettings = settings ?? UserSettings.defaults();
          final photoUrl = profile?.photoUrl;
          return Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 820),
              child: ListView(
                padding: EdgeInsets.fromLTRB(
                  embedded ? AppSpacing.xl : AppSpacing.md,
                  AppSpacing.lg,
                  embedded ? AppSpacing.xl : AppSpacing.md,
                  AppSpacing.xl,
                ),
                children: [
                  if (embedded) ...[
                    Text(
                      'Settings',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Tune PulseNotes without leaving your workspace.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                  ],
                  _SettingsSection(
                    title: 'Account',
                    children: [
                      ListTile(
                        leading: CircleAvatar(
                          backgroundColor: AppColors.lavender,
                          backgroundImage: photoUrl == null || photoUrl.isEmpty
                              ? null
                              : NetworkImage(
                                  photoUrl,
                                  webHtmlElementStrategy:
                                      WebHtmlElementStrategy.fallback,
                                ),
                          child: photoUrl == null || photoUrl.isEmpty
                              ? const Icon(Icons.person_outline_rounded)
                              : null,
                        ),
                        title: Text(
                          profile?.displayName ??
                              user.displayName ??
                              'PulseNotes User',
                        ),
                        subtitle: Text(user.email ?? profile?.email ?? ''),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: onOpenProfile,
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.logout_rounded),
                        title: const Text('Sign out'),
                        onTap: () => ref.read(authServiceProvider).signOut(),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _SettingsSection(
                    title: 'Appearance',
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(AppSpacing.sm),
                        child: SegmentedButton<PulseThemeMode>(
                          segments: const [
                            ButtonSegment(
                              value: PulseThemeMode.system,
                              label: Text('System'),
                              icon: Icon(Icons.devices_rounded),
                            ),
                            ButtonSegment(
                              value: PulseThemeMode.light,
                              label: Text('Light'),
                              icon: Icon(Icons.light_mode_outlined),
                            ),
                            ButtonSegment(
                              value: PulseThemeMode.dark,
                              label: Text('Dark'),
                              icon: Icon(Icons.dark_mode_outlined),
                            ),
                          ],
                          selected: {effectiveSettings.themeMode},
                          onSelectionChanged: (selection) {
                            final messenger = ScaffoldMessenger.of(context);
                            ref
                                .read(userSettingsRepositoryProvider)
                                .updateThemeMode(user.uid, selection.first)
                                .catchError(
                                  (error) => _showError(messenger, error),
                                );
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _SettingsSection(
                    title: 'Notes',
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(AppSpacing.sm),
                        child: DropdownButtonFormField<String>(
                          initialValue: NoteCategory.normalize(
                            effectiveSettings.defaultNoteTag,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Default note tag',
                            prefixIcon: Icon(Icons.label_outline_rounded),
                          ),
                          items: NoteCategory.defaults.map((tag) {
                            return DropdownMenuItem(
                              value: tag,
                              child: Text(tag),
                            );
                          }).toList(),
                          onChanged: (tag) {
                            if (tag == null) {
                              return;
                            }
                            final messenger = ScaffoldMessenger.of(context);
                            ref
                                .read(userSettingsRepositoryProvider)
                                .updateDefaultNoteTag(user.uid, tag)
                                .catchError(
                                  (error) => _showError(messenger, error),
                                );
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _SettingsSection(
                    title: 'Reminders',
                    children: [
                      SwitchListTile(
                        title: const Text('Notifications enabled'),
                        subtitle: const Text('Allow local reminder alerts.'),
                        value: effectiveSettings.notificationsEnabled,
                        onChanged: (enabled) {
                          final messenger = ScaffoldMessenger.of(context);
                          ref
                              .read(userSettingsRepositoryProvider)
                              .updateNotificationsEnabled(user.uid, enabled)
                              .catchError(
                                (error) => _showError(messenger, error),
                              );
                        },
                      ),
                      const Divider(height: 1),
                      SwitchListTile(
                        title: const Text('Smart reminders enabled'),
                        subtitle: const Text(
                          'Suggest reminders from phrases while writing.',
                        ),
                        value: effectiveSettings.smartRemindersEnabled,
                        onChanged: (enabled) {
                          final messenger = ScaffoldMessenger.of(context);
                          ref
                              .read(userSettingsRepositoryProvider)
                              .updateSmartRemindersEnabled(user.uid, enabled)
                              .catchError(
                                (error) => _showError(messenger, error),
                              );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  const _SettingsSection(
                    title: 'About',
                    children: [
                      ListTile(
                        leading: Icon(Icons.auto_awesome_rounded),
                        title: Text('PulseNotes'),
                        subtitle: Text(
                          'Notes that become tasks. Tasks that become reminders.\nVersion 1.0.0',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showError(ScaffoldMessengerState messenger, Object error) {
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('Settings save failed: $error')));
  }
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: AppSpacing.xs),
          child: Text(title, style: Theme.of(context).textTheme.titleSmall),
        ),
        const SizedBox(height: AppSpacing.xs),
        AppCard(
          padding: EdgeInsets.zero,
          child: Column(children: children),
        ),
      ],
    );
  }
}
