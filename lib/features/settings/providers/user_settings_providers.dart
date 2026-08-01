import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/firebase_providers.dart';
import '../../auth/providers/auth_providers.dart';
import '../data/user_settings_repository.dart';
import '../models/user_settings.dart';

final userSettingsRepositoryProvider = Provider<UserSettingsRepository>((ref) {
  return UserSettingsRepository(ref.watch(firestoreProvider));
});

final currentUserSettingsProvider = StreamProvider<UserSettings?>((ref) {
  final authState = ref.watch(authStateChangesProvider);
  final repository = ref.watch(userSettingsRepositoryProvider);

  return authState.when(
    data: (user) {
      if (user == null) {
        return Stream.value(null);
      }
      return Stream.fromFuture(
        repository.createSettingsIfMissing(user.uid).catchError((
          error,
          stackTrace,
        ) {
          debugPrint(
            '[UserSettingsProvider] event=create_if_missing_failed '
            'uid=${user.uid} error=$error\n$stackTrace',
          );
        }),
      ).asyncExpand((_) => repository.getSettingsStream(user.uid));
    },
    loading: () => Stream.value(null),
    error: (_, _) => Stream.value(null),
  );
});

final appThemeModeProvider = Provider<ThemeMode>((ref) {
  final settings = ref.watch(currentUserSettingsProvider).asData?.value;
  return switch (settings?.themeMode ?? PulseThemeMode.system) {
    PulseThemeMode.system => ThemeMode.system,
    PulseThemeMode.light => ThemeMode.light,
    PulseThemeMode.dark => ThemeMode.dark,
  };
});
