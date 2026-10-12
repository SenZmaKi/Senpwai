import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:senpwai/anilist/models.dart';
import 'package:senpwai/downloads/models.dart';
import 'package:senpwai/downloads/source_resolver.dart';
import 'package:senpwai/sources/shared/shared.dart';
import 'package:senpwai/tracking/models.dart';
import 'package:senpwai/ui/pages/settings_page/tracked_source_control.dart';

void main() {
  testWidgets(
    'failed checks keep selection and retry; stale results are ignored',
    (tester) async {
      final requests = <Completer<SourceMatchState<Object>>>[];
      final saved = <AnimeSource?>[];
      final now = DateTime.utc(2026);
      final tracked = TrackedAnime(
        anilistId: 1,
        animeSnapshot: const AnilistAnime(
          id: 1,
          title: AnilistTitle(romaji: 'Example'),
          genres: [],
        ),
        downloadFolder: '/anime',
        resolution: Resolution.res1080p,
        language: Language.japanese,
        createdAt: now,
        updatedAt: now,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TrackedSourceControl(
              tracked: tracked,
              checkSource: (_) {
                final request = Completer<SourceMatchState<Object>>();
                requests.add(request);
                return request.future;
              },
              onChanged: (source) async => saved.add(source),
            ),
          ),
        ),
      );
      Future<void> choose(String label) async {
        await tester.tap(find.byType(DropdownButton<String>));
        // A pending check deliberately keeps its progress animation running.
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        await tester.tap(find.widgetWithText(DropdownMenuItem<String>, label));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
      }

      await choose(AnimeSource.nyaa.label);
      expect(find.text('Checking Nyaa…'), findsOneWidget);
      expect(saved, isEmpty);
      requests.last.complete(
        const SourceMatchState.failed('No match found', noMatch: true),
      );
      await tester.pumpAndSettle();
      expect(find.text('Not found on Nyaa'), findsOneWidget);
      expect(saved, isEmpty);
      await tester.tap(find.text('Retry'));
      await tester.pump();
      requests.last.complete(const SourceMatchState.failed('Network failure'));
      await tester.pumpAndSettle();
      expect(find.text('Couldn’t check Nyaa'), findsOneWidget);
      await tester.tap(find.text('Retry'));
      await tester.pump();
      final stale = requests.last;
      await choose(AnimeSource.animepahe.label);
      stale.complete(const SourceMatchState.matched(true));
      await tester.pump();
      expect(saved, isEmpty);
      requests.last.complete(const SourceMatchState.matched(true));
      await tester.pumpAndSettle();
      expect(saved, [AnimeSource.animepahe]);
      expect(find.text('Found · locked to AnimePahe'), findsOneWidget);
      await choose(AnimeSource.nyaa.label);
      final cancelled = requests.last;
      await choose('Auto');
      cancelled.complete(const SourceMatchState.matched(true));
      await tester.pumpAndSettle();
      expect(saved, [AnimeSource.animepahe, null]);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('source menu locks a source and returns to automatic', (
    tester,
  ) async {
    AnimeSource? selected;
    var calls = 0;
    final now = DateTime.utc(2026);
    final tracked = TrackedAnime(
      anilistId: 1,
      animeSnapshot: const AnilistAnime(
        id: 1,
        title: AnilistTitle(romaji: 'Example'),
        genres: [],
      ),
      downloadFolder: '/anime',
      resolution: Resolution.res1080p,
      language: Language.japanese,
      createdAt: now,
      updatedAt: now,
    );
    Future<void> show(TrackedAnime item) => tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(
          body: TrackedSourceControl(
            tracked: item,
            enabledSources: const {AnimeSource.nyaa},
            checkSource: (_) async => const SourceMatchState.matched(true),
            onChanged: (source) async {
              selected = source;
              calls++;
            },
          ),
        ),
      ),
    );
    await show(tracked);
    await tester.tap(find.byType(DropdownButton<String>));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(
      tester
          .widget<DropdownMenuItem<String>>(
            find.widgetWithText(
              DropdownMenuItem<String>,
              AnimeSource.animepahe.label,
            ),
          )
          .enabled,
      isFalse,
    );
    await tester.tap(
      find.widgetWithText(DropdownMenuItem<String>, AnimeSource.nyaa.label),
    );
    await tester.pumpAndSettle();
    expect(selected, AnimeSource.nyaa);
    await show(
      tracked.copyWith(
        preferredSource: AnimeSource.nyaa,
        sourceSelectedByUser: true,
      ),
    );
    expect(find.text(AnimeSource.nyaa.label), findsOneWidget);
    expect(find.byIcon(Icons.lock_outline), findsOneWidget);
    await tester.tap(find.byType(DropdownButton<String>));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.widgetWithText(DropdownMenuItem<String>, 'Auto'));
    await tester.pumpAndSettle();
    expect(selected, isNull);
    expect(calls, 2);
  });
}
