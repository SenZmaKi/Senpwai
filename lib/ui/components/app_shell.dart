import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:senpwai/anilist/anilist.dart';
import 'package:senpwai/shared/persistence/app_image_cache.dart';
import 'package:senpwai/ui/components/anime_cover_image.dart';
import 'package:senpwai/ui/shared/responsive.dart';
import 'package:senpwai/ui/components/update_navigation_action.dart';
import 'package:senpwai/updates/updates.dart';

Widget _buildAvatarIcon(
  AnilistViewer? viewer,
  bool isAuthLoading, {
  bool compact = false,
}) {
  if (isAuthLoading) {
    return SizedBox(
      width: compact ? 20 : 24,
      height: compact ? 20 : 24,
      child: const CircularProgressIndicator(strokeWidth: 2),
    );
  }
  final avatarUrl = normalizeImageUrl(viewer?.avatarUrl);
  if (avatarUrl != null) {
    return CircleAvatar(
      radius: compact ? 10 : 12,
      backgroundImage: CachedNetworkImageProvider(
        avatarUrl,
        cacheManager: AppImageCache.manager,
      ),
    );
  }
  return Icon(Icons.login, size: compact ? 20 : 24);
}

class AppShell extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onDestinationChanged;
  final Widget body;
  final AnilistViewer? viewer;
  final bool isAuthLoading;
  final VoidCallback onAvatarTap;
  final Future<void> Function() onUpdateReady;

  const AppShell({
    super.key,
    required this.currentIndex,
    required this.onDestinationChanged,
    required this.body,
    this.viewer,
    this.isAuthLoading = false,
    required this.onAvatarTap,
    required this.onUpdateReady,
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
                onUpdateReady: onUpdateReady,
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
          : _MobileNavigationBar(
              currentIndex: currentIndex,
              destinations: _destinations,
              onDestinationChanged: onDestinationChanged,
              onUpdateReady: onUpdateReady,
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
  final Future<void> Function() onUpdateReady;

  const _DesktopRail({
    required this.currentIndex,
    required this.onDestinationChanged,
    required this.destinations,
    this.viewer,
    this.isAuthLoading = false,
    required this.onAvatarTap,
    required this.onUpdateReady,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxHeight < 500;
        final verticalSpacing = isCompact ? 6.0 : 12.0;

        return SizedBox(
          width: isCompact ? 84 : 96,
          child: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: IntrinsicHeight(
                child: Column(
                  children: [
                    SizedBox(height: verticalSpacing),
                    for (var index = 0; index < destinations.length; index++)
                      _RailTile(
                        icon: destinations[index].icon,
                        selectedIcon: destinations[index].selectedIcon,
                        label: destinations[index].label,
                        selected: currentIndex == index,
                        onTap: () => onDestinationChanged(index),
                        compact: isCompact,
                      ),
                    const Spacer(),
                    UpdateNavigationAction(
                      onReady: onUpdateReady,
                      compact: isCompact,
                    ),
                    Tooltip(
                      message: viewer == null
                          ? 'Log in to AniList'
                          : 'Open AniList profile',
                      child: _RailTile(
                        iconWidget: _buildAvatarIcon(
                          viewer,
                          isAuthLoading,
                          compact: isCompact,
                        ),
                        label: isAuthLoading
                            ? 'Loading'
                            : (viewer?.name ?? 'Login'),
                        onTap: onAvatarTap,
                        compact: isCompact,
                      ),
                    ),
                    SizedBox(height: verticalSpacing),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _MobileNavigationBar extends ConsumerWidget {
  final int currentIndex;
  final List<_Dest> destinations;
  final ValueChanged<int> onDestinationChanged;
  final Future<void> Function() onUpdateReady;

  const _MobileNavigationBar({
    required this.currentIndex,
    required this.destinations,
    required this.onDestinationChanged,
    required this.onUpdateReady,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final updateState = ref.watch(UpdateController.provider);
    return NavigationBar(
      selectedIndex: currentIndex,
      onDestinationSelected: (index) {
        if (index < destinations.length) {
          onDestinationChanged(index);
        } else {
          unawaited(handleUpdateAction(ref, updateState, onUpdateReady));
        }
      },
      destinations: [
        for (final destination in destinations)
          NavigationDestination(
            icon: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: Icon(destination.icon),
            ),
            selectedIcon: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: Icon(destination.selectedIcon),
            ),
            label: destination.label,
          ),
        if (updateState.isVisible)
          NavigationDestination(
            tooltip: updateTooltip(updateState),
            icon: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: UpdateNavigationIndicator(state: updateState),
            ),
            label: updateShortLabel(updateState),
          ),
      ],
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
  final bool compact;

  const _RailTile({
    this.icon,
    this.selectedIcon,
    this.iconWidget,
    required this.label,
    this.selected = false,
    required this.onTap,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6 : 10,
        vertical: compact ? 2 : 4,
      ),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(compact ? 10 : 12),
          child: Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(
              vertical: compact ? 5 : 8,
              horizontal: compact ? 4 : 8,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(compact ? 10 : 12),
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
                      size: compact ? 20 : 24,
                      color: selected
                          ? colorScheme.primary
                          : colorScheme.onSurface.withValues(alpha: 0.4),
                    ),
                SizedBox(height: compact ? 2 : 4),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontSize: compact ? 10 : 11,
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
