import 'dart:async';

import 'package:flutter/material.dart';
import 'package:senpwai/ui/components/anime_card/card_switcher.dart';
import 'package:senpwai/settings/settings.dart';
import 'package:senpwai/ui/pages/settings_page/settings_controls.dart';
import 'package:senpwai/ui/pages/settings_page/settings_tile.dart';

class BrowsingSettings extends StatelessWidget {
  final AppSettings settings;
  final AppSettingsNotifier notifier;
  final String? searchQuery;
  const BrowsingSettings({
    super.key,
    required this.settings,
    required this.notifier,
    this.searchQuery,
  });
  @override
  Widget build(BuildContext context) => SettingsGroupCard(
    title: 'Browsing',
    icon: Icons.explore_outlined,
    description: 'Anime layout, content visibility, and motion',
    searchQuery: searchQuery,
    searchTerms: const [
      'Card view layout poster grid landscape table list Home search results',
      'Hide anime ratings scores stars details banners',
    ],
    children: [
      SettingsTile(
        icon: Icons.dashboard_customize_outlined,
        title: 'Anime card style',
        subtitle: 'Used on Home and Search',
        keywords: 'poster landscape table grid list',
        searchQuery: searchQuery,
        trailing: CardSwitcher(
          selected: settings.appearance.cardViewMode,
          onSwitch: (mode) => unawaited(notifier.setCardViewMode(mode)),
        ),
      ),
      SettingsTile(
        icon: Icons.star_outline_rounded,
        title: 'Hide anime ratings',
        subtitle: 'Hide ratings on anime cards, banners, and details',
        keywords: 'scores stars',
        searchQuery: searchQuery,
        trailing: AsyncSwitch(
          value: settings.appearance.hideAnimeRatings,
          onChanged: notifier.setHideAnimeRatings,
        ),
      ),

      SettingsTile(
        icon: Icons.subject_rounded,
        title: 'Hide synopses by default',
        subtitle: 'Hide plot summaries on cards and details until revealed',
        searchQuery: searchQuery,
        trailing: AsyncSwitch(
          value: settings.appearance.hideSynopses,
          onChanged: notifier.setHideSynopses,
        ),
      ),
      SettingsTile(
        icon: Icons.sell_outlined,
        title: 'Show genres',
        subtitle: 'Show genre tags on cards, banners, and anime details',
        searchQuery: searchQuery,
        trailing: AsyncSwitch(
          value: settings.appearance.showGenres,
          onChanged: notifier.setShowGenres,
        ),
      ),
      SettingsTile(
        icon: Icons.translate_rounded,
        title: 'Show native title',
        subtitle: 'Show the secondary native title on anime details',
        searchQuery: searchQuery,
        trailing: AsyncSwitch(
          value: settings.appearance.showNativeTitle,
          onChanged: notifier.setShowNativeTitle,
        ),
      ),
      SettingsTile(
        icon: Icons.pause_circle_outline_rounded,
        title: 'Pause banner rotation',
        subtitle: 'Keep the home banner still; swipe or use arrows to browse',
        searchQuery: searchQuery,
        trailing: AsyncSwitch(
          value: settings.appearance.pauseBannerRotation,
          onChanged: notifier.setPauseBannerRotation,
        ),
      ),
      SettingsTile(
        icon: Icons.density_small_rounded,
        title: 'Compact cards',
        subtitle: 'Fit more anime cards on Home and Search',
        searchQuery: searchQuery,
        trailing: AsyncSwitch(
          value: settings.appearance.compactCards,
          onChanged: notifier.setCompactCards,
        ),
      ),
      SettingsTile(
        icon: Icons.animation_rounded,
        title: 'Reduce motion',
        subtitle:
            'Reduce browsing animations; system reduced motion is always respected',
        searchQuery: searchQuery,
        trailing: AsyncSwitch(
          value: settings.appearance.reduceMotion,
          onChanged: notifier.setReduceMotion,
        ),
      ),
    ],
  );
}
