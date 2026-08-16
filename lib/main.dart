import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/services/app_theme.dart';
import 'core/services/local_notifications_service.dart';
import 'core/widgets/offline_status_indicator.dart';
import 'core/widgets/in_app_reminder_alerts.dart';
import 'features/auth/presentation/auth_gate.dart';
import 'features/reminders/providers/reminders_providers.dart';
import 'features/settings/providers/user_settings_providers.dart';
import 'firebase_options.dart';

final FlutterLocalNotificationsPlugin notificationsPlugin =
    FlutterLocalNotificationsPlugin();
final GlobalKey<ScaffoldMessengerState> rootScaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  _configureFirestore();
  final notificationsService = LocalNotificationsService(notificationsPlugin);
  try {
    await notificationsService.initialize();
  } catch (error, stackTrace) {
    debugPrint(
      '[Startup] Local notifications could not be initialized: '
      '$error\n$stackTrace',
    );
  }

  runApp(
    ProviderScope(
      overrides: [
        flutterLocalNotificationsPluginProvider.overrideWithValue(
          notificationsPlugin,
        ),
        localNotificationsServiceProvider.overrideWithValue(
          notificationsService,
        ),
      ],
      child: const JotCueApp(),
    ),
  );
}

void _configureFirestore() {
  if (!kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS)) {
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );
  }
}

class JotCueApp extends ConsumerWidget {
  const JotCueApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: 'JotCue',
      scaffoldMessengerKey: rootScaffoldMessengerKey,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.build(),
      darkTheme: AppTheme.buildDark(),
      themeMode: ref.watch(appThemeModeProvider),
      builder: (context, child) {
        return InAppReminderAlerts(
          messengerKey: rootScaffoldMessengerKey,
          child: Stack(
            children: [
              child ?? const SizedBox.shrink(),
              const OfflineStatusIndicator(),
            ],
          ),
        );
      },
      home: const AuthGate(),
    );
  }
}
