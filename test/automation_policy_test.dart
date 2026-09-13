import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/features/automation/data/automation_policy.dart';
import 'package:pulse/features/automation/models/automation_preferences.dart';

void main() {
  const policy = AutomationPolicy();

  AutomationDecision evaluate(
    AutomationLevel level,
    AutomationActionKind action,
  ) {
    return policy.evaluate(
      preferences: AutomationPreferences(level: level),
      action: action,
    );
  }

  test('observe never prepares an assistant mutation', () {
    for (final action in AutomationActionKind.values) {
      expect(
        evaluate(AutomationLevel.observe, action),
        AutomationDecision.observeOnly,
      );
    }
  });

  test('suggest stays recommendation-only', () {
    for (final action in AutomationActionKind.values) {
      expect(
        evaluate(AutomationLevel.suggest, action),
        AutomationDecision.suggestOnly,
      );
    }
  });

  test('approval requires approval for local schedule moves', () {
    expect(
      evaluate(
        AutomationLevel.approval,
        AutomationActionKind.localScheduleMove,
      ),
      AutomationDecision.requiresApproval,
    );
  });

  test('trusted makes only local schedule moves eligible', () {
    expect(
      evaluate(AutomationLevel.trusted, AutomationActionKind.localScheduleMove),
      AutomationDecision.trustedEligible,
    );
  });

  test('trusted calendar writes still require approval', () {
    expect(
      evaluate(
        AutomationLevel.trusted,
        AutomationActionKind.externalCalendarWrite,
      ),
      AutomationDecision.requiresApproval,
    );
  });

  test('trusted completion decisions still require approval', () {
    expect(
      evaluate(
        AutomationLevel.trusted,
        AutomationActionKind.workReviewDecision,
      ),
      AutomationDecision.requiresApproval,
    );
  });

  test('trusted structured capture still requires approval', () {
    expect(
      evaluate(
        AutomationLevel.trusted,
        AutomationActionKind.structuredCaptureCreate,
      ),
      AutomationDecision.requiresApproval,
    );
  });
}
