class CalendarQueryRange {
  const CalendarQueryRange({required this.start, required this.end});

  final DateTime start;
  final DateTime end;

  bool get isValid => end.isAfter(start);

  @override
  bool operator ==(Object other) {
    return other is CalendarQueryRange &&
        other.start == start &&
        other.end == end;
  }

  @override
  int get hashCode => Object.hash(start, end);
}
