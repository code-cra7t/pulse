import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/features/automation/data/automation_policy.dart';
import 'package:pulse/features/automation/models/automation_audit_entry.dart';

void main() {
  test('automation audit entry round-trips through local map', () {
    final entry = AutomationAuditEntry(
      id: 'audit-1',
      userId: 'user',
      action: AutomationActionKind.localScheduleMove,
      issueId: 'issue-1',
      blockId: 'block-1',
      title: 'Study',
      reason: 'Calendar conflict',
      fromStartsAt: DateTime(2026, 9, 14, 9),
      fromEndsAt: DateTime(2026, 9, 14, 10),
      toStartsAt: DateTime(2026, 9, 14, 11),
      toEndsAt: DateTime(2026, 9, 14, 12),
      executedAt: DateTime(2026, 9, 13, 16),
      status: AutomationAuditStatus.failed,
      error: 'conflict',
    );

    final restored = AutomationAuditEntry.fromLocalMap(entry.toLocalMap());

    expect(restored.id, entry.id);
    expect(restored.action, AutomationActionKind.localScheduleMove);
    expect(restored.status, AutomationAuditStatus.failed);
    expect(restored.error, 'conflict');
    expect(restored.fromStartsAt, entry.fromStartsAt);
    expect(restored.toEndsAt, entry.toEndsAt);
  });

  test('undo metadata survives local round-trip and anchors cooldown', () {
    final undoneAt = DateTime(2026, 9, 13, 16, 20);
    final entry = AutomationAuditEntry(
      id: 'audit-2',
      userId: 'user',
      action: AutomationActionKind.localScheduleMove,
      issueId: 'issue-2',
      blockId: 'block-2',
      title: 'Study',
      reason: 'Availability changed',
      fromStartsAt: DateTime(2026, 9, 14, 9),
      fromEndsAt: DateTime(2026, 9, 14, 10),
      toStartsAt: DateTime(2026, 9, 14, 11),
      toEndsAt: DateTime(2026, 9, 14, 12),
      executedAt: DateTime(2026, 9, 13, 16),
      status: AutomationAuditStatus.undone,
      undoRequestedAt: DateTime(2026, 9, 13, 16, 19),
      undoneAt: undoneAt,
    );

    final restored = AutomationAuditEntry.fromLocalMap(entry.toLocalMap());

    expect(restored.status, AutomationAuditStatus.undone);
    expect(restored.undoRequestedAt, entry.undoRequestedAt);
    expect(restored.undoneAt, undoneAt);
    expect(restored.cooldownAnchor, undoneAt);
    expect(restored.wasApplied, isTrue);
  });
}
