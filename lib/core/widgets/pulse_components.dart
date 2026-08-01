import 'package:flutter/material.dart';

import '../services/app_theme.dart';

class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.color,
    this.padding = const EdgeInsets.all(AppSpacing.md),
    this.onTap,
    this.borderColor,
  });

  final Widget child;
  final Color? color;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final background = color ?? Theme.of(context).colorScheme.surface;
    final foreground = AppColors.textFor(background);
    final mutedForeground = AppColors.mutedTextFor(background);
    final inheritedTextTheme = Theme.of(context).textTheme;

    return Material(
      color: background,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.lg),
        side: BorderSide(color: borderColor ?? Colors.transparent, width: 2),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: IconTheme.merge(
          data: IconThemeData(color: foreground),
          child: DefaultTextStyle.merge(
            style: inheritedTextTheme.bodyMedium?.copyWith(color: foreground),
            child: Theme(
              data: Theme.of(context).copyWith(
                textTheme: inheritedTextTheme
                    .apply(bodyColor: foreground, displayColor: foreground)
                    .copyWith(
                      bodySmall: inheritedTextTheme.bodySmall?.copyWith(
                        color: mutedForeground,
                      ),
                      titleSmall: inheritedTextTheme.titleSmall?.copyWith(
                        color: mutedForeground,
                      ),
                    ),
              ),
              child: Padding(padding: padding, child: child),
            ),
          ),
        ),
      ),
    );
  }
}

class AppChip extends StatelessWidget {
  const AppChip({
    super.key,
    required this.label,
    this.icon,
    this.selected = false,
    this.onTap,
    this.color,
  });

  final String label;
  final IconData? icon;
  final bool selected;
  final VoidCallback? onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final background = selected
        ? color ?? AppColors.ink
        : color?.withValues(alpha: 0.72) ??
              Theme.of(context).colorScheme.surface;
    final foreground = AppColors.textFor(background);

    return Material(
      color: background,
      shape: const StadiumBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 16, color: foreground),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: foreground,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              if (subtitle != null) ...[
                const SizedBox(height: 3),
                Text(subtitle!, style: Theme.of(context).textTheme.bodySmall),
              ],
            ],
          ),
        ),
        ?trailing,
      ],
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.icon = Icons.note_alt_outlined,
  });

  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(
                color: AppColors.butter,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 32, color: AppColors.ink),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(title, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: AppSpacing.xs),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: AppSpacing.lg),
              FilledButton.tonal(
                onPressed: onAction,
                child: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class FloatingBottomNav extends StatelessWidget {
  const FloatingBottomNav({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.onCreate,
  });

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(18, 0, 18, 12),
      child: SizedBox(
        height: 76,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned.fill(
                  top: 10,
                  child: Material(
                    elevation: 10,
                    shadowColor: Colors.black.withValues(alpha: 0.13),
                    color: AppColors.ink,
                    borderRadius: BorderRadius.circular(28),
                    child: Row(
                      children: [
                        Expanded(
                          child: _NavItem(
                            icon: Icons.note_alt_rounded,
                            label: 'Notes',
                            selected: selectedIndex == 0,
                            onTap: () => onDestinationSelected(0),
                          ),
                        ),
                        Expanded(
                          child: _NavItem(
                            icon: Icons.light_mode_outlined,
                            label: 'Today',
                            selected: selectedIndex == 1,
                            onTap: () => onDestinationSelected(1),
                          ),
                        ),
                        const SizedBox(width: 72),
                        Expanded(
                          child: _NavItem(
                            icon: Icons.notifications_none_rounded,
                            label: 'Reminders',
                            selected: selectedIndex == 2,
                            onTap: () => onDestinationSelected(2),
                          ),
                        ),
                        Expanded(
                          child: _NavItem(
                            icon: Icons.settings_outlined,
                            label: 'Settings',
                            selected: selectedIndex == 3,
                            onTap: () => onDestinationSelected(3),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  top: 0,
                  child: Semantics(
                    button: true,
                    label: 'Create note',
                    child: Material(
                      elevation: 8,
                      color: AppColors.primary,
                      shape: const CircleBorder(),
                      child: InkWell(
                        onTap: onCreate,
                        customBorder: const CircleBorder(),
                        child: const SizedBox(
                          width: 64,
                          height: 64,
                          child: Icon(
                            Icons.add_rounded,
                            color: Colors.white,
                            size: 32,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.butter : Colors.white60;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 22, color: color),
          const SizedBox(height: 2),
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}
