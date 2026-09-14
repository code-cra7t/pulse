import '../../automation/data/automation_policy.dart';
import '../../automation/models/automation_preferences.dart';
import '../models/ask_jotcue.dart';
import 'ask_jotcue_action_executor.dart';
import 'ask_jotcue_plan_builder.dart';

enum AskJotCuePlanStepStatus { succeeded, failed, notRun }

class AskJotCuePlanStepExecution {
  const AskJotCuePlanStepExecution({
    required this.index,
    required this.proposal,
    required this.status,
    required this.message,
  });

  final int index;
  final AskJotCueActionProposal proposal;
  final AskJotCuePlanStepStatus status;
  final String message;
}

class AskJotCuePlanExecutionResult {
  const AskJotCuePlanExecutionResult({required this.steps});

  final List<AskJotCuePlanStepExecution> steps;

  int get succeededCount => steps
      .where((step) => step.status == AskJotCuePlanStepStatus.succeeded)
      .length;

  bool get isComplete =>
      steps.isNotEmpty &&
      steps.every((step) => step.status == AskJotCuePlanStepStatus.succeeded);

  List<AskJotCueActionProposal> get succeededProposals => steps
      .where((step) => step.status == AskJotCuePlanStepStatus.succeeded)
      .map((step) => step.proposal)
      .toList(growable: false);

  String get summary {
    if (isComplete) {
      return 'Applied all ${steps.length} plan steps.';
    }
    final failed = steps.firstWhere(
      (step) => step.status == AskJotCuePlanStepStatus.failed,
    );
    return 'Applied $succeededCount of ${steps.length} plan steps. '
        'Step ${failed.index + 1} failed: ${failed.message} '
        'Remaining steps were not run. Ask again before retrying this plan.';
  }
}

/// Executes a previously reviewed plan one existing typed action at a time.
///
/// The plan is preflighted against the current automation policy before the
/// first mutation. Execution then stops on the first failed/stale step. This is
/// intentionally not transactional: successful earlier steps are reported as
/// applied rather than pretending they were rolled back.
class AskJotCuePlanExecutor {
  const AskJotCuePlanExecutor({required AskJotCueActionExecutor actionExecutor})
    : _actionExecutor = actionExecutor;

  final AskJotCueActionExecutor _actionExecutor;

  Future<AskJotCuePlanExecutionResult> execute({
    required AutomationPreferences preferences,
    required AskJotCueActionPlan plan,
    required DateTime now,
    required bool approved,
  }) async {
    _validate(plan);
    if (!approved) {
      throw StateError('This plan still needs your confirmation.');
    }

    for (final proposal in plan.steps) {
      _actionExecutor.validateOwnership(proposal);
      final decision = _actionExecutor.decisionFor(
        preferences: preferences,
        proposal: proposal,
      );
      if (decision == AutomationDecision.observeOnly) {
        throw StateError(
          'Assistant permissions are set to Observe, so no plan steps were applied.',
        );
      }
      if (decision == AutomationDecision.suggestOnly) {
        throw StateError(
          'Assistant permissions are set to Suggest, so this plan remains a suggestion.',
        );
      }
    }

    final executions = <AskJotCuePlanStepExecution>[];
    for (var index = 0; index < plan.steps.length; index++) {
      final proposal = plan.steps[index];
      try {
        final message = await _actionExecutor.execute(
          preferences: preferences,
          proposal: proposal,
          now: now,
          approved: true,
        );
        executions.add(
          AskJotCuePlanStepExecution(
            index: index,
            proposal: proposal,
            status: AskJotCuePlanStepStatus.succeeded,
            message: message,
          ),
        );
      } catch (error) {
        executions.add(
          AskJotCuePlanStepExecution(
            index: index,
            proposal: proposal,
            status: AskJotCuePlanStepStatus.failed,
            message: _errorMessage(error),
          ),
        );
        for (
          var remaining = index + 1;
          remaining < plan.steps.length;
          remaining++
        ) {
          executions.add(
            AskJotCuePlanStepExecution(
              index: remaining,
              proposal: plan.steps[remaining],
              status: AskJotCuePlanStepStatus.notRun,
              message: 'Not run because an earlier step failed.',
            ),
          );
        }
        return AskJotCuePlanExecutionResult(
          steps: List<AskJotCuePlanStepExecution>.unmodifiable(executions),
        );
      }
    }

    return AskJotCuePlanExecutionResult(
      steps: List<AskJotCuePlanStepExecution>.unmodifiable(executions),
    );
  }

  void _validate(AskJotCueActionPlan plan) {
    if (plan.steps.length < 2 ||
        plan.steps.length > AskJotCuePlanBuilder.maxSteps) {
      throw StateError(
        'A multi-step plan must contain between 2 and ${AskJotCuePlanBuilder.maxSteps} steps.',
      );
    }
    final ids = plan.steps.map((proposal) => proposal.id).toSet();
    if (ids.length != plan.steps.length) {
      throw StateError('A multi-step plan cannot contain duplicate actions.');
    }
    final userIds = plan.steps.map((proposal) => proposal.userId).toSet();
    if (userIds.length != 1 || userIds.single.trim().isEmpty) {
      throw StateError(
        'All plan steps must belong to the same signed-in account.',
      );
    }
  }

  String _errorMessage(Object error) {
    final value = error.toString();
    const prefix = 'Bad state: ';
    return value.startsWith(prefix) ? value.substring(prefix.length) : value;
  }
}
