class AttentionPreferences {
  const AttentionPreferences({
    this.enabled = true,
    this.morningPulseEnabled = true,
    this.morningMinutes = 8 * 60,
    this.dailyClosingEnabled = true,
    this.closingMinutes = 19 * 60,
    this.deadlineAlertsEnabled = true,
    this.scheduleAlertsEnabled = true,
    this.quietHoursEnabled = true,
    this.quietStartMinutes = 22 * 60,
    this.quietEndMinutes = 7 * 60,
  });

  final bool enabled;
  final bool morningPulseEnabled;
  final int morningMinutes;
  final bool dailyClosingEnabled;
  final int closingMinutes;
  final bool deadlineAlertsEnabled;
  final bool scheduleAlertsEnabled;
  final bool quietHoursEnabled;
  final int quietStartMinutes;
  final int quietEndMinutes;

  bool get isValid =>
      _minute(morningMinutes) &&
      _minute(closingMinutes) &&
      _minute(quietStartMinutes) &&
      _minute(quietEndMinutes) &&
      (!quietHoursEnabled || quietStartMinutes != quietEndMinutes);

  bool isQuiet(DateTime value) {
    if (!quietHoursEnabled) return false;
    final minute = value.hour * 60 + value.minute;
    if (quietStartMinutes < quietEndMinutes) {
      return minute >= quietStartMinutes && minute < quietEndMinutes;
    }
    return minute >= quietStartMinutes || minute < quietEndMinutes;
  }

  DateTime nextAllowed(DateTime value) {
    if (!isQuiet(value)) return value;
    final todayEnd = DateTime(
      value.year,
      value.month,
      value.day,
    ).add(Duration(minutes: quietEndMinutes));
    if (quietStartMinutes < quietEndMinutes) {
      return todayEnd;
    }
    if ((value.hour * 60 + value.minute) < quietEndMinutes) {
      return todayEnd;
    }
    return todayEnd.add(const Duration(days: 1));
  }

  AttentionPreferences copyWith({
    bool? enabled,
    bool? morningPulseEnabled,
    int? morningMinutes,
    bool? dailyClosingEnabled,
    int? closingMinutes,
    bool? deadlineAlertsEnabled,
    bool? scheduleAlertsEnabled,
    bool? quietHoursEnabled,
    int? quietStartMinutes,
    int? quietEndMinutes,
  }) {
    return AttentionPreferences(
      enabled: enabled ?? this.enabled,
      morningPulseEnabled: morningPulseEnabled ?? this.morningPulseEnabled,
      morningMinutes: morningMinutes ?? this.morningMinutes,
      dailyClosingEnabled: dailyClosingEnabled ?? this.dailyClosingEnabled,
      closingMinutes: closingMinutes ?? this.closingMinutes,
      deadlineAlertsEnabled:
          deadlineAlertsEnabled ?? this.deadlineAlertsEnabled,
      scheduleAlertsEnabled:
          scheduleAlertsEnabled ?? this.scheduleAlertsEnabled,
      quietHoursEnabled: quietHoursEnabled ?? this.quietHoursEnabled,
      quietStartMinutes: quietStartMinutes ?? this.quietStartMinutes,
      quietEndMinutes: quietEndMinutes ?? this.quietEndMinutes,
    );
  }

  Map<String, Object?> toLocalMap() => {
    'enabled': enabled,
    'morningPulseEnabled': morningPulseEnabled,
    'morningMinutes': morningMinutes,
    'dailyClosingEnabled': dailyClosingEnabled,
    'closingMinutes': closingMinutes,
    'deadlineAlertsEnabled': deadlineAlertsEnabled,
    'scheduleAlertsEnabled': scheduleAlertsEnabled,
    'quietHoursEnabled': quietHoursEnabled,
    'quietStartMinutes': quietStartMinutes,
    'quietEndMinutes': quietEndMinutes,
  };

  factory AttentionPreferences.fromLocalMap(Map<String, Object?>? data) {
    if (data == null) return const AttentionPreferences();
    return AttentionPreferences(
      enabled: data['enabled'] as bool? ?? true,
      morningPulseEnabled: data['morningPulseEnabled'] as bool? ?? true,
      morningMinutes: data['morningMinutes'] as int? ?? 8 * 60,
      dailyClosingEnabled: data['dailyClosingEnabled'] as bool? ?? true,
      closingMinutes: data['closingMinutes'] as int? ?? 19 * 60,
      deadlineAlertsEnabled: data['deadlineAlertsEnabled'] as bool? ?? true,
      scheduleAlertsEnabled: data['scheduleAlertsEnabled'] as bool? ?? true,
      quietHoursEnabled: data['quietHoursEnabled'] as bool? ?? true,
      quietStartMinutes: data['quietStartMinutes'] as int? ?? 22 * 60,
      quietEndMinutes: data['quietEndMinutes'] as int? ?? 7 * 60,
    );
  }

  static bool _minute(int value) => value >= 0 && value < 24 * 60;
}
