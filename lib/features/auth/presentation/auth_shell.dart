import 'package:flutter/material.dart';

import '../../../core/services/app_theme.dart';
import '../../../core/widgets/jotcue_brand.dart';

class AuthShell extends StatelessWidget {
  const AuthShell({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
    this.footer,
    this.onBack,
  });

  final String title;
  final String subtitle;
  final Widget child;
  final Widget? footer;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final darkTheme = AppTheme.buildDark();
    return Theme(
      data: darkTheme,
      child: Scaffold(
        backgroundColor: AppColors.brandInk,
        body: Stack(
          children: [
            const Positioned(
              top: -180,
              right: -150,
              child: _AmbientCircle(size: 380, color: AppColors.teal),
            ),
            const Positioned(
              bottom: -220,
              left: -170,
              child: _AmbientCircle(size: 430, color: AppColors.primary),
            ),
            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 460),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            if (onBack != null) ...[
                              IconButton(
                                onPressed: onBack,
                                tooltip: 'Back',
                                icon: const Icon(Icons.arrow_back_rounded),
                              ),
                              const SizedBox(width: AppSpacing.xs),
                            ],
                            const JotCueLockup(
                              markSize: 40,
                              foregroundColor: Colors.white,
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.xl),
                        Text(
                          title,
                          style: darkTheme.textTheme.headlineMedium?.copyWith(
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          subtitle,
                          style: darkTheme.textTheme.bodyLarge?.copyWith(
                            color: Colors.white70,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        DecoratedBox(
                          decoration: BoxDecoration(
                            color: AppColors.darkPanel,
                            borderRadius: BorderRadius.circular(AppRadii.lg),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.10),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.18),
                                blurRadius: 28,
                                offset: const Offset(0, 14),
                              ),
                            ],
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(AppSpacing.lg),
                            child: child,
                          ),
                        ),
                        if (footer != null) ...[
                          const SizedBox(height: AppSpacing.md),
                          Center(child: footer),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AmbientCircle extends StatelessWidget {
  const _AmbientCircle({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color.withValues(alpha: 0.075),
        ),
      ),
    );
  }
}
