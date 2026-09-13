import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/app_theme.dart';
import '../models/ask_jotcue.dart';
import '../providers/assistant_providers.dart';

Future<void> showAskJotCueSheet({
  required BuildContext context,
  required AskJotCueContext assistantContext,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => AskJotCueSheet(assistantContext: assistantContext),
  );
}

class AskJotCueSheet extends ConsumerStatefulWidget {
  const AskJotCueSheet({super.key, required this.assistantContext});

  final AskJotCueContext assistantContext;

  @override
  ConsumerState<AskJotCueSheet> createState() => _AskJotCueSheetState();
}

class _AskJotCueSheetState extends ConsumerState<AskJotCueSheet> {
  late final TextEditingController _controller;
  late final ScrollController _scrollController;
  final List<AskJotCueMessage> _messages = [
    const AskJotCueMessage(
      text:
          'Ask me about your current plan. I can explain focus, deadlines, free time, scheduled work, active projects, and anything JotCue thinks needs review.',
      isUser: false,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _scrollController = ScrollController();
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
                        'Read-only planning assistant · on device',
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
            _QuickQuestions(onAsk: _submitText),
            const SizedBox(height: AppSpacing.sm),
            Expanded(
              child: ListView.separated(
                key: const ValueKey('ask-jotcue-conversation'),
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                itemCount: _messages.length,
                separatorBuilder: (_, _) =>
                    const SizedBox(height: AppSpacing.xs),
                itemBuilder: (context, index) =>
                    _MessageBubble(message: _messages[index]),
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
                  onPressed: _submit,
                  tooltip: 'Ask JotCue',
                  icon: const Icon(Icons.arrow_upward_rounded),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Ask JotCue does not change tasks, projects, schedules, or calendars in this version.',
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

  void _submitText(String value) {
    final query = value.trim();
    if (query.isEmpty) return;

    final answer = ref
        .read(askJotCueEngineProvider)
        .answer(query: query, context: widget.assistantContext);
    setState(() {
      _messages
        ..add(AskJotCueMessage(text: query, isUser: true))
        ..add(
          AskJotCueMessage(
            text: answer.title == null
                ? answer.text
                : '${answer.title}\n${answer.text}',
            isUser: false,
          ),
        );
      _controller.clear();
    });
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
      'How much time do I have today?',
      'What needs attention?',
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
  const _MessageBubble({required this.message});

  final AskJotCueMessage message;

  @override
  Widget build(BuildContext context) {
    final alignment = message.isUser
        ? Alignment.centerRight
        : Alignment.centerLeft;
    final background = message.isUser
        ? Theme.of(context).colorScheme.primaryContainer
        : Theme.of(context).colorScheme.surfaceContainerHighest;
    final maxWidth = MediaQuery.sizeOf(context).width * 0.82;

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
            child: Text(message.text),
          ),
        ),
      ),
    );
  }
}
