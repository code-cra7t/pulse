import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/services/app_theme.dart';
import '../../../core/widgets/pulse_components.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key, required this.onStart});

  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 960),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.lg,
                    AppSpacing.lg,
                    AppSpacing.xl,
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight - AppSpacing.xxl,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: AppColors.ink,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Icon(
                                Icons.auto_awesome_rounded,
                                color: AppColors.butter,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Text(
                              'PulseNotes',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.xl),
                        Text(
                          'Write it down.\nWe will catch the rest.',
                          style: Theme.of(context).textTheme.displaySmall,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          'Notes that become tasks. Tasks that become reminders.',
                          style: Theme.of(context).textTheme.bodyLarge
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                        ),
                        const SizedBox(height: AppSpacing.xl),
                        const _WelcomeNoteStack(),
                        const SizedBox(height: AppSpacing.xl),
                        FilledButton.icon(
                          onPressed: onStart,
                          icon: const Icon(Icons.edit_note_rounded),
                          label: const Text('Start writing'),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Center(
                          child: Text(
                            'A calm place for busy thoughts.',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _WelcomeNoteStack extends StatelessWidget {
  const _WelcomeNoteStack();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 300,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            top: 28,
            left: 8,
            right: 44,
            child: Transform.rotate(
              angle: -4 * math.pi / 180,
              child: const _DemoNote(
                color: AppColors.sky,
                label: 'Work',
                title: 'Meeting',
                body: 'Shape launch notes\nand send the recap',
                icon: Icons.groups_2_outlined,
              ),
            ),
          ),
          Positioned(
            top: 74,
            left: 54,
            right: 0,
            child: Transform.rotate(
              angle: 4 * math.pi / 180,
              child: const _DemoNote(
                color: AppColors.mint,
                label: 'Clean Up',
                title: 'Home reset',
                body: '- Clear the desk\n- Water plants',
                icon: Icons.eco_outlined,
              ),
            ),
          ),
          Positioned(
            top: 150,
            left: 18,
            right: 22,
            child: const _DemoNote(
              color: AppColors.butter,
              label: 'To-Do',
              title: 'Call Mike at 5pm',
              body: 'Smart reminder detected',
              icon: Icons.notifications_active_outlined,
            ),
          ),
        ],
      ),
    );
  }
}

class _DemoNote extends StatelessWidget {
  const _DemoNote({
    required this.color,
    required this.label,
    required this.title,
    required this.body,
    required this.icon,
  });

  final Color color;
  final String label;
  final String title;
  final String body;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      color: color,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppChip(label: label, color: Colors.white54),
                const SizedBox(height: AppSpacing.sm),
                Text(title, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: AppSpacing.xs),
                Text(body, style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: const BoxDecoration(
              color: Colors.white54,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 20),
          ),
        ],
      ),
    );
  }
}
