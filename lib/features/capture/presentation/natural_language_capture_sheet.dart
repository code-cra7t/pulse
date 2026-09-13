import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/app_theme.dart';
import '../../../core/services/firebase_providers.dart';
import '../../../core/widgets/pulse_components.dart';
import '../models/capture_draft.dart';
import '../providers/capture_providers.dart';

Future<void> showNaturalLanguageCaptureSheet({
  required BuildContext context,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => const NaturalLanguageCaptureSheet(),
  );
}

class NaturalLanguageCaptureSheet extends ConsumerStatefulWidget {
  const NaturalLanguageCaptureSheet({super.key});

  @override
  ConsumerState<NaturalLanguageCaptureSheet> createState() =>
      _NaturalLanguageCaptureSheetState();
}

class _NaturalLanguageCaptureSheetState
    extends ConsumerState<NaturalLanguageCaptureSheet> {
  late final TextEditingController _controller;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final parser = ref.watch(naturalLanguageCaptureParserProvider);
    final raw = _controller.text;
    final draft = parser.parse(raw);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md + bottomInset,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Quick capture',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Write it naturally. Review before JotCue creates anything.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: _saving ? null : () => Navigator.of(context).pop(),
                  tooltip: 'Close capture',
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              key: const ValueKey('natural-language-capture-field'),
              controller: _controller,
              enabled: !_saving,
              minLines: 3,
              maxLines: 6,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                hintText:
                    'e.g. Life insurance exam Oct 2. Revise 8 chapters and do two mock exams.',
                alignLabelWithHint: true,
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: AppSpacing.md),
            if (raw.trim().isEmpty)
              const _CaptureHelp()
            else if (draft == null)
              const _UnstructuredPreview()
            else
              _StructuredPreview(draft: draft),
            const SizedBox(height: AppSpacing.lg),
            if (draft != null)
              FilledButton.icon(
                key: const ValueKey('confirm-structured-capture'),
                onPressed: _saving ? null : () => _saveStructured(draft),
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.auto_awesome_motion_outlined),
                label: Text(_structuredActionLabel(draft)),
              ),
            if (raw.trim().isNotEmpty) ...[
              if (draft != null) const SizedBox(height: AppSpacing.xs),
              OutlinedButton.icon(
                key: const ValueKey('save-capture-as-note'),
                onPressed: _saving ? null : _saveAsNote,
                icon: const Icon(Icons.note_add_outlined),
                label: const Text('Save as note instead'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _saveStructured(CaptureDraft draft) async {
    final user = ref.read(firebaseAuthProvider).currentUser;
    if (user == null) {
      _showMessage('Sign in before creating a structured capture.');
      return;
    }
    setState(() => _saving = true);
    try {
      final result = await ref
          .read(captureServiceProvider)
          .createStructured(userId: user.uid, draft: draft);
      if (!mounted) {
        return;
      }
      final projectCreated = result.projectId != null;
      final message = projectCreated
          ? result.taskCount == 0
                ? 'Project created.'
                : 'Project created with ${result.taskCount} ${result.taskCount == 1 ? 'task' : 'tasks'}.'
          : '${result.taskCount} ${result.taskCount == 1 ? 'task' : 'tasks'} captured.';
      _finish(message);
    } catch (error) {
      if (mounted) {
        _showMessage('Could not create capture: $error');
      }
    } finally {
      if (mounted && _saving) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _saveAsNote() async {
    final user = ref.read(firebaseAuthProvider).currentUser;
    if (user == null) {
      _showMessage('Sign in before saving a capture.');
      return;
    }
    setState(() => _saving = true);
    try {
      await ref
          .read(captureServiceProvider)
          .saveAsNote(userId: user.uid, rawText: _controller.text);
      if (!mounted) {
        return;
      }
      _finish('Capture saved as a note.');
    } catch (error) {
      if (mounted) {
        _showMessage('Could not save capture: $error');
      }
    } finally {
      if (mounted && _saving) {
        setState(() => _saving = false);
      }
    }
  }

  String _structuredActionLabel(CaptureDraft draft) {
    return switch (draft.kind) {
      CaptureDraftKind.project =>
        draft.tasks.isEmpty ? 'Create project' : 'Create project + tasks',
      CaptureDraftKind.task => 'Create task',
      CaptureDraftKind.taskList => 'Create ${draft.tasks.length} tasks',
    };
  }

  void _finish(String message) {
    if (_saving) {
      setState(() => _saving = false);
    }
    final messenger = ScaffoldMessenger.maybeOf(context);
    Navigator.of(context).pop();
    messenger?.showSnackBar(SnackBar(content: Text(message)));
  }

  void _showMessage(String message) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.showSnackBar(SnackBar(content: Text(message)));
  }
}

class _CaptureHelp extends StatelessWidget {
  const _CaptureHelp();

  @override
  Widget build(BuildContext context) {
    return AppCard(
      color: AppColors.sky,
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: Text(
        'Try a clear deadline and action: “Submit HPC report by Sep 30” or “Visualization oral exam Oct 8. Review lectures and practise questions.”',
        style: Theme.of(context).textTheme.bodySmall,
      ),
    );
  }
}

class _UnstructuredPreview extends StatelessWidget {
  const _UnstructuredPreview();

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.edit_note_rounded),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Keep this as a note',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 3),
                Text(
                  'JotCue could not safely infer a task or project. It will not guess.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StructuredPreview extends StatelessWidget {
  const _StructuredPreview({required this.draft});

  final CaptureDraft draft;

  @override
  Widget build(BuildContext context) {
    final kindLabel = switch (draft.kind) {
      CaptureDraftKind.project => 'Project',
      CaptureDraftKind.task => 'Task',
      CaptureDraftKind.taskList => 'Task list',
    };

    return AppCard(
      key: const ValueKey('structured-capture-preview'),
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome_outlined, size: 20),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  'JotCue found a $kindLabel',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
            ],
          ),
          if (draft.projectName != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              draft.projectName!,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
          if (draft.deadline != null) ...[
            const SizedBox(height: AppSpacing.xs),
            _MetaRow(
              icon: Icons.event_outlined,
              text: 'Deadline ${_formatDate(draft.deadline!)}',
            ),
          ],
          if (draft.tasks.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            ...draft.tasks.map(
              (task) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 2),
                      child: Icon(Icons.check_box_outline_blank, size: 17),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(child: Text(task)),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Nothing is created until you confirm.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 17),
        const SizedBox(width: 6),
        Expanded(child: Text(text)),
      ],
    );
  }
}

String _formatDate(DateTime date) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${months[date.month - 1]} ${date.day}, ${date.year}';
}
