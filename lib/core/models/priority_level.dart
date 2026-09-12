enum PriorityLevel {
  none,
  low,
  medium,
  high,
  critical;

  static PriorityLevel fromValue(String? value) {
    return PriorityLevel.values.firstWhere(
      (level) => level.name == value,
      orElse: () => PriorityLevel.none,
    );
  }
}
