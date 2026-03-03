import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:senpwai/anilist/anilist.dart';
import 'package:senpwai/ui/shared/responsive.dart';

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

    if (vertical) {
      return Scaffold(
        body: Row(
          children: [
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
            Expanded(child: body),
          ],
        ),
      );
    }

    return Scaffold(
      body: body,
      bottomNavigationBar: NavigationBar(
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
              icon: Icon(d.icon),
              selectedIcon: Icon(d.selectedIcon),
              label: d.label,
            ),
          ),
          NavigationDestination(
            icon: _buildAvatarIcon(context),
            label: isAuthLoading
                ? 'Loading'
                : (viewer != null ? viewer!.name : 'Login'),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatarIcon(BuildContext context) {
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
    return NavigationRail(
      selectedIndex: currentIndex,
      onDestinationSelected: (index) {
        if (index == destinations.length) {
          onAvatarTap();
        } else {
          onDestinationChanged(index);
        }
      },
      labelType: NavigationRailLabelType.all,
      destinations: [
        ...destinations.map(
          (d) => NavigationRailDestination(
            icon: Icon(d.icon),
            selectedIcon: Icon(d.selectedIcon),
            label: Text(d.label),
          ),
        ),
        NavigationRailDestination(
          icon: _buildRailAvatarIcon(),
          label: Text(
            isAuthLoading
                ? 'Loading'
                : (viewer != null ? viewer!.name : 'Login'),
          ),
        ),
      ],
    );
  }

  Widget _buildRailAvatarIcon() {
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
}
