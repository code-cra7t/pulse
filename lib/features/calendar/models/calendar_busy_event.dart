class CalendarBusyEvent {
  const CalendarBusyEvent({
    required this.id,
    required this.title,
    required this.startsAt,
    required this.endsAt,
    this.isAllDay = false,
  });

  final String id;
  final String title;
  final DateTime startsAt;
  final DateTime endsAt;
  final bool isAllDay;

  bool get isValid => endsAt.isAfter(startsAt);

  factory CalendarBusyEvent.fromPlatformMap(Map<Object?, Object?> data) {
    final startMillis = data['startsAt'];
    final endMillis = data['endsAt'];
    if (startMillis is! num || endMillis is! num) {
      throw const FormatException('Calendar event times are missing.');
    }

    return CalendarBusyEvent(
      id: (data['id'] as String?) ?? '',
      title: ((data['title'] as String?) ?? '').trim(),
      startsAt: DateTime.fromMillisecondsSinceEpoch(startMillis.toInt()),
      endsAt: DateTime.fromMillisecondsSinceEpoch(endMillis.toInt()),
      isAllDay: data['isAllDay'] == true,
    );
  }
}
