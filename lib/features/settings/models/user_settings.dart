import 'package:cloud_firestore/cloud_firestore.dart';

enum PulseThemeMode {
  system,
  light,
  dark;

  static PulseThemeMode fromString(String? value) {
    return PulseThemeMode.values.firstWhere(
      (mode) => mode.name == value,
      orElse: () => PulseThemeMode.system,
    );
  }
}

class UserSettings {
  const UserSettings({
    required this.themeMode,
    required this.defaultNoteTag,
    required this.notificationsEnabled,
    required this.smartRemindersEnabled,
    required this.updatedAt,
  });

  final PulseThemeMode themeMode;
  final String defaultNoteTag;
  final bool notificationsEnabled;
  final bool smartRemindersEnabled;
  final DateTime updatedAt;

  factory UserSettings.defaults() {
    return UserSettings(
      themeMode: PulseThemeMode.system,
      defaultNoteTag: 'Personal',
      notificationsEnabled: true,
      smartRemindersEnabled: true,
      updatedAt: DateTime.now(),
    );
  }

  factory UserSettings.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data();
    if (data == null) {
      return UserSettings.defaults();
    }

    final updatedAt = data['updatedAt'] as Timestamp?;
    return UserSettings(
      themeMode: PulseThemeMode.fromString(data['themeMode'] as String?),
      defaultNoteTag: data['defaultNoteTag'] as String? ?? 'Personal',
      notificationsEnabled: data['notificationsEnabled'] as bool? ?? true,
      smartRemindersEnabled: data['smartRemindersEnabled'] as bool? ?? true,
      updatedAt: updatedAt?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'themeMode': themeMode.name,
      'defaultNoteTag': defaultNoteTag,
      'notificationsEnabled': notificationsEnabled,
      'smartRemindersEnabled': smartRemindersEnabled,
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }
}
