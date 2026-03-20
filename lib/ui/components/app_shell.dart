import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:senpwai/anilist/anilist.dart';
import 'package:senpwai/ui/shared/responsive.dart';

Widget _buildAvatarIcon(AnilistViewer? viewer, bool isAuthLoading) {
  if (isAuthLoading) {
    return const SizedBox(
      width: 24,
      height: 24,
      child: CircularProgressIndicator(strokeWidth: 2),
    );
  }
  if (viewer?.avatarUrl != null) {
    return CircleAvatar(
      radius: 12,
      backgroundImage: CachedNetworkImageProvider(viewer!.avatarUrl!),
    );
  }
  return const Icon(Icons.login);
}

class AppShell extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onDestinationChanged;
  final Widget body;
  final AnilistViewer? viewer;
  final bool isAuthLoading;
  final VoidCallback onAvatarTap;

  const AppShell({
    super.key,
    required this.currentIndex,
    required this.onDestinationChanged,
    required this.body,
    this.viewer,
    this.isAuthLoading = false,
    required this.onAvatarTap,
  });

  static const _destinations = [
    _Dest(icon: Icons.home_outlined, selectedIcon: Icons.home, label: 'Home'),
    _Dest(
      icon: Icons.search_outlined,
      selectedIcon: Icons.search,
      label: 'Search',
    ),
    _Dest(
      icon: Icons.download_outlined,
      selectedIcon: Icons.download,
      label: 'Downloads',
    ),
    _Dest(
      icon: Icons.settings_outlined,
      selectedIcon: Icons.settings,
      label: 'Settings',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final vertical = useVerticalNav(context);
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        bottom: vertical,
        child: Row(
          children: [
            if (vertical) ...[
              _DesktopRail(
                currentIndex: currentIndex,
                onDestinationChanged: onDestinationChanged,
                destinations: _destinations,
                viewer: viewer,
                isAuthLoading: isAuthLoading,
                onAvatarTap: onAvatarTap,
              ),
              VerticalDivider(
                width: 1,
                thickness: 1,
                color: theme.dividerTheme.color ?? theme.dividerColor,
              ),
            ],
            Expanded(key: const ValueKey('shell-body'), child: body),
          ],
        ),
      ),
      bottomNavigationBar: vertical
          ? null
          : NavigationBar(
              selectedIndex: currentIndex,
              onDestinationSelected: (index) {
                if (index == _destinations.length) {
                  onAvatarTap();
                } else {
                  onDestinationChanged(index);
                }
              },
              destinations: [
                ..._destinations.map(
                  (d) => NavigationDestination(
                    icon: MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: Icon(d.icon),
                    ),
                    selectedIcon: MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: Icon(d.selectedIcon),
                    ),
                    label: d.label,
                  ),
                ),
                NavigationDestination(
                  icon: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: _buildAvatarIcon(viewer, isAuthLoading),
                  ),
                  label: isAuthLoading
                      ? 'Loading'
                      : (viewer != null ? viewer!.name : 'Login'),
                ),
              ],
            ),
    );
  }
}

class _Dest {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  const _Dest({
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });
}

class _DesktopRail extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onDestinationChanged;
  final List<_Dest> destinations;
  final AnilistViewer? viewer;
  final bool isAuthLoading;
  final VoidCallback onAvatarTap;

  const _DesktopRail({
    required this.currentIndex,
    required this.onDestinationChanged,
    required this.destinations,
    this.viewer,
    this.isAuthLoading = false,
    required this.onAvatarTap,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SizedBox(
        width: 96,
        child: Column(
          children: [
            const SizedBox(height: 12),
            for (var index = 0; index < destinations.length; index++)
              _RailTile(
                icon: destinations[index].icon,
                selectedIcon: destinations[index].selectedIcon,
                label: destinations[index].label,
                selected: currentIndex == index,
                onTap: () => onDestinationChanged(index),
              ),
            const Spacer(),
            _RailTile(
              iconWidget: _buildAvatarIcon(viewer, isAuthLoading),
              label: isAuthLoading
                  ? 'Loading'
                  : (viewer != null ? viewer!.name : 'Login'),
              onTap: onAvatarTap,
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

class _RailTile extends StatelessWidget {
  final IconData? icon;
  final IconData? selectedIcon;
  final Widget? iconWidget;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _RailTile({
    this.icon,
    this.selectedIcon,
    this.iconWidget,
    required this.label,
    this.selected = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: selected
                  ? colorScheme.primary.withValues(alpha: 0.15)
                  : Colors.transparent,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                iconWidget ??
                    Icon(
                      selected ? selectedIcon! : icon!,
                      color: selected
                          ? colorScheme.primary
                          : colorScheme.onSurface.withValues(alpha: 0.4),
                    ),
                const SizedBox(height: 4),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontSize: 11,
                    color: selected
                        ? colorScheme.primary
                        : colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
