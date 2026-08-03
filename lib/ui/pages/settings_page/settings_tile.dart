import 'package:flutter/material.dart';
import 'package:senpwai/ui/pages/settings_page/settings_search.dart';
import 'package:senpwai/ui/shared/theme/theme.dart';

class SettingsSectionTitle extends StatelessWidget {
  final String title;
  final IconData icon;
  final String? description;

  const SettingsSectionTitle({
    super.key,
    required this.title,
    required this.icon,
    this.description,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 20, color: theme.colorScheme.primary),
            const SizedBox(width: 10),
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
          ],
        ),
        if (description != null) ...[
          const SizedBox(height: 4),
          Text(
            description!,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ],
      ],
    );
  }
}

class SettingsGroupCard extends StatelessWidget implements SettingsSearchable {
  final String? title;
  final IconData? icon;
  final String? description;
  final Widget? headerTrailing;
  final List<Widget> children;
  final List<String> searchTerms;
  final String? searchQuery;

  const SettingsGroupCard({
    super.key,
    this.title,
    this.icon,
    this.description,
    this.headerTrailing,
    required this.children,
    this.searchTerms = const [],
    this.searchQuery,
  });

  bool _matchesSelf(String? query) => settingsSearchMatches(query, [
    if (title != null) title!,
    if (description != null) description!,
  ]);

  @override
  bool matchesSearch(String? query) {
    if (_matchesSelf(query) || settingsSearchMatches(query, searchTerms)) {
      return true;
    }
    for (final child in children) {
      if (child case final SettingsSearchable searchable) {
        if (searchable.matchesSearch(query)) return true;
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ext = theme.extension<SenpwaiThemeExtension>();
    final radius = ext?.cardRadius ?? 12.0;

    final hasQuery = searchQuery?.trim().isNotEmpty ?? false;
    final cardMatchesSelf = _matchesSelf(searchQuery);
    final searchTermsMatch = settingsSearchMatches(searchQuery, searchTerms);

    if (hasQuery && !matchesSearch(searchQuery)) {
      return const SizedBox.shrink();
    }

    final visibleChildren = <Widget>[];
    for (final child in children) {
      final childMatches = switch (child) {
        final SettingsSearchable searchable => searchable.matchesSearch(
          searchQuery,
        ),
        _ => false,
      };
      if (!hasQuery ||
          cardMatchesSelf ||
          (searchTermsMatch && child is! SettingsSearchable) ||
          childMatches) {
        visibleChildren.add(child);
      }
    }

    if (visibleChildren.isEmpty) {
      return const SizedBox.shrink();
    }

    return _SettingsSearchScope(
      showAllChildren: hasQuery && cardMatchesSelf,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withValues(
            alpha: 0.35,
          ),
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(
            color: theme.colorScheme.outline.withValues(alpha: 0.12),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (title != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                child: Row(
                  children: [
                    if (icon != null) ...[
                      Icon(icon, size: 18, color: theme.colorScheme.primary),
                      const SizedBox(width: 8),
                    ],
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title!,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.2,
                            ),
                          ),
                          if (description != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              description!,
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontSize: 11,
                                color: theme.colorScheme.onSurface.withValues(
                                  alpha: 0.55,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (headerTrailing != null) headerTrailing!,
                  ],
                ),
              ),
            if (title != null && visibleChildren.isNotEmpty)
              Divider(
                height: 1,
                thickness: 1,
                color: theme.colorScheme.outline.withValues(alpha: 0.08),
              ),
            for (var i = 0; i < visibleChildren.length; i++) ...[
              visibleChildren[i],
              if (i < visibleChildren.length - 1)
                Divider(
                  height: 1,
                  indent: 48,
                  thickness: 1,
                  color: theme.colorScheme.outline.withValues(alpha: 0.06),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class SettingsTile extends StatelessWidget implements SettingsSearchable {
  final IconData icon;
  final String title;
  final String subtitle;
  final String? keywords;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool enabled;
  final String? searchQuery;

  const SettingsTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.keywords,
    this.trailing,
    this.onTap,
    this.enabled = true,
    this.searchQuery,
  });

  @override
  bool matchesSearch(String? query) {
    return settingsSearchMatches(query, [
      title,
      subtitle,
      if (keywords != null) keywords!,
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final effectiveQuery =
        _SettingsSearchScope.maybeOf(context)?.showAllChildren ?? false
        ? null
        : searchQuery;
    if (!matchesSearch(effectiveQuery)) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 460;

        Widget buildTileContent() {
          if (isCompact && trailing != null) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Icon(
                          icon,
                          size: 20,
                          color: enabled
                              ? theme.colorScheme.onSurface.withValues(
                                  alpha: 0.7,
                                )
                              : theme.colorScheme.onSurface.withValues(
                                  alpha: 0.35,
                                ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              subtitle,
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
                    ],
                  ),
                  const SizedBox(height: 10),
                  Align(alignment: Alignment.centerRight, child: trailing!),
                ],
              ),
            );
          }

          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: enabled
                      ? theme.colorScheme.onSurface.withValues(alpha: 0.7)
                      : theme.colorScheme.onSurface.withValues(alpha: 0.35),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
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
                if (trailing != null) ...[const SizedBox(width: 12), trailing!],
              ],
            ),
          );
        }

        final content = Opacity(
          opacity: enabled ? 1.0 : 0.45,
          child: buildTileContent(),
        );

        return MouseRegion(
          cursor: enabled && onTap != null
              ? SystemMouseCursors.click
              : SystemMouseCursors.basic,
          child: InkWell(onTap: enabled ? onTap : null, child: content),
        );
      },
    );
  }
}

class _SettingsSearchScope extends InheritedWidget {
  final bool showAllChildren;

  const _SettingsSearchScope({
    required this.showAllChildren,
    required super.child,
  });

  static _SettingsSearchScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_SettingsSearchScope>();

  @override
  bool updateShouldNotify(_SettingsSearchScope oldWidget) =>
      showAllChildren != oldWidget.showAllChildren;
}
