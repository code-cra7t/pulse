import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/app_theme.dart';
import '../../automation/data/automation_policy.dart';
import '../../automation/providers/automation_providers.dart';
import '../../pulse/models/daily_pulse_loop.dart';
import '../../pulse/models/pulse_overview.dart';
import '../../tasks/data/task_dependency_analyzer.dart';
import '../../tasks/models/task.dart';
import '../../tasks/models/task_metadata_update.dart';
import '../models/ai_assistant_preferences.dart';
import '../models/ask_jotcue.dart';
import '../providers/assistant_providers.dart';

Future<void> showAskJotCueSheet({
  required BuildContext context,
  required AskJotCueContext assistantContext,
  AiAssistantPreferences aiPreferences = const AiAssistantPreferences(),
  bool gatewayConfigured = false,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => AskJotCueSheet(
      assistantContext: assistantContext,
      aiPreferences: aiPreferences,
      gatewayConfigured: gatewayConfigured,
    ),
  );
}

class AskJotCueSheet extends ConsumerStatefulWidget {
  const AskJotCueSheet({
    super.key,
    required this.assistantContext,
    this.aiPreferences = const AiAssistantPreferences(),
    this.gatewayConfigured = false,
  });

  final AskJotCueContext assistantContext;
  final AiAssistantPreferences aiPreferences;
  final bool gatewayConfigured;

  @override
  ConsumerState<AskJotCueSheet> createState() => _AskJotCueSheetState();
}

