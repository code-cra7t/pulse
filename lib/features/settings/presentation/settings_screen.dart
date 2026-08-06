import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/app_theme.dart';
import '../../../core/services/firebase_providers.dart';
import '../../../core/widgets/pulse_components.dart';
import '../../auth/providers/account_deletion_provider.dart';
import '../../auth/providers/auth_providers.dart';
import '../../notes/models/note_category.dart';
import '../../profile/providers/user_profile_providers.dart';
import '../models/user_settings.dart';
import '../providers/user_settings_providers.dart';
import 'privacy_policy_screen.dart';

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
                      const Divider(height: 1),
                      ListTile(
                        leading: Icon(
                          Icons.delete_forever_outlined,
                          color: Theme.of(context).colorScheme.error,
                        ),
                        title: Text(
                          'Delete account',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                        subtitle: const Text(
                          'Permanently delete your account and data.',
                        ),
                        onTap: () => showDialog<void>(
                          context: context,
                          barrierDismissible: false,
                          builder: (_) => const _DeleteAccountDialog(),
                        ),
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
                  _SettingsSection(
                    title: 'About',
                    children: [
                      const ListTile(
                        leading: Icon(Icons.auto_awesome_rounded),
                        title: Text('PulseNotes'),
                        subtitle: Text(
                          'Notes that become tasks. Tasks that become reminders.\nVersion 1.0.0',
                        ),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.privacy_tip_outlined),
                        title: const Text('Privacy policy'),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const PrivacyPolicyScreen(),
                          ),
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

class _DeleteAccountDialog extends ConsumerStatefulWidget {
  const _DeleteAccountDialog();

  @override
  ConsumerState<_DeleteAccountDialog> createState() =>
      _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends ConsumerState<_DeleteAccountDialog> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  bool _isDeleting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _deleteAccount() async {
    if (!(_formKey.currentState?.validate() ?? false) || _isDeleting) {
      return;
    }

    setState(() {
      _isDeleting = true;
      _errorMessage = null;
    });

    try {
      await ref
          .read(accountDeletionServiceProvider)
          .deleteCurrentAccount(password: _passwordController.text);
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isDeleting = false;
        _errorMessage = _accountDeletionMessage(error);
      });
    }
  }

  String _accountDeletionMessage(Object error) {
    final text = error.toString().toLowerCase();
    if (text.contains('wrong-password') ||
        text.contains('invalid-credential')) {
      return 'That password is incorrect.';
    }
    if (text.contains('network-request-failed')) {
      return 'Check your connection and try again.';
    }
    if (text.contains('too-many-requests')) {
      return 'Too many attempts. Please wait and try again.';
    }
    return 'Could not finish deleting the account. Some data may already have been removed; please try again.';
  }

  @override
  Widget build(BuildContext context) {
    final errorColor = Theme.of(context).colorScheme.error;
    return AlertDialog(
      icon: Icon(Icons.warning_amber_rounded, color: errorColor),
      title: const Text('Delete your account?'),
      content: Form(
        key: _formKey,
        child: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'This permanently deletes your notes, tasks, reminders, uploaded images, settings, and PulseNotes account. This cannot be undone.',
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _passwordController,
                obscureText: true,
                enabled: !_isDeleting,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Confirm your password',
                ),
                validator: (value) => value == null || value.isEmpty
                    ? 'Enter your password to continue.'
                    : null,
                onFieldSubmitted: (_) => _deleteAccount(),
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(_errorMessage!, style: TextStyle(color: errorColor)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isDeleting ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _isDeleting ? null : _deleteAccount,
          style: FilledButton.styleFrom(backgroundColor: errorColor),
          child: _isDeleting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Delete permanently'),
        ),
      ],
    );
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
