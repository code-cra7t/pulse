class SchedulingPreferences {
  const SchedulingPreferences({
    required this.isConfigured,
    required this.dayStartMinutes,
    required this.dayEndMinutes,
    required this.availableWeekdays,
    required this.minimumBlockMinutes,
    required this.preferredBlockMinutes,
    required this.breakMinutes,
    required this.maxFocusMinutesPerDay,
    required this.defaultTaskMinutes,
    required this.protectLunch,
    required this.lunchStartMinutes,
    required this.lunchEndMinutes,
  });

  final bool isConfigured;
  final int dayStartMinutes;
  final int dayEndMinutes;
  final List<int> availableWeekdays;
  final int minimumBlockMinutes;
  final int preferredBlockMinutes;
  final int breakMinutes;
  final int maxFocusMinutesPerDay;
  final int defaultTaskMinutes;
  final bool protectLunch;
  final int lunchStartMinutes;
  final int lunchEndMinutes;

  static const int minutesPerDay = 24 * 60;

  factory SchedulingPreferences.defaults() {
    return const SchedulingPreferences(
      isConfigured: false,
      dayStartMinutes: 8 * 60,
      dayEndMinutes: 20 * 60,
      availableWeekdays: [
        DateTime.monday,
        DateTime.tuesday,
        DateTime.wednesday,
        DateTime.thursday,
        DateTime.friday,
      ],
      minimumBlockMinutes: 30,
      preferredBlockMinutes: 90,
      breakMinutes: 15,
      maxFocusMinutesPerDay: 360,
      defaultTaskMinutes: 30,
      protectLunch: false,
      lunchStartMinutes: 12 * 60 + 30,
      lunchEndMinutes: 13 * 60 + 30,
    );
  }

  factory SchedulingPreferences.fromMap(Object? raw) {
    if (raw is! Map) {
      return SchedulingPreferences.defaults();
    }
    final data = Map<String, dynamic>.from(raw);
    final weekdays =
        (data['availableWeekdays'] as List?)
            ?.whereType<num>()
            .map((value) => value.toInt())
            .where(
              (value) => value >= DateTime.monday && value <= DateTime.sunday,
            )
            .toSet()
            .toList()
          ?..sort();

    final preferences = SchedulingPreferences(
      isConfigured: data['isConfigured'] == true,
      dayStartMinutes: _intValue(data['dayStartMinutes'], 8 * 60),
      dayEndMinutes: _intValue(data['dayEndMinutes'], 20 * 60),
      availableWeekdays: weekdays == null || weekdays.isEmpty
          ? SchedulingPreferences.defaults().availableWeekdays
          : weekdays,
      minimumBlockMinutes: _intValue(data['minimumBlockMinutes'], 30),
      preferredBlockMinutes: _intValue(data['preferredBlockMinutes'], 90),
      breakMinutes: _intValue(data['breakMinutes'], 15),
      maxFocusMinutesPerDay: _intValue(data['maxFocusMinutesPerDay'], 360),
      defaultTaskMinutes: _intValue(data['defaultTaskMinutes'], 30),
      protectLunch: data['protectLunch'] == true,
      lunchStartMinutes: _intValue(data['lunchStartMinutes'], 12 * 60 + 30),
      lunchEndMinutes: _intValue(data['lunchEndMinutes'], 13 * 60 + 30),
    );
    return preferences.isValid ? preferences : SchedulingPreferences.defaults();
  }

  bool get isValid {
    if (dayStartMinutes < 0 || dayStartMinutes >= minutesPerDay) {
      return false;
    }
    if (dayEndMinutes <= 0 || dayEndMinutes >= minutesPerDay) {
      return false;
    }
    if (dayEndMinutes <= dayStartMinutes) {
      return false;
    }
    if (availableWeekdays.isEmpty ||
        availableWeekdays.any(
          (day) => day < DateTime.monday || day > DateTime.sunday,
        )) {
      return false;
    }
    if (minimumBlockMinutes < 15 || minimumBlockMinutes > 240) {
      return false;
    }
    if (preferredBlockMinutes < minimumBlockMinutes ||
        preferredBlockMinutes > 360) {
      return false;
    }
    if (breakMinutes < 0 || breakMinutes > 120) {
      return false;
    }
    if (maxFocusMinutesPerDay < minimumBlockMinutes ||
        maxFocusMinutesPerDay > 16 * 60) {
      return false;
    }
    if (defaultTaskMinutes < 15 || defaultTaskMinutes > 8 * 60) {
      return false;
    }
    if (protectLunch) {
      if (lunchStartMinutes < dayStartMinutes ||
          lunchEndMinutes > dayEndMinutes ||
          lunchEndMinutes <= lunchStartMinutes) {
        return false;
      }
    }
    return true;
  }

  bool isEnabledOn(DateTime date) => availableWeekdays.contains(date.weekday);

  DateTime startFor(DateTime date) => _atMinutes(date, dayStartMinutes);

  DateTime endFor(DateTime date) => _atMinutes(date, dayEndMinutes);

  DateTime lunchStartFor(DateTime date) => _atMinutes(date, lunchStartMinutes);

  DateTime lunchEndFor(DateTime date) => _atMinutes(date, lunchEndMinutes);

  Map<String, dynamic> toMap() {
    return {
      'isConfigured': isConfigured,
      'dayStartMinutes': dayStartMinutes,
      'dayEndMinutes': dayEndMinutes,
      'availableWeekdays': availableWeekdays,
      'minimumBlockMinutes': minimumBlockMinutes,
      'preferredBlockMinutes': preferredBlockMinutes,
      'breakMinutes': breakMinutes,
      'maxFocusMinutesPerDay': maxFocusMinutesPerDay,
      'defaultTaskMinutes': defaultTaskMinutes,
      'protectLunch': protectLunch,
      'lunchStartMinutes': lunchStartMinutes,
      'lunchEndMinutes': lunchEndMinutes,
    };
  }

  SchedulingPreferences copyWith({
    bool? isConfigured,
    int? dayStartMinutes,
    int? dayEndMinutes,
    List<int>? availableWeekdays,
    int? minimumBlockMinutes,
    int? preferredBlockMinutes,
    int? breakMinutes,
    int? maxFocusMinutesPerDay,
    int? defaultTaskMinutes,
    bool? protectLunch,
    int? lunchStartMinutes,
    int? lunchEndMinutes,
  }) {
    return SchedulingPreferences(
      isConfigured: isConfigured ?? this.isConfigured,
      dayStartMinutes: dayStartMinutes ?? this.dayStartMinutes,
      dayEndMinutes: dayEndMinutes ?? this.dayEndMinutes,
      availableWeekdays: availableWeekdays ?? this.availableWeekdays,
      minimumBlockMinutes: minimumBlockMinutes ?? this.minimumBlockMinutes,
      preferredBlockMinutes:
          preferredBlockMinutes ?? this.preferredBlockMinutes,
      breakMinutes: breakMinutes ?? this.breakMinutes,
      maxFocusMinutesPerDay:
          maxFocusMinutesPerDay ?? this.maxFocusMinutesPerDay,
      defaultTaskMinutes: defaultTaskMinutes ?? this.defaultTaskMinutes,
      protectLunch: protectLunch ?? this.protectLunch,
      lunchStartMinutes: lunchStartMinutes ?? this.lunchStartMinutes,
      lunchEndMinutes: lunchEndMinutes ?? this.lunchEndMinutes,
    );
  }
}

int _intValue(Object? value, int fallback) {
  return value is num ? value.toInt() : fallback;
}

DateTime _atMinutes(DateTime date, int minutes) {
  final day = DateTime(date.year, date.month, date.day);
  return day.add(Duration(minutes: minutes));
}
