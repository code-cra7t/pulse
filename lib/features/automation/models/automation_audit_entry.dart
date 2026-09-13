import '../data/automation_policy.dart';

enum AutomationAuditStatus {
  pending,
  succeeded,
  failed,
  undoPending,
  undone;

  static AutomationAuditStatus fromValue(String? value) {
    return AutomationAuditStatus.values.firstWhere(
      (status) => status.name == value,
      orElse: () => AutomationAuditStatus.failed,
    );
  }
}

class AutomationAuditEntry {
  const AutomationAuditEntry({
    required this.id,
    required this.userId,
    required this.action,
    required this.issueId,
    required this.blockId,
    required this.title,
    required this.reason,
    required this.fromStartsAt,
    required this.fromEndsAt,
    required this.toStartsAt,
    required this.toEndsAt,
    required this.executedAt,
    required this.status,
    this.error,
    this.undoRequestedAt,
    this.undoneAt,
    this.undoError,
  });

  final String id;
  final String userId;
  final AutomationActionKind action;
  final String issueId;
  final String blockId;
  final String title;
  final String reason;
  final DateTime fromStartsAt;
  final DateTime fromEndsAt;
  final DateTime toStartsAt;
  final DateTime toEndsAt;
  final DateTime executedAt;
  final AutomationAuditStatus status;
  final String? error;
  final DateTime? undoRequestedAt;
  final DateTime? undoneAt;
  final String? undoError;

  DateTime get cooldownAnchor => undoneAt ?? undoRequestedAt ?? executedAt;

  bool get wasApplied =>
      status == AutomationAuditStatus.succeeded ||
      status == AutomationAuditStatus.undoPending ||
      status == AutomationAuditStatus.undone;

  AutomationAuditEntry copyWith({
    AutomationAuditStatus? status,
    Object? error = _unchanged,
    Object? undoRequestedAt = _unchanged,
    Object? undoneAt = _unchanged,
    Object? undoError = _unchanged,
  }) {
    return AutomationAuditEntry(
      id: id,
      userId: userId,
      action: action,
      issueId: issueId,
      blockId: blockId,
      title: title,
      reason: reason,
      fromStartsAt: fromStartsAt,
      fromEndsAt: fromEndsAt,
      toStartsAt: toStartsAt,
      toEndsAt: toEndsAt,
      executedAt: executedAt,
      status: status ?? this.status,
      error: identical(error, _unchanged) ? this.error : error as String?,
      undoRequestedAt: identical(undoRequestedAt, _unchanged)
          ? this.undoRequestedAt
          : undoRequestedAt as DateTime?,
      undoneAt: identical(undoneAt, _unchanged)
          ? this.undoneAt
          : undoneAt as DateTime?,
      undoError: identical(undoError, _unchanged)
          ? this.undoError
          : undoError as String?,
    );
  }

  factory AutomationAuditEntry.fromLocalMap(Map<String, dynamic> data) {
    return AutomationAuditEntry(
      id: data['id'] as String? ?? '',
      userId: data['userId'] as String? ?? '',
      action: _actionFromValue(data['action'] as String?),
      issueId: data['issueId'] as String? ?? '',
      blockId: data['blockId'] as String? ?? '',
      title: data['title'] as String? ?? '',
      reason: data['reason'] as String? ?? '',
      fromStartsAt: DateTime.fromMillisecondsSinceEpoch(
        data['fromStartsAtMs'] as int? ?? 0,
      ),
      fromEndsAt: DateTime.fromMillisecondsSinceEpoch(
        data['fromEndsAtMs'] as int? ?? 0,
      ),
      toStartsAt: DateTime.fromMillisecondsSinceEpoch(
        data['toStartsAtMs'] as int? ?? 0,
      ),
      toEndsAt: DateTime.fromMillisecondsSinceEpoch(
        data['toEndsAtMs'] as int? ?? 0,
      ),
      executedAt: DateTime.fromMillisecondsSinceEpoch(
        data['executedAtMs'] as int? ?? 0,
      ),
      status: AutomationAuditStatus.fromValue(data['status'] as String?),
      error: data['error'] as String?,
      undoRequestedAt: _dateFromMilliseconds(data['undoRequestedAtMs']),
      undoneAt: _dateFromMilliseconds(data['undoneAtMs']),
      undoError: data['undoError'] as String?,
    );
  }

  Map<String, dynamic> toLocalMap() => {
    'id': id,
    'userId': userId,
    'action': action.name,
    'issueId': issueId,
    'blockId': blockId,
    'title': title,
    'reason': reason,
    'fromStartsAtMs': fromStartsAt.millisecondsSinceEpoch,
    'fromEndsAtMs': fromEndsAt.millisecondsSinceEpoch,
    'toStartsAtMs': toStartsAt.millisecondsSinceEpoch,
    'toEndsAtMs': toEndsAt.millisecondsSinceEpoch,
    'executedAtMs': executedAt.millisecondsSinceEpoch,
    'status': status.name,
    'error': error,
    'undoRequestedAtMs': undoRequestedAt?.millisecondsSinceEpoch,
    'undoneAtMs': undoneAt?.millisecondsSinceEpoch,
    'undoError': undoError,
  };
}

AutomationActionKind _actionFromValue(String? value) {
  return AutomationActionKind.values.firstWhere(
    (action) => action.name == value,
    orElse: () => AutomationActionKind.localScheduleMove,
  );
}

DateTime? _dateFromMilliseconds(Object? value) {
  return value is int ? DateTime.fromMillisecondsSinceEpoch(value) : null;
}

const _unchanged = Object();
