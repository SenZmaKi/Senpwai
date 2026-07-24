import 'package:flutter/material.dart';

enum SettingsCategory {
  appearance(
    'Appearance',
    Icons.palette_outlined,
    'Theme, colors & typography',
  ),
  content(
    'Content & Downloads',
    Icons.tune_rounded,
    'Media options & download folders',
  ),
  torrent(
    'BitTorrent Engine',
    Icons.hub_rounded,
    'Speeds, port, encryption & proxy',
  ),
  sources(
    'Sources & Search',
    Icons.source_rounded,
    'Providers priority & Nyaa filters',
  ),
  tracking(
    'Tracking & AniList',
    Icons.radar_rounded,
    'AniList & auto-downloader',
  ),
  system(
    'System & Storage',
    Icons.storage_rounded,
    'Notifications, cache & about',
  );

  final String title;
  final IconData icon;
  final String subtitle;

  const SettingsCategory(this.title, this.icon, this.subtitle);
}

class SettingsCategoryNav extends StatelessWidget {
  final SettingsCategory? activeCategory;
  final ValueChanged<SettingsCategory> onSelect;
  final bool isSidebar;

  const SettingsCategoryNav({
    super.key,
    this.activeCategory,
    required this.onSelect,
    this.isSidebar = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (!isSidebar) {
      return Column(
        children: SettingsCategory.values.map((cat) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: InkWell(
                onTap: () => onSelect(cat),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest.withValues(
                      alpha: 0.35,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: theme.colorScheme.outline.withValues(alpha: 0.12),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withValues(
                            alpha: 0.12,
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          cat.icon,
                          size: 22,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              cat.title,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              cat.subtitle,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurface.withValues(
                                  alpha: 0.55,
                                ),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        Icons.chevron_right_rounded,
                        size: 22,
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: SettingsCategory.values.map((cat) {
        final active = cat == activeCategory;
        return Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: InkWell(
              onTap: () => onSelect(cat),
              borderRadius: BorderRadius.circular(10),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: active
                      ? theme.colorScheme.primary.withValues(alpha: 0.15)
                      : Colors.transparent,
                  border: Border.all(
                    color: active
                        ? theme.colorScheme.primary.withValues(alpha: 0.3)
                        : Colors.transparent,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      cat.icon,
                      size: 20,
                      color: active
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            cat.title,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: active
                                  ? FontWeight.bold
                                  : FontWeight.w500,
                              color: active
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.onSurface,
                            ),
                          ),
                          Text(
                            cat.subtitle,
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontSize: 11,
                              color: theme.colorScheme.onSurface.withValues(
                                alpha: 0.5,
                              ),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
