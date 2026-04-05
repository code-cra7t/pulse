enum RepeatType {
  none,
  daily,
  weekly;

  String get value => name;

  static RepeatType fromValue(String? value) {
    return RepeatType.values.firstWhere(
      (type) => type.value == value,
      orElse: () => RepeatType.none,
    );
  }
}
