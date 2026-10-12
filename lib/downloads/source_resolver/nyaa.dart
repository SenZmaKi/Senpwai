import 'package:logging/logging.dart';
import 'package:senpwai/anilist/enums.dart';
import 'package:senpwai/anitomy/anitomy.dart' as anitomy_parser;
import 'package:senpwai/sources/shared/fuzzy.dart';
import 'package:senpwai/anilist/models.dart';
import 'package:senpwai/downloads/source_resolver/shared.dart';
import 'package:senpwai/shared/log.dart';
import 'package:senpwai/sources/nyaa.dart' as nyaa;
import 'package:senpwai/sources/shared/matcher/nyaa.dart';
import 'package:senpwai/sources/shared/shared.dart';

final _log = Logger('senpwai.downloads.source_resolver.nyaa');

class NyaaDownloadSourceResolver {
  final NyaaMatcher _matcher;
  final nyaa.Source _source;

  NyaaDownloadSourceResolver({NyaaMatcher? matcher, nyaa.Source? source})
    : _matcher = matcher ?? NyaaMatcher(strictSearchErrors: true),
      _source = source ?? nyaa.Source.getInstance();

  Future<SourceMatchState<bool>> resolve(AnilistAnimeBase anime) async {
    try {
      if (anime.format == AnilistFormat.movie) {
        final matches = await _matcher.matchMovie(
          anime,
          const NyaaMatchParams(
            preferredResolution: Resolution.res1080p,
            preferredLanguage: Language.japanese,
          ),
        );
        if (matches.isEmpty) {
          return const SourceMatchState.failed(
            'No movie match found',
            noMatch: true,
          );
        }
        return const SourceMatchState.matched(true);
      }

      final expandedCandidates = expandNyaaTitleCandidates(
        anime.title.toTitleCandidates(),
      );
      if (expandedCandidates.isEmpty) {
        return const SourceMatchState.failed(
          'No title candidates',
          noMatch: true,
        );
      }
      final resultPages = await Future.wait(
        expandedCandidates
            .take(4)
            .map(
              (term) => _source.search(
                params: nyaa.SearchParams(term: term, page: 1),
              ),
            ),
      );
      final titleCandidates = anime.title.toTitleCandidates();
      final hasMatch = resultPages.any(
        (page) => page.items.any((result) {
          final title = anitomy_parser.parseFilename(result.filename).title;
          return title != null &&
              titleCandidates.any(
                (candidate) =>
                    titleSimilarity(candidate, title) >=
                    Constants.minMatchScore,
              );
        }),
      );
      if (!hasMatch) {
        return const SourceMatchState.failed('No results found', noMatch: true);
      }
      return const SourceMatchState.matched(true);
    } catch (error, stackTrace) {
      _log.warningWithMetadata(
        'Nyaa matching failed',
        metadata: {'error': error.toString(), 'stack': stackTrace.toString()},
      );
      return SourceMatchState.failed(error.toString());
    }
  }
}