class _AskJotCueSheetState extends ConsumerState<AskJotCueSheet> {
  late final TextEditingController _controller;
  late final ScrollController _scrollController;
  late AskJotCueContext _assistantContext;
  final Set<String> _runningActionIds = <String>{};
  final Set<String> _completedActionIds = <String>{};
  bool _isAnswering = false;
  final List<AskJotCueMessage> _messages = [
    const AskJotCueMessage(
      text:
          'Ask me about your current plan. Local reasoning runs first. If you explicitly enable Hybrid assistance, only unsupported questions may use the configured AI gateway, and any proposed change still requires the same local safety checks and confirmation.',
      isUser: false,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _scrollController = ScrollController();
    _assistantContext = widget.assistantContext;
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final size = MediaQuery.sizeOf(context);
    final height = (size.height * 0.86).clamp(460.0, 780.0).toDouble();
    final preferences = ref.watch(automationPreferencesProvider);
    final policy = ref.watch(automationPolicyProvider);
    final aiPreferences = widget.aiPreferences;
    final gatewayConfigured = widget.gatewayConfigured;

    return SizedBox(
      height: height,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.md,
          AppSpacing.md,
          AppSpacing.sm + bottomInset,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppColors.lavender,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Padding(
                    padding: EdgeInsets.all(9),
                    child: Icon(Icons.auto_awesome_rounded, size: 21),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Ask JotCue',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      Text(
                        aiPreferences.usesRemoteGateway && gatewayConfigured
                            ? 'Planning assistant · local first + hybrid'
                            : 'Planning assistant · on device',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  tooltip: 'Close Ask JotCue',
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            _QuickQuestions(onAsk: (value) => _submitText(value)),
            const SizedBox(height: AppSpacing.sm),
            Expanded(
              child: ListView.separated(
                key: const ValueKey('ask-jotcue-conversation'),
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                itemCount: _messages.length,
                separatorBuilder: (_, _) =>
                    const SizedBox(height: AppSpacing.xs),
                itemBuilder: (context, index) {
                  final message = _messages[index];
                  final proposal = message.actionProposal;
                  final decision = proposal == null
                      ? null
                      : policy.evaluate(
                          preferences: preferences,
                          action: _policyActionFor(proposal.kind),
                        );
                  return _MessageBubble(
                    message: message,
                    decision: decision,
                    isRunning:
                        proposal != null &&
                        _runningActionIds.contains(proposal.id),
                    isCompleted:
                        proposal != null &&
                        _completedActionIds.contains(proposal.id),
                    onApply: proposal == null
                        ? null
                        : () => _applyAction(proposal),
                  );
                },
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: TextField(
                    key: const ValueKey('ask-jotcue-field'),
                    controller: _controller,
                    minLines: 1,
                    maxLines: 3,
                    textCapitalization: TextCapitalization.sentences,
                    textInputAction: TextInputAction.send,
                    decoration: const InputDecoration(
                      hintText: 'Ask about your plan…',
                    ),
                    onSubmitted: (_) => _submit(),
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                IconButton.filled(
                  key: const ValueKey('ask-jotcue-send'),
                  onPressed: _isAnswering ? null : _submit,
                  tooltip: 'Ask JotCue',
                  icon: _isAnswering
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.arrow_upward_rounded),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              aiPreferences.usesRemoteGateway && gatewayConfigured
                  ? 'Hybrid is local-first. Remote answers are ephemeral; proposed changes still use local validation and explicit Apply.'
                  : aiPreferences.usesRemoteGateway
                  ? 'Hybrid is selected but no gateway is configured in this build; Ask JotCue remains local-only.'
                  : 'Supported changes are previewed first. Calendar writes and unsupported requests are never silently applied.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _submit() {
    _submitText(_controller.text);
  }

  Future<void> _submitText(String value) async {
    final query = value.trim();
    if (query.isEmpty || _isAnswering) return;

    final aiPreferences = widget.aiPreferences;
    setState(() {
      _isAnswering = true;
      _messages.add(AskJotCueMessage(text: query, isUser: true));
      _controller.clear();
    });
    _scrollToEnd();

    try {
      final answer = await ref
          .read(hybridAskJotCueServiceProvider)
          .answer(
            query: query,
            context: _assistantContext,
            preferences: aiPreferences,
          );
      if (!mounted) return;
      var proposal = answer.actionProposal;
      var answerText = answer.title == null
          ? answer.text
          : '${answer.title}\n${answer.text}';

      if (proposal != null) {
        final decision = ref
            .read(automationPolicyProvider)
            .evaluate(
              preferences: ref.read(automationPreferencesProvider),
              action: _policyActionFor(proposal.kind),
            );
        if (decision == AutomationDecision.observeOnly) {
          answerText =
              'Observe mode\nI understood the requested change, but Observe mode does not prepare assistant actions. Change Assistant permissions in Settings if you want JotCue to suggest or apply changes.';
          proposal = null;
        }
      }

      setState(() {
        _isAnswering = false;
        _messages.add(
          AskJotCueMessage(
            text: answerText,
            isUser: false,
            actionProposal: proposal,
            usedRemoteAi: answer.usedRemoteAi,
          ),
        );
      });
      _scrollToEnd();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isAnswering = false;
        _messages.add(
          const AskJotCueMessage(
            text:
                'I could not answer that safely right now. Nothing was changed.',
            isUser: false,
          ),
        );
      });
      _scrollToEnd();
    }
  }

  Future<void> _applyAction(AskJotCueActionProposal proposal) async {
    if (_runningActionIds.contains(proposal.id) ||
        _completedActionIds.contains(proposal.id)) {
      return;
    }
    setState(() => _runningActionIds.add(proposal.id));
    try {
      final result = await ref
          .read(askJotCueActionExecutorProvider)
          .execute(
            preferences: ref.read(automationPreferencesProvider),
            proposal: proposal,
            now: DateTime.now(),
            approved: true,
          );
      if (!mounted) return;
      setState(() {
        _runningActionIds.remove(proposal.id);
        _completedActionIds.add(proposal.id);
        _messages.add(AskJotCueMessage(text: result, isUser: false));
        _applyProposalLocally(proposal);
      });
      _scrollToEnd();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _runningActionIds.remove(proposal.id);
        _messages.add(
          AskJotCueMessage(
            text: 'I did not apply that change: $error',
            isUser: false,
          ),
        );
      });
      _scrollToEnd();
    }
  }

  void _applyProposalLocally(AskJotCueActionProposal proposal) {
    var tasks = _assistantContext.tasks;
    var blocks = _assistantContext.blocks;

    if (proposal.kind == AskJotCueActionKind.taskCompletion &&
        proposal.targetCompletion != null) {
      tasks = [
        for (final task in tasks)
          if (task.id == proposal.taskId)
            task.copyWith(isCompleted: proposal.targetCompletion!)
          else
            task,
      ];
    } else if (proposal.kind == AskJotCueActionKind.taskPriority &&
        proposal.targetPriority != null) {
      tasks = [
        for (final task in tasks)
          if (task.id == proposal.taskId)
            task.copyWith(priority: proposal.targetPriority!)
          else
            task,
      ];
    } else if (proposal.kind == AskJotCueActionKind.taskMetadata &&
        proposal.metadataUpdate != null) {
      tasks = [
        for (final task in tasks)
          if (task.id == proposal.taskId)
            _applyMetadataUpdateToTask(task, proposal.metadataUpdate!)
          else
            task,
      ];
    } else if (proposal.kind == AskJotCueActionKind.scheduleMove &&
        proposal.blockId != null &&
        proposal.toStartsAt != null &&
        proposal.toEndsAt != null) {
      blocks = [
        for (final block in blocks)
          if (block.id == proposal.blockId)
            block.copyWith(
              startsAt: proposal.toStartsAt!,
              endsAt: proposal.toEndsAt!,
              updatedAt: DateTime.now(),
            )
          else
            block,
      ];
    }

    final dependencies = const TaskDependencyAnalyzer().analyze(tasks);
    final pulse = PulseOverview.build(
      projects: _assistantContext.projects,
      tasks: tasks,
      now: _assistantContext.now,
      dependencyAnalysis: dependencies,
    );
    final dailyLoop = DailyPulseLoop.build(
      now: _assistantContext.now,
      pulse: pulse,
      blocks: blocks,
      scheduling: _assistantContext.scheduling,
      replanning: _assistantContext.replanning,
    );
    _assistantContext = _assistantContext.copyWith(
      tasks: tasks,
      blocks: blocks,
      pulse: pulse,
      dailyLoop: dailyLoop,
    );
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }
}

class _QuickQuestions extends StatelessWidget {
  const _QuickQuestions({required this.onAsk});

  final ValueChanged<String> onAsk;

  @override
  Widget build(BuildContext context) {
    const questions = [
      'What should I do now?',
      'What’s due soon?',
      'What needs attention?',
      'What can you change?',
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (var index = 0; index < questions.length; index++) ...[
            ActionChip(
              key: ValueKey('ask-jotcue-quick-$index'),
              label: Text(questions[index]),
              onPressed: () => onAsk(questions[index]),
            ),
            if (index != questions.length - 1)
              const SizedBox(width: AppSpacing.xs),
          ],
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    required this.decision,
    required this.isRunning,
    required this.isCompleted,
    this.onApply,
  });

  final AskJotCueMessage message;
  final AutomationDecision? decision;
  final bool isRunning;
  final bool isCompleted;
  final VoidCallback? onApply;

  @override
  Widget build(BuildContext context) {
    final alignment = message.isUser
        ? Alignment.centerRight
        : Alignment.centerLeft;
    final background = message.isUser
        ? Theme.of(context).colorScheme.primaryContainer
        : Theme.of(context).colorScheme.surfaceContainerHighest;
    final maxWidth = MediaQuery.sizeOf(context).width * 0.82;
    final proposal = message.actionProposal;

    return Align(
      alignment: alignment,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: 10,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (message.usedRemoteAi) ...[
                  Text(
                    'AI-assisted · ephemeral',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                ],
                Text(message.text),
                if (proposal != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  _ActionPreviewCard(
                    proposal: proposal,
                    decision: decision!,
                    isRunning: isRunning,
                    isCompleted: isCompleted,
                    onApply: onApply,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ActionPreviewCard extends StatelessWidget {
  const _ActionPreviewCard({
    required this.proposal,
    required this.decision,
    required this.isRunning,
    required this.isCompleted,
    required this.onApply,
  });

  final AskJotCueActionProposal proposal;
  final AutomationDecision decision;
  final bool isRunning;
  final bool isCompleted;
  final VoidCallback? onApply;

  @override
  Widget build(BuildContext context) {
    final canApply =
        !isRunning &&
        !isCompleted &&
        (decision == AutomationDecision.requiresApproval ||
            decision == AutomationDecision.trustedEligible);
    final status = switch (decision) {
      AutomationDecision.observeOnly => 'Observe only',
      AutomationDecision.suggestOnly => 'Suggestion only',
      AutomationDecision.requiresApproval => 'Requires your approval',
      AutomationDecision.trustedEligible =>
        'Trusted permission · still waits for this confirmation',
    };
    final buttonLabel = isCompleted
        ? 'Applied'
        : isRunning
        ? 'Applying…'
        : decision == AutomationDecision.suggestOnly
        ? 'Suggestion only'
        : 'Apply';

    return Container(
      key: ValueKey('ask-jotcue-action-${proposal.id}'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            proposal.previewTitle,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 4),
          Text(proposal.previewText),
          const SizedBox(height: 6),
          Text(
            status,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.tonal(
              key: ValueKey('ask-jotcue-apply-${proposal.id}'),
              onPressed: canApply ? onApply : null,
              child: Text(buttonLabel),
            ),
          ),
        ],
      ),
    );
  }
}

AutomationActionKind _policyActionFor(AskJotCueActionKind kind) {
  return switch (kind) {
    AskJotCueActionKind.taskCompletion =>
      AutomationActionKind.workReviewDecision,
    AskJotCueActionKind.taskPriority ||
    AskJotCueActionKind.taskMetadata => AutomationActionKind.taskPlanningUpdate,
    AskJotCueActionKind.scheduleMove => AutomationActionKind.localScheduleMove,
    AskJotCueActionKind.structuredCapture || AskJotCueActionKind.noteCreate =>
      AutomationActionKind.structuredCaptureCreate,
  };
}

Task _applyMetadataUpdateToTask(Task task, TaskMetadataUpdate update) {
  var next = task;
  if (update.clearProjectId) {
    next = next.copyWith(projectId: null);
  } else if (update.projectId != null) {
    next = next.copyWith(projectId: update.projectId);
  }

  if (update.clearDueAt) {
    next = next.copyWith(dueAt: null);
  } else if (update.dueAt != null) {
    next = next.copyWith(dueAt: update.dueAt);
  }

  if (update.priority != null) {
    next = next.copyWith(priority: update.priority);
  }

  if (update.clearEstimatedMinutes) {
    next = next.copyWith(estimatedMinutes: null);
  } else if (update.estimatedMinutes != null) {
    next = next.copyWith(estimatedMinutes: update.estimatedMinutes);
  }

  if (update.isFlexible != null) {
    next = next.copyWith(isFlexible: update.isFlexible);
  }
  if (update.dependsOnTaskIds != null) {
    next = next.copyWith(dependsOnTaskIds: update.dependsOnTaskIds);
  }
  if (update.clearWaitingFor) {
    next = next.copyWith(waitingFor: null);
  } else if (update.waitingFor != null) {
    next = next.copyWith(waitingFor: update.waitingFor);
  }
  return next;
}
