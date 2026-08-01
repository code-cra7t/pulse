import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/app_theme.dart';
import 'pulse_components.dart';

class AdaptiveShell extends StatelessWidget {
  const AdaptiveShell({
    super.key,
    required this.body,
    required this.selectedIndex,
    required this.onDestinationSelected,
    this.desktopList,
    this.desktopEditor,
    this.onCreate,
    this.profileName,
    this.profileSubtitle,
    this.onProfileTap,
  });

  static const double tabletBreakpoint = 700;
  static const double desktopBreakpoint = 1100;

  final Widget body;
  final Widget? desktopList;
  final Widget? desktopEditor;
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final VoidCallback? onCreate;
  final String? profileName;
  final String? profileSubtitle;
  final VoidCallback? onProfileTap;

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyN, control: true):
            ?onCreate,
      },
      child: Focus(
        autofocus: true,
        child: LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth >= desktopBreakpoint) {
              return _buildDesktop(context, constraints.maxWidth);
            }
            if (constraints.maxWidth >= tabletBreakpoint) {
              return _buildTablet(context);
            }
            return _buildMobile();
          },
        ),
      ),
    );
  }

  Widget _buildMobile() {
    return Scaffold(
      extendBody: true,
      body: body,
      bottomNavigationBar: onCreate == null
          ? null
          : FloatingBottomNav(
              selectedIndex: selectedIndex,
              onDestinationSelected: onDestinationSelected,
              onCreate: onCreate!,
            ),
    );
  }

  Widget _buildTablet(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvasFor(context),
      body: SafeArea(
        child: Row(
          children: [
            _DesktopSidebar(
              compact: true,
              selectedIndex: selectedIndex,
              onDestinationSelected: onDestinationSelected,
              onCreate: onCreate,
              profileName: profileName,
              profileSubtitle: profileSubtitle,
              onProfileTap: onProfileTap,
            ),
            Expanded(child: body),
          ],
        ),
      ),
    );
  }

  Widget _buildDesktop(BuildContext context, double availableWidth) {
    final notesPanelWidth = switch (availableWidth) {
      >= 1500 => 420.0,
      >= 1250 => 390.0,
      _ => 350.0,
    };
    return Scaffold(
      backgroundColor: AppColors.canvasFor(context),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _DesktopSidebar(
                selectedIndex: selectedIndex,
                onDestinationSelected: onDestinationSelected,
                onCreate: onCreate,
                profileName: profileName,
                profileSubtitle: profileSubtitle,
                onProfileTap: onProfileTap,
              ),
              const SizedBox(width: AppSpacing.sm),
              SizedBox(
                width: notesPanelWidth,
                child: _WorkspacePanel(child: desktopList ?? body),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _WorkspacePanel(
                  child: desktopEditor ?? const SizedBox.shrink(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WorkspacePanel extends StatelessWidget {
  const _WorkspacePanel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final background = AppColors.panelFor(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(color: AppColors.panelBorderFor(context)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: Theme.of(context).brightness == Brightness.dark
                  ? 0.18
                  : 0.035,
            ),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadii.lg),
        child: ColoredBox(color: background, child: child),
      ),
    );
  }
}

class _DesktopSidebar extends StatelessWidget {
  const _DesktopSidebar({
    required this.selectedIndex,
    required this.onDestinationSelected,
    this.compact = false,
    this.onCreate,
    this.profileName,
    this.profileSubtitle,
    this.onProfileTap,
  });

  final bool compact;
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final VoidCallback? onCreate;
  final String? profileName;
  final String? profileSubtitle;
  final VoidCallback? onProfileTap;

  static const _destinations = <(IconData, String)>[
    (Icons.note_alt_rounded, 'Notes'),
    (Icons.light_mode_outlined, 'Today'),
    (Icons.notifications_none_rounded, 'Reminders'),
    (Icons.settings_outlined, 'Settings'),
  ];

  @override
  Widget build(BuildContext context) {
    final logoBackground = Theme.of(context).brightness == Brightness.dark
        ? AppColors.primary.withValues(alpha: 0.24)
        : AppColors.primarySoft;
    final width = compact ? 84.0 : 200.0;
    return SizedBox(
      width: width,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? AppSpacing.xs : AppSpacing.sm,
          vertical: AppSpacing.sm,
        ),
        child: Column(
          crossAxisAlignment: compact
              ? CrossAxisAlignment.center
              : CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: logoBackground,
                      borderRadius: BorderRadius.circular(AppRadii.sm),
                    ),
                    child: const Icon(
                      Icons.auto_awesome_rounded,
                      color: AppColors.primary,
                      size: 20,
                    ),
                  ),
                  if (!compact) ...[
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: Text(
                        'PulseNotes',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            for (var index = 0; index < _destinations.length; index++) ...[
              _SidebarDestination(
                compact: compact,
                icon: _destinations[index].$1,
                label: _destinations[index].$2,
                selected: selectedIndex == index,
                onTap: () => onDestinationSelected(index),
              ),
              const SizedBox(height: AppSpacing.xs),
            ],
            const SizedBox(height: AppSpacing.md),
            if (onCreate != null)
              compact
                  ? IconButton.filled(
                      onPressed: onCreate,
                      icon: const Icon(Icons.add_rounded),
                      tooltip: 'New note (Ctrl+N)',
                    )
                  : SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: onCreate,
                        icon: const Icon(Icons.add_rounded),
                        label: const Text('New note'),
                      ),
                    ),
            const Spacer(),
            if (profileName != null)
              _ProfileTile(
                compact: compact,
                name: profileName!,
                subtitle: profileSubtitle,
                onTap: onProfileTap,
              ),
          ],
        ),
      ),
    );
  }
}

class _SidebarDestination extends StatelessWidget {
  const _SidebarDestination({
    required this.compact,
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final bool compact;
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final background = selected ? AppColors.sidebarActive : Colors.transparent;
    final foreground = selected
        ? AppColors.textFor(AppColors.sidebarActive)
        : Theme.of(context).colorScheme.onSurface;

    return Tooltip(
      message: compact ? label : '',
      child: Material(
        color: background,
        borderRadius: BorderRadius.circular(AppRadii.md),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadii.md),
          child: SizedBox(
            height: 50,
            child: Row(
              mainAxisAlignment: compact
                  ? MainAxisAlignment.center
                  : MainAxisAlignment.start,
              children: [
                if (!compact) const SizedBox(width: AppSpacing.sm),
                Icon(icon, color: foreground, size: 21),
                if (!compact) ...[
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(
                        context,
                      ).textTheme.titleMedium?.copyWith(color: foreground),
                    ),
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

class _ProfileTile extends StatelessWidget {
  const _ProfileTile({
    required this.compact,
    required this.name,
    this.subtitle,
    this.onTap,
  });

  final bool compact;
  final String name;
  final String? subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final initial = name.trim().isEmpty ? 'P' : name.trim()[0].toUpperCase();
    final avatarForeground = AppColors.textFor(AppColors.lavender);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadii.md),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xs),
        child: Row(
          mainAxisAlignment: compact
              ? MainAxisAlignment.center
              : MainAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: AppColors.lavender,
              child: Text(
                initial,
                style: TextStyle(
                  color: avatarForeground,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (!compact) ...[
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                  ],
                ),
              ),
              const Icon(Icons.more_horiz_rounded, size: 18),
            ],
          ],
        ),
      ),
    );
  }
}
