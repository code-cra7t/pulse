enum AttentionDestination { pulse, plan }

enum AttentionKind { morningPulse, dailyClosing, deadline, scheduleIssue }

class AttentionNotificationPlan {
  const AttentionNotificationPlan({
    required this.id,
    required this.kind,
    required this.title,
    required this.body,
    required this.scheduledAt,
    required this.destination,
    this.repeatDaily = false,
  });

  final int id;
  final AttentionKind kind;
  final String title;
  final String body;
  final DateTime scheduledAt;
  final AttentionDestination destination;
  final bool repeatDaily;
}
