import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/services/app_theme.dart';
import 'core/services/local_notifications_service.dart';
import 'core/widgets/offline_status_indicator.dart';
import 'features/auth/presentation/auth_gate.dart';
import 'features/reminders/providers/reminders_providers.dart';
import 'firebase_options.dart';

final FlutterLocalNotificationsPlugin notificationsPlugin =
    FlutterLocalNotificationsPlugin();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );
  final notificationsService = LocalNotificationsService(notificationsPlugin);
  await notificationsService.initialize();

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
      child: const PulseNotesApp(),
    ),
  );
}

class PulseNotesApp extends StatelessWidget {
  const PulseNotesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PulseNotes',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.build(),
      builder: (context, child) {
        return Stack(
          children: [
            child ?? const SizedBox.shrink(),
            const OfflineStatusIndicator(),
          ],
        );
      },
      home: const AuthGate(),
    );
  }
}
