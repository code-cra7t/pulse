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

enum _ProfileSaveStatus { idle, saving, saved, failed }

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key, this.embedded = false, this.onClose});

  final bool embedded;
  final VoidCallback? onClose;

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  late final TextEditingController _displayNameController;
  _ProfileSaveStatus _saveStatus = _ProfileSaveStatus.idle;
  bool _uploadingPhoto = false;
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
      backgroundColor: widget.embedded ? Colors.transparent : null,
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

          return Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: ListView(
                padding: EdgeInsets.fromLTRB(
                  widget.embedded ? AppSpacing.xl : AppSpacing.md,
                  AppSpacing.lg,
                  widget.embedded ? AppSpacing.xl : AppSpacing.md,
                  AppSpacing.xl,
                ),
                children: [
                  if (widget.embedded)
                    SectionHeader(
                      title: 'Profile',
                      subtitle: 'Your PulseNotes identity and avatar.',
                      trailing: IconButton(
                        onPressed: widget.onClose,
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ),
                  if (widget.embedded) const SizedBox(height: AppSpacing.lg),
                  AppCard(
                    color: AppColors.lavender,
                    child: Column(
                      children: [
                        _ProfileAvatar(
                          profile: activeProfile,
                          uploading: _uploadingPhoto,
                          onUpload: _uploadPhoto,
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        TextField(
                          controller: _displayNameController,
                          textCapitalization: TextCapitalization.words,
                          decoration: const InputDecoration(
                            labelText: 'Display name',
                            prefixIcon: Icon(Icons.badge_outlined),
                          ),
                          onChanged: (_) {
                            setState(() {
                              _saveStatus = _ProfileSaveStatus.idle;
                            });
                          },
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Email',
                            prefixIcon: Icon(Icons.mail_outline_rounded),
                          ),
                          child: Text(
                            activeProfile.email.isEmpty
                                ? 'No email on file'
                                : activeProfile.email,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Row(
                          children: [
                            Expanded(child: _SaveStatusText(_saveStatus)),
                            const SizedBox(width: AppSpacing.sm),
                            FilledButton(
                              onPressed:
                                  _saveStatus == _ProfileSaveStatus.saving
                                  ? null
                                  : () => _saveDisplayName(activeProfile.uid),
                              child: const Text('Save profile'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  OutlinedButton.icon(
                    onPressed: _signOut,
                    icon: const Icon(Icons.logout_rounded),
                    label: const Text('Sign out'),
                  ),
                ],
              ),
            ),
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
  }

  UserProfile _fallbackProfile(User user) {
    final now = DateTime.now();
    return UserProfile(
      uid: user.uid,
      displayName:
          user.displayName ?? user.email?.split('@').first ?? 'PulseNotes User',
      email: user.email ?? '',
      photoUrl: user.photoURL,
      createdAt: now,
      updatedAt: now,
    );
  }

  Future<void> _saveDisplayName(String uid) async {
    setState(() {
      _saveStatus = _ProfileSaveStatus.saving;
    });

    try {
      await ref
          .read(userProfileRepositoryProvider)
          .updateDisplayName(uid, _displayNameController.text);
      if (!mounted) {
        return;
      }
      setState(() {
        _saveStatus = _ProfileSaveStatus.saved;
      });
      _showMessage('Profile saved.');
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _saveStatus = _ProfileSaveStatus.failed;
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

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({
    required this.profile,
    required this.uploading,
    required this.onUpload,
  });

  final UserProfile profile;
  final bool uploading;
  final VoidCallback onUpload;

  @override
  Widget build(BuildContext context) {
    final photoUrl = profile.photoUrl;
    final initial = profile.displayName.trim().isEmpty
        ? 'P'
        : profile.displayName.trim()[0].toUpperCase();
    final fallbackForeground = AppColors.textFor(AppColors.surface);

    return Column(
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            CircleAvatar(
              radius: 48,
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
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(color: fallbackForeground),
                    )
                  : null,
            ),
            if (uploading)
              const SizedBox(
                width: 42,
                height: 42,
                child: CircularProgressIndicator(strokeWidth: 3),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        TextButton.icon(
          onPressed: uploading ? null : onUpload,
          icon: const Icon(Icons.add_a_photo_outlined),
          label: Text(uploading ? 'Uploading...' : 'Change photo'),
        ),
      ],
    );
  }
}

class _SaveStatusText extends StatelessWidget {
  const _SaveStatusText(this.status);

  final _ProfileSaveStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      _ProfileSaveStatus.idle => ('Not saved', AppColors.muted),
      _ProfileSaveStatus.saving => ('Saving...', AppColors.muted),
      _ProfileSaveStatus.saved => ('Saved', AppColors.teal),
      _ProfileSaveStatus.failed => (
        'Save failed',
        Theme.of(context).colorScheme.error,
      ),
    };

    return Text(
      label,
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
        color: color,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}
