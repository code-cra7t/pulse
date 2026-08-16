import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/services/app_theme.dart';
import '../../../core/services/firebase_providers.dart';
import '../../../core/widgets/pulse_components.dart';
import '../../auth/providers/auth_providers.dart';
import '../models/user_profile.dart';
import '../providers/user_profile_providers.dart';

enum ProfileSaveStatus { idle, saving, saved, failed }

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key, this.embedded = false, this.onClose});

  final bool embedded;
  final VoidCallback? onClose;

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  late final TextEditingController _displayNameController;
  ProfileSaveStatus _saveStatus = ProfileSaveStatus.idle;
  bool _uploadingPhoto = false;
  bool _hasChanges = false;
  String? _lastProfileUid;

  @override
  void initState() {
    super.initState();
    _displayNameController = TextEditingController();
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(firebaseAuthProvider).currentUser;
    final profileAsync = ref.watch(currentUserProfileProvider);

    return Scaffold(
      backgroundColor: widget.embedded
          ? Colors.transparent
          : AppColors.canvasFor(context),
      appBar: widget.embedded
          ? null
          : AppBar(
              leading: IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.arrow_back_rounded),
              ),
              title: const Text('Profile'),
            ),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => EmptyState(
          icon: Icons.person_off_outlined,
          title: 'Could not load profile',
          message: '$error',
          actionLabel: 'Retry',
          onAction: () => ref.invalidate(currentUserProfileProvider),
        ),
        data: (profile) {
          if (user == null) {
            return const EmptyState(
              icon: Icons.lock_outline_rounded,
              title: 'Signed out',
              message: 'Sign in again to edit your profile.',
            );
          }

          final fallbackProfile = _fallbackProfile(user);
          final activeProfile = profile ?? fallbackProfile;
          _syncController(activeProfile);

          return ProfileDetailsView(
            profile: activeProfile,
            displayNameController: _displayNameController,
            embedded: widget.embedded,
            uploadingPhoto: _uploadingPhoto,
            saveStatus: _saveStatus,
            hasChanges: _hasChanges,
            onClose: widget.onClose,
            onUploadPhoto: _uploadPhoto,
            onDisplayNameChanged: (_) {
              setState(() {
                _hasChanges = true;
                _saveStatus = ProfileSaveStatus.idle;
              });
            },
            onSave: () => _saveDisplayName(activeProfile.uid),
            onSignOut: _signOut,
          );
        },
      ),
    );
  }

  void _syncController(UserProfile profile) {
    if (_lastProfileUid == profile.uid) {
      return;
    }
    _lastProfileUid = profile.uid;
    _displayNameController.text = profile.displayName;
    _hasChanges = false;
  }

  UserProfile _fallbackProfile(User user) {
    final now = DateTime.now();
    return UserProfile(
      uid: user.uid,
      displayName:
          user.displayName ?? user.email?.split('@').first ?? 'JotCue User',
      email: user.email ?? '',
      photoUrl: user.photoURL,
      createdAt: now,
      updatedAt: now,
    );
  }

  Future<void> _saveDisplayName(String uid) async {
    setState(() {
      _saveStatus = ProfileSaveStatus.saving;
    });

    try {
      await ref
          .read(userProfileRepositoryProvider)
          .updateDisplayName(uid, _displayNameController.text);
      if (!mounted) {
        return;
      }
      setState(() {
        _hasChanges = false;
        _saveStatus = ProfileSaveStatus.saved;
      });
      _showMessage('Profile saved.');
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _saveStatus = ProfileSaveStatus.failed;
      });
      _showMessage('Save failed: $error');
    }
  }

  Future<void> _uploadPhoto() async {
    if (_uploadingPhoto) {
      return;
    }

    final user = ref.read(firebaseAuthProvider).currentUser;
    if (user == null) {
      return;
    }

    final image = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (image == null) {
      return;
    }

    setState(() {
      _uploadingPhoto = true;
    });

    try {
      await ref
          .read(userProfileRepositoryProvider)
          .uploadProfileImage(user.uid, image);
      if (mounted) {
        _showMessage('Profile photo updated.');
      }
    } catch (error) {
      if (mounted) {
        _showMessage('Could not upload photo: $error');
      }
    } finally {
      if (mounted) {
        setState(() {
          _uploadingPhoto = false;
        });
      }
    }
  }

  Future<void> _signOut() async {
    await ref.read(authServiceProvider).signOut();
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class ProfileDetailsView extends StatelessWidget {
  const ProfileDetailsView({
    super.key,
    required this.profile,
    required this.displayNameController,
    required this.uploadingPhoto,
    required this.saveStatus,
    required this.hasChanges,
    required this.onUploadPhoto,
    required this.onDisplayNameChanged,
    required this.onSave,
    required this.onSignOut,
    this.embedded = false,
    this.onClose,
  });

  final UserProfile profile;
  final TextEditingController displayNameController;
  final bool embedded;
  final bool uploadingPhoto;
  final ProfileSaveStatus saveStatus;
  final bool hasChanges;
  final VoidCallback? onClose;
  final VoidCallback onUploadPhoto;
  final ValueChanged<String> onDisplayNameChanged;
  final VoidCallback onSave;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final horizontalPadding = embedded
                ? AppSpacing.xl
                : constraints.maxWidth < 420
                ? AppSpacing.sm
                : AppSpacing.md;

            return ListView(
              padding: EdgeInsets.fromLTRB(
                horizontalPadding,
                embedded ? AppSpacing.xl : AppSpacing.sm,
                horizontalPadding,
                AppSpacing.xl,
              ),
              children: [
                if (embedded) ...[
                  SectionHeader(
                    title: 'Profile',
                    subtitle: 'Your JotCue identity and account details.',
                    trailing: IconButton(
                      tooltip: 'Close profile',
                      onPressed: onClose,
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                ],
                _ProfileHero(
                  profile: profile,
                  uploading: uploadingPhoto,
                  onUpload: onUploadPhoto,
                ),
                const SizedBox(height: AppSpacing.md),
                AppCard(
                  color: AppColors.panelFor(context),
                  borderColor: AppColors.panelBorderFor(context),
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Personal details',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'Choose the name shown throughout your workspace.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      TextField(
                        controller: displayNameController,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(
                          labelText: 'Display name',
                          prefixIcon: Icon(Icons.badge_outlined),
                        ),
                        onChanged: onDisplayNameChanged,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          prefixIcon: Icon(Icons.mail_outline_rounded),
                        ),
                        child: Text(
                          profile.email.isEmpty
                              ? 'No email on file'
                              : profile.email,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      LayoutBuilder(
                        builder: (context, actionConstraints) {
                          final stackActions = actionConstraints.maxWidth < 430;
                          final status = _SaveStatusText(
                            saveStatus,
                            hasChanges: hasChanges,
                          );
                          final saveButton = FilledButton.icon(
                            onPressed:
                                saveStatus == ProfileSaveStatus.saving ||
                                    !hasChanges
                                ? null
                                : onSave,
                            icon: saveStatus == ProfileSaveStatus.saving
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.check_rounded),
                            label: Text(
                              saveStatus == ProfileSaveStatus.saving
                                  ? 'Saving'
                                  : 'Update profile',
                            ),
                          );

                          if (stackActions) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                status,
                                const SizedBox(height: AppSpacing.sm),
                                saveButton,
                              ],
                            );
                          }

                          return Row(
                            children: [
                              Expanded(child: status),
                              const SizedBox(width: AppSpacing.md),
                              SizedBox(width: 176, child: saveButton),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                AppCard(
                  color: AppColors.panelFor(context),
                  borderColor: AppColors.panelBorderFor(context),
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final compact = constraints.maxWidth < 440;
                      final copy = Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Account session',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: AppSpacing.xxs),
                          Text(
                            'Sign out of JotCue on this device.',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      );
                      final button = OutlinedButton.icon(
                        onPressed: onSignOut,
                        icon: const Icon(Icons.logout_rounded),
                        label: const Text('Sign out'),
                      );

                      if (compact) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            copy,
                            const SizedBox(height: AppSpacing.md),
                            button,
                          ],
                        );
                      }

                      return Row(
                        children: [
                          Expanded(child: copy),
                          const SizedBox(width: AppSpacing.md),
                          SizedBox(width: 148, child: button),
                        ],
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ProfileHero extends StatelessWidget {
  const _ProfileHero({
    required this.profile,
    required this.uploading,
    required this.onUpload,
  });

  final UserProfile profile;
  final bool uploading;
  final VoidCallback onUpload;

  @override
  Widget build(BuildContext context) {
    final surface = AppColors.panelFor(context);
    final firstTint = Color.alphaBlend(
      AppColors.primary.withValues(alpha: 0.12),
      surface,
    );
    final secondTint = Color.alphaBlend(
      AppColors.teal.withValues(alpha: 0.10),
      surface,
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [firstTint, secondTint],
        ),
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(color: AppColors.panelBorderFor(context)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final horizontal = constraints.maxWidth >= 500;
            final identity = Column(
              crossAxisAlignment: horizontal
                  ? CrossAxisAlignment.start
                  : CrossAxisAlignment.center,
              children: [
                Text(
                  'JotCue account',
                  style: Theme.of(
                    context,
                  ).textTheme.labelLarge?.copyWith(color: AppColors.primary),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  profile.displayName.trim().isEmpty
                      ? 'JotCue user'
                      : profile.displayName.trim(),
                  textAlign: horizontal ? TextAlign.start : TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  profile.email.isEmpty ? 'No email on file' : profile.email,
                  textAlign: horizontal ? TextAlign.start : TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: AppSpacing.sm),
                TextButton.icon(
                  onPressed: uploading ? null : onUpload,
                  icon: const Icon(Icons.add_a_photo_outlined),
                  label: Text(uploading ? 'Uploading...' : 'Change photo'),
                ),
              ],
            );

            if (!horizontal) {
              return Column(
                children: [
                  _ProfileAvatar(profile: profile, uploading: uploading),
                  const SizedBox(height: AppSpacing.md),
                  identity,
                ],
              );
            }

            return Row(
              children: [
                _ProfileAvatar(profile: profile, uploading: uploading),
                const SizedBox(width: AppSpacing.lg),
                Expanded(child: identity),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({required this.profile, required this.uploading});

  final UserProfile profile;
  final bool uploading;

  @override
  Widget build(BuildContext context) {
    final photoUrl = profile.photoUrl;
    final initial = profile.displayName.trim().isEmpty
        ? 'P'
        : profile.displayName.trim()[0].toUpperCase();
    final fallbackForeground = AppColors.textFor(AppColors.surface);

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [AppColors.primary, AppColors.butter, AppColors.teal],
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircleAvatar(
            radius: 46,
            backgroundColor: AppColors.surface,
            backgroundImage: photoUrl == null || photoUrl.isEmpty
                ? null
                : NetworkImage(
                    photoUrl,
                    webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
                  ),
            child: photoUrl == null || photoUrl.isEmpty
                ? Text(
                    initial,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: fallbackForeground,
                    ),
                  )
                : null,
          ),
          if (uploading)
            Container(
              width: 92,
              height: 92,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.brandInk.withValues(alpha: 0.45),
              ),
              alignment: Alignment.center,
              child: const SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  color: Colors.white,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SaveStatusText extends StatelessWidget {
  const _SaveStatusText(this.status, {required this.hasChanges});

  final ProfileSaveStatus status;
  final bool hasChanges;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      ProfileSaveStatus.idle =>
        hasChanges
            ? ('Unsaved changes', AppColors.warning)
            : ('Up to date', AppColors.teal),
      ProfileSaveStatus.saving => ('Saving changes...', AppColors.muted),
      ProfileSaveStatus.saved => ('Profile updated', AppColors.teal),
      ProfileSaveStatus.failed => (
        'Save failed',
        Theme.of(context).colorScheme.error,
      ),
    };

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          status == ProfileSaveStatus.failed
              ? Icons.error_outline_rounded
              : status == ProfileSaveStatus.saving
              ? Icons.sync_rounded
              : hasChanges
              ? Icons.edit_outlined
              : Icons.check_circle_outline_rounded,
          size: 18,
          color: color,
        ),
        const SizedBox(width: AppSpacing.xs),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}
