import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/services/app_theme.dart';
import '../../../core/widgets/jotcue_brand.dart';
import '../../../core/widgets/pulse_components.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({
    super.key,
    required this.onStart,
    required this.onSignIn,
  });

  final VoidCallback onStart;
  final VoidCallback onSignIn;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.brandInk,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 760;
            final horizontalPadding = isWide ? AppSpacing.xxl : AppSpacing.lg;
            final availableHeight = math.max(0.0, constraints.maxHeight - 48);
            final content = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const JotCueLockup(markSize: 44, foregroundColor: Colors.white),
                if (isWide)
                  const Spacer()
                else
                  const SizedBox(height: AppSpacing.xl),
                if (isWide)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: _WelcomeCopy(onStart: onStart, showAction: true),
                      ),
                      const SizedBox(width: AppSpacing.xxl),
                      const Expanded(child: _WelcomeNoteStack()),
                    ],
                  )
                else ...[
                  _WelcomeCopy(onStart: onStart, showAction: false),
                  const SizedBox(height: AppSpacing.xl),
                  const _WelcomeNoteStack(),
                  const SizedBox(height: AppSpacing.lg),
                  _StartButton(onPressed: onStart),
                ],
                if (isWide)
                  const Spacer(flex: 2)
                else
                  const SizedBox(height: AppSpacing.lg),
                Center(
                  child: TextButton(
                    onPressed: onSignIn,
                    style: TextButton.styleFrom(foregroundColor: Colors.white),
                    child: const Text('I already have an account'),
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Center(
                  child: Text(
                    'A calm place for busy thoughts.',
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: Colors.white60),
                  ),
                ),
              ],
            );

            return SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                horizontalPadding,
                AppSpacing.lg,
                horizontalPadding,
                AppSpacing.lg,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1040),
                  child: isWide
                      ? SizedBox(height: availableHeight, child: content)
                      : ConstrainedBox(
                          constraints: BoxConstraints(
                            minHeight: availableHeight,
                          ),
                          child: content,
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

class _WelcomeCopy extends StatelessWidget {
  const _WelcomeCopy({required this.onStart, required this.showAction});

  final VoidCallback onStart;
  final bool showAction;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Write it down.\nWe’ll cue the rest.',
          style: Theme.of(
            context,
          ).textTheme.displaySmall?.copyWith(color: Colors.white, fontSize: 42),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          'Notes that become tasks. Tasks that become reminders.',
          style: Theme.of(
            context,
          ).textTheme.bodyLarge?.copyWith(color: Colors.white70),
        ),
        if (showAction) ...[
          const SizedBox(height: AppSpacing.xl),
          _StartButton(onPressed: onStart),
        ],
      ],
    );
  }
}

class _StartButton extends StatelessWidget {
  const _StartButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 360),
      child: FilledButton.icon(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
        ),
        icon: const Icon(Icons.edit_note_rounded),
        label: const Text('Start writing'),
      ),
    );
  }
}

class _WelcomeNoteStack extends StatelessWidget {
  const _WelcomeNoteStack();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 330,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            top: 18,
            left: 8,
            right: 44,
            child: Transform.rotate(
              angle: -4 * math.pi / 180,
              child: const _DemoNote(
                color: AppColors.sky,
                label: 'Work',
                title: 'Meeting notes',
                body: 'Shape launch notes\nand send the recap',
                icon: Icons.groups_2_outlined,
              ),
            ),
          ),
          Positioned(
            top: 86,
            left: 52,
            right: 0,
            child: Transform.rotate(
              angle: 4 * math.pi / 180,
              child: const _DemoNote(
                color: AppColors.mint,
                label: 'Clean Up',
                title: 'Home reset',
                body: '☐ Clear the desk\n☐ Water plants',
                icon: Icons.eco_outlined,
              ),
            ),
          ),
          Positioned(
            top: 174,
            left: 18,
            right: 22,
            child: const _DemoNote(
              color: AppColors.butter,
              label: 'To-Do',
              title: 'Call Mike at 5pm',
              body: 'Task created  →\nReminder · 5:00 PM',
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
                Text(
                  title,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(color: AppColors.ink),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  body,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: AppColors.ink),
                ),
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
