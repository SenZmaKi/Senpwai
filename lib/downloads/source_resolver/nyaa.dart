import 'package:logging/logging.dart';
import 'package:senpwai/anilist/models.dart';
import 'package:senpwai/downloads/source_resolver/shared.dart';
import 'package:senpwai/shared/log.dart';
import 'package:senpwai/sources/nyaa.dart' as nyaa;
import 'package:senpwai/sources/shared/matcher/nyaa.dart';

final _log = Logger('senpwai.downloads.source_resolver.nyaa');

class NyaaDownloadSourceResolver {
  final nyaa.Source _source;

  NyaaDownloadSourceResolver({nyaa.Source? source})
    : _source = source ?? nyaa.Source.getInstance();

  Future<SourceMatchState<bool>> resolve(AnilistAnimeBase anime) async {
    try {
      final expandedCandidates = expandNyaaTitleCandidates(
        anime.title.toTitleCandidates(),
      );
      if (expandedCandidates.isEmpty) {
        return const SourceMatchState.failed('No title candidates');
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
      if (resultPages.every((page) => page.items.isEmpty)) {
        return const SourceMatchState.failed('No results found');
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
