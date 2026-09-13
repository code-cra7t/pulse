import '../models/automation_preferences.dart';

enum AutomationActionKind {
  localScheduleMove,
  externalCalendarWrite,
  workReviewDecision,
  structuredCaptureCreate,
}

enum AutomationDecision {
  observeOnly,
  suggestOnly,
  requiresApproval,
  trustedEligible,
}

class AutomationPolicy {
  const AutomationPolicy();

  AutomationDecision evaluate({
    required AutomationPreferences preferences,
    required AutomationActionKind action,
  }) {
    final level = preferences.level;
    if (level == AutomationLevel.observe) {
      return AutomationDecision.observeOnly;
    }
    if (level == AutomationLevel.suggest) {
      return AutomationDecision.suggestOnly;
    }

    if (_alwaysRequiresApproval(action)) {
      return AutomationDecision.requiresApproval;
    }

    if (level == AutomationLevel.trusted) {
      return AutomationDecision.trustedEligible;
    }
    return AutomationDecision.requiresApproval;
  }

  bool _alwaysRequiresApproval(AutomationActionKind action) {
    return switch (action) {
      AutomationActionKind.externalCalendarWrite ||
      AutomationActionKind.workReviewDecision ||
      AutomationActionKind.structuredCaptureCreate => true,
      AutomationActionKind.localScheduleMove => false,
    };
  }
}
