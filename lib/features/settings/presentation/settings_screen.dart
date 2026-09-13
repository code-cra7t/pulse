import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/app_theme.dart';
import '../../../core/services/firebase_providers.dart';
import '../../../core/widgets/jotcue_brand.dart';
import '../../../core/widgets/pulse_components.dart';
import '../../assistant/models/ai_assistant_preferences.dart';
import '../../assistant/presentation/ai_assistant_preferences_sheet.dart';
import '../../assistant/providers/assistant_providers.dart';
import '../../automation/models/automation_preferences.dart';
import '../../automation/models/automation_safety_preferences.dart';
import '../../automation/presentation/automation_preferences_sheet.dart';
import '../../automation/presentation/automation_safety_sheet.dart';
import '../../automation/providers/trusted_automation_providers.dart';
import '../../attention/models/attention_preferences.dart';
import '../../attention/presentation/attention_preferences_sheet.dart';
import '../../attention/providers/attention_providers.dart';
import '../../auth/providers/account_deletion_provider.dart';
import '../../auth/providers/auth_providers.dart';
import '../../notes/models/note_category.dart';
import '../../profile/providers/user_profile_providers.dart';
import '../../projects/models/project.dart';
import '../../projects/providers/project_providers.dart';
import '../../scheduling/presentation/widgets/scheduling_preferences_sheet.dart';
import '../../tasks/models/task.dart';
import '../../tasks/providers/task_providers.dart';
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
    final automationSafety =
        ref.watch(automationSafetyPreferencesProvider).asData?.value ??
        const AutomationSafetyPreferences();
    final aiAssistantPreferences =
        ref.watch(aiAssistantPreferencesProvider).asData?.value ??
        const AiAssistantPreferences();
    final aiGatewayConfigured = ref.watch(aiGatewayClientProvider).isConfigured;
    final attentionPreferences =
        ref.watch(attentionPreferencesProvider).asData?.value ??
        const AttentionPreferences();
    final tasks = ref.watch(tasksProvider);
    final projects =
        ref.watch(projectsStreamProvider).asData?.value ?? const <Project>[];

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
                      'Tune JotCue without leaving your workspace.',
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
                              'JotCue User',
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
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
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
                          dropdownColor: Theme.of(context).colorScheme.surface,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Default note tag',
                            prefixIcon: Icon(Icons.label_outline_rounded),
                          ),
                          items: NoteCategory.defaults.map((tag) {
                            return DropdownMenuItem(
                              value: tag,
                              child: Text(
                                tag,
                                style: TextStyle(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurface,
                                ),
                              ),
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
                    title: 'Planning',
                    children: [
                      ListTile(
                        leading: const Icon(Icons.calendar_view_week_outlined),
                        title: const Text('Planning availability'),
                        subtitle: Text(
                          effectiveSettings.schedulingPreferences.isConfigured
                              ? 'Controls when JotCue may suggest focused work.'
                              : 'Set when JotCue is allowed to suggest focused work.',
                        ),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () => _editSchedulingPreferences(
                          context,
                          ref,
                          user.uid,
                          effectiveSettings,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _SettingsSection(
                    title: 'Assistant',
                    children: [
                      ListTile(
                        leading: const Icon(Icons.auto_awesome_outlined),
                        title: const Text('Assistant permissions'),
                        subtitle: Text(
                          _automationLevelLabel(
                            effectiveSettings.automationPreferences.level,
                          ),
                        ),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () => _editAutomationPreferences(
                          context,
                          ref,
                          user.uid,
                          effectiveSettings,
                        ),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        key: const ValueKey('ai-assistance-setting'),
                        leading: const Icon(Icons.psychology_alt_outlined),
                        title: const Text('AI assistance'),
                        subtitle: Text(
                          _aiAssistantLabel(
                            aiAssistantPreferences,
                            aiGatewayConfigured,
                          ),
                        ),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () => _editAiAssistantPreferences(
                          context,
                          ref,
                          aiAssistantPreferences,
                          aiGatewayConfigured,
                        ),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        key: const ValueKey(
                          'trusted-automation-safety-setting',
                        ),
                        leading: const Icon(Icons.shield_outlined),
                        title: const Text('Trusted automation safety'),
                        subtitle: Text(
                          _automationSafetyLabel(
                            automationSafety,
                            effectiveSettings.automationPreferences.level,
                          ),
                        ),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () => _editAutomationSafety(
                          context,
                          ref,
                          user.uid,
                          tasks,
                          projects,
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
                      ListTile(
                        key: const ValueKey('proactive-attention-setting'),
                        leading: const Icon(
                          Icons.notifications_active_outlined,
                        ),
                        title: const Text('Proactive attention'),
                        subtitle: Text(
                          attentionPreferences.enabled
                              ? 'Morning Pulse, closing, deadlines, and planning cues'
                              : 'Off on this device',
                        ),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () async {
                          final updated = await showAttentionPreferencesSheet(
                            context: context,
                            initial: attentionPreferences,
                          );
                          if (updated == null || !context.mounted) return;
                          final messenger = ScaffoldMessenger.of(context);
                          ref
                              .read(offlineAttentionStoreProvider)
                              .writePreferences(user.uid, updated)
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
                        leading: JotCueMark(size: 38),
                        title: Text('JotCue'),
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

  Future<void> _editSchedulingPreferences(
    BuildContext context,
    WidgetRef ref,
    String userId,
    UserSettings settings,
  ) async {
    final updated = await showSchedulingPreferencesSheet(
      context: context,
      initial: settings.schedulingPreferences,
    );
    if (updated == null || !context.mounted) {
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(userSettingsRepositoryProvider)
          .updateSchedulingPreferences(userId, updated);
    } catch (error) {
      _showError(messenger, error);
    }
  }

  Future<void> _editAutomationPreferences(
    BuildContext context,
    WidgetRef ref,
    String userId,
    UserSettings settings,
  ) async {
    final updated = await showAutomationPreferencesSheet(
      context: context,
      initial: settings.automationPreferences,
    );
    if (updated == null || !context.mounted) {
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(userSettingsRepositoryProvider)
          .updateAutomationPreferences(userId, updated);
    } catch (error) {
      _showError(messenger, error);
    }
  }

  Future<void> _editAiAssistantPreferences(
    BuildContext context,
    WidgetRef ref,
    AiAssistantPreferences initial,
    bool gatewayConfigured,
  ) async {
    final updated = await showAiAssistantPreferencesSheet(
      context: context,
      initial: initial,
      gatewayConfigured: gatewayConfigured,
    );
    if (updated == null || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(offlineAiAssistantStoreProvider).writePreferences(updated);
    } catch (error) {
      _showError(messenger, error);
    }
  }

  Future<void> _editAutomationSafety(
    BuildContext context,
    WidgetRef ref,
    String userId,
    List<Task> tasks,
    List<Project> projects,
  ) async {
    final store = ref.read(offlineAutomationSafetyStoreProvider);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final current = await store.readPreferences(userId);
      if (!context.mounted) {
        return;
      }
      final updated = await showAutomationSafetySheet(
        context: context,
        initial: current,
        tasks: tasks,
        projects: projects,
      );
      if (updated == null) {
        return;
      }
      await store.writePreferences(userId, updated);
    } catch (error) {
      _showError(messenger, error);
    }
  }

  void _showError(ScaffoldMessengerState messenger, Object error) {
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('Settings save failed: $error')));
  }
}

String _aiAssistantLabel(
  AiAssistantPreferences preferences,
  bool gatewayConfigured,
) {
  if (!preferences.usesRemoteGateway) return 'Local only';
  return gatewayConfigured
      ? 'Hybrid · local first, remote fallback'
      : 'Hybrid selected · gateway not configured';
}

String _automationLevelLabel(AutomationLevel level) => switch (level) {
  AutomationLevel.observe => 'Observe only',
  AutomationLevel.suggest => 'Suggest changes',
  AutomationLevel.approval => 'Act with approval',
  AutomationLevel.trusted => 'Trusted permissions',
};

String _automationSafetyLabel(
  AutomationSafetyPreferences safety,
  AutomationLevel level,
) {
  if (safety.paused) {
    return 'Paused on this device';
  }
  if (level != AutomationLevel.trusted) {
    return 'Applies when Trusted is enabled';
  }
  if (safety.exclusionCount == 0) {
    return 'Active · 30-minute bounce protection';
  }
  return '${safety.exclusionCount} exclusion${safety.exclusionCount == 1 ? '' : 's'} · 30-minute cooldown';
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
                'This permanently deletes your notes, tasks, reminders, local planning blocks, local automation history and safety controls, device-local AI assistance preference, uploaded images, settings, and JotCue account. This cannot be undone.',
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
