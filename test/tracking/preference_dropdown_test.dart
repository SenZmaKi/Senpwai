import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:senpwai/sources/shared/shared.dart';
import 'package:senpwai/ui/pages/anime_page/download_widgets.dart';

void main() {
  testWidgets(
    'compact tracked preferences expose resolution and language choices',
    (tester) async {
      Resolution? resolution;
      Language? language;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Wrap(
              children: [
                SizedBox(
                  width: 112,
                  child: DownloadDropdown<Resolution>(
                    label: 'Resolution',
                    showLabel: false,
                    options: downloadResolutionOptions,
                    selected: Resolution.res1080p,
                    labelBuilder: (value) => value.toString(),
                    onSelected: (value) => resolution = value,
                  ),
                ),
                SizedBox(
                  width: 140,
                  child: DownloadDropdown<Language>(
                    label: 'Language',
                    showLabel: false,
                    options: Language.values,
                    selected: Language.japanese,
                    labelBuilder: (value) => value.toString(),
                    onSelected: (value) => language = value,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      expect(find.text('Resolution'), findsNothing);
      expect(
        tester
            .widget<DropdownButton<Resolution>>(
              find.byType(DropdownButton<Resolution>),
            )
            .items!
            .map((item) => item.value),
        [
          Resolution.res1080p,
          Resolution.res720p,
          Resolution.res480p,
          Resolution.res360p,
        ],
      );
      await tester.tap(find.byType(DropdownButton<Resolution>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('720p').last);
      await tester.pumpAndSettle();
      expect(resolution, Resolution.res720p);
      await tester.tap(find.byType(DropdownButton<Language>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('English').last);
      await tester.pumpAndSettle();
      expect(language, Language.english);
      expect(tester.takeException(), isNull);
    },
  );
}
