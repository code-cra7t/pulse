import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../notes/presentation/notes_home_screen.dart';
import '../../profile/providers/user_profile_providers.dart';
import '../../settings/providers/user_settings_providers.dart';
import '../providers/auth_providers.dart';
import 'login_screen.dart';
import 'welcome_screen.dart';

class AuthGate extends ConsumerStatefulWidget {
  const AuthGate({super.key});

  @override
  ConsumerState<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends ConsumerState<AuthGate> {
  bool _showLogin = false;
  final Set<String> _initializedUsers = <String>{};

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateChangesProvider);

    return authState.when(
      data: (user) {
        if (user == null) {
          if (_showLogin) {
            return const LoginScreen();
          }
          return WelcomeScreen(
            onStart: () {
              setState(() {
                _showLogin = true;
              });
            },
          );
        }

        _ensureUserDocuments(user);
        return const NotesHomeScreen();
      },
      loading: () => const Scaffold(
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.note_alt_outlined, size: 48),
                SizedBox(height: 12),
                Text('Opening PulseNotes...'),
              ],
            ),
          ),
        ),
      ),
      error: (error, stackTrace) => Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Something went wrong while checking your session.\n$error',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }

  void _ensureUserDocuments(User user) {
    if (!_initializedUsers.add(user.uid)) {
      return;
    }

    unawaited(
      Future.wait([
        ref.read(userProfileRepositoryProvider).createProfileIfMissing(user),
        ref
            .read(userSettingsRepositoryProvider)
            .createSettingsIfMissing(user.uid),
      ]).catchError((error, stackTrace) {
        debugPrint(
          '[AuthGate] event=user_bootstrap_failed uid=${user.uid} '
          'error=$error\n$stackTrace',
        );
        return <void>[];
      }),
    );
  }
}
