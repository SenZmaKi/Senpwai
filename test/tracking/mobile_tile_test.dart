import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:senpwai/anilist/models.dart';
import 'package:senpwai/downloads/models.dart';
import 'package:senpwai/sources/shared/shared.dart';
import 'package:senpwai/tracking/models.dart';
import 'package:senpwai/tracking/notifier.dart';
import 'package:senpwai/ui/shared/theme/theme.dart';
import 'package:senpwai/ui/pages/settings_page/tracked_anime_tile.dart';

import '../support/support.dart';

void main() {
  final appTheme = SenpwaiThemePreset.defaultTheme.toTheme();
  final colors = appTheme.colors.dark;
  final theme = ThemeData.dark().copyWith(
    extensions: [
      SenpwaiThemeExtension(
        cardRadius: appTheme.shape.cardRadius,
        cardBorderColor: colors.surfaceVariant,
        cardBorderWidth: appTheme.shape.cardBorderWidth,
        cardShadows: const [],
        shimmerBase: colors.surface,
        shimmerHighlight: colors.surfaceVariant,
        randomColourPalette: colors.randomColors,
        imageOverlay: colors.imageOverlay,
        onImageOverlay: colors.onImageOverlay,
        textShadow: colors.textShadow,
        downloadColors: SenpwaiDownloadColors.deriveFrom(colors),
      ),
    ],
  );
  setUpAll(() async {
    final originalDebugPrint = debugPrint;
    await setupTestApp();
    debugPrint = originalDebugPrint;
  });
  for (final width in [320.0, 390.0, 480.0, 900.0]) {
    testWidgets('tracked controls fit width $width with larger text', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(TrackingNotifier.provider.notifier);
      final tracked = TrackedAnime(
        anilistId: 1,
        animeSnapshot: const AnilistAnime(
          id: 1,
          title: AnilistTitle(romaji: 'Reincarnated as a Sword Season 2'),
          genres: [],
        ),
        downloadFolder:
            '/Users/sen/Downloads/Anime/Reincarnated as a Sword Season 2',
        preferredSource: AnimeSource.tokyoinsider,
        sourceSelectedByUser: true,
        resolution: Resolution.res1080p,
        language: Language.japanese,
        createdAt: DateTime.utc(2026),
        updatedAt: DateTime.utc(2026),
      );
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: theme,
            home: Scaffold(
              body: MediaQuery(
                data: MediaQueryData(
                  size: Size(width, 900),
                  textScaler: const TextScaler.linear(1.3),
                ),
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: TrackedAnimeTile(
                      tracked: tracked,
                      index: 0,
                      notifier: notifier,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final source = find.byType(DropdownButton<String>);
      final resolution = find.byType(DropdownButton<Resolution>);
      final language = find.byType(DropdownButton<Language>);
      expect(source, findsOneWidget);
      if (width < 600) {
        expect(
          tester.getTopLeft(resolution).dy,
          greaterThan(tester.getTopLeft(source).dy),
        );
        expect(
          tester.getTopLeft(resolution).dy,
          tester.getTopLeft(language).dy,
        );
      }
    });
  }
}
