import 'dart:async';
import 'package:dio/dio.dart';
import 'package:senpwai/shared/net/request_cancellation_scope.dart';
import 'package:collection/collection.dart';
import 'package:senpwai/downloads/models.dart';
import 'package:senpwai/shared/net/download/download.dart';
import 'package:senpwai/shared/parallel.dart';
import 'package:senpwai/sources/animeheaven.dart' as heaven;
import 'package:senpwai/sources/animepahe.dart' as pahe;
import 'package:senpwai/sources/tokyoinsider.dart' as tokyo;

/// Runs in the main isolate: source requests may need its browser transport.
/// Recovery never chooses another quality, audio track, or similarly named file.
class HttpLinkRefresh {
  static final _lane = AsyncLimiter(1);

  static Future<PreparedHttpDownloadJob> refresh(
    PreparedHttpDownloadJob job,
  ) async {
    final cancel = CancelToken();
    final timeout = Timer(
      const Duration(seconds: 100),
      () => cancel.cancel('Source recovery timed out'),
    );
    try {
      return await _lane.run(
        () => runWithRequestCancelToken(cancel, () => _refresh(job)),
      );
    } finally {
      timeout.cancel();
    }
  }

  static Future<PreparedHttpDownloadJob> _refresh(
    PreparedHttpDownloadJob job,
  ) async {
    throwIfRequestScopeCancelled();
    final recipe = job.recovery;
    if (recipe == null) {
      throw const DownloadUserError(
        title: 'Download link expired',
        description:
            'This download has no saved source selection. Choose it again from the anime page.',
      );
    }
    late String url;
    final headers = <String, dynamic>{};
    switch (job.source) {
      case AnimeSource.animeheaven:
        final source = heaven.Source.getInstance();
        final pages = await source.fetchEpisodePages(
          animeUrl: recipe.animeLocator,
          animeTitle: job.animeTitle,
        );
        final page = _exact(
          pages.where((p) => p.episodeNumber == recipe.episode),
        );
        url = await source.fetchDownloadUrl(episodePage: page);
      case AnimeSource.tokyoinsider:
        final source = tokyo.Source.getInstance();
        final pages = await source.fetchEpisodePages(
          animeUrl: recipe.animeLocator,
          animeTitle: job.animeTitle,
        );
        final page = _exact(
          pages.where((p) => p.episodeNumber == recipe.episode),
        );
        final links = await source.fetchEpisodeDownloadLinks(episodePage: page);
        final link = _exact(
          links.where(
            (l) =>
                l.filename == recipe.sourceFileName &&
                l.resolution?.name == recipe.resolution &&
                l.language?.name == recipe.language,
          ),
        );
        url = link.url;
      case AnimeSource.animepahe:
        await pahe.Source.ensureInitialized();
        final source = pahe.Source.getInstance();
        // Refresh the anime session using a stable numeric ID. Never fuzzy
        // match another title when a session has changed.
        var animeSession = recipe.animeLocator;
        for (var page = 1; page <= 5 && recipe.animeId != null; page++) {
          final results = await source.search(
            params: pahe.SearchParams(term: job.animeTitle, page: page),
          );
          final match = results.items.firstWhereOrNull(
            (a) => a.id == recipe.animeId,
          );
          if (match != null) {
            animeSession = match.session;
            break;
          }
          if (results.fetchNextPage == null) break;
        }
        final range = await source.computeEpisodePageRange(
          startEpisode: recipe.episode,
          endEpisode: recipe.episode,
          animeSession: animeSession,
        );
        final sessions = await source.fetchEpisodeSessions(
          animeSession: animeSession,
          pageNum: range.startPageNum,
          pageJson: range.startPageNum == 1 ? range.firstPageJson : null,
        );
        final episode = _exact(
          sessions.where((s) => s.number == recipe.episode),
        );
        final links = await source.fetchDownloadLinks(
          animeTitle: job.animeTitle,
          animeSession: animeSession,
          episodeSession: episode,
        );
        final link = _exact(
          links.where(
            (l) =>
                l.filename == recipe.sourceFileName &&
                l.resolution.name == recipe.resolution &&
                l.audioLanguage.name == recipe.language,
          ),
        );
        final batch = source.openKwikLinkResolverBatch();
        try {
          final direct = await source.fetchDirectDownloadLink(
            downloadLink: link,
          );
          url = direct.url;
          headers['Referer'] = direct.refererUrl;
        } finally {
          await batch.close();
        }
      case AnimeSource.nyaa:
        throw StateError('A torrent cannot refresh HTTP access.');
    }
    final target = await Download.probeSingleFile(url: url, headers: headers);
    if (job.source == AnimeSource.animeheaven &&
        recipe.sourceFileName.isNotEmpty &&
        target.suggestedFileName != recipe.sourceFileName) {
      throw const DownloadUserError(
        title: 'Source file changed',
        description:
            'The source now offers a different file. Choose a replacement from the anime page.',
      );
    }
    return job.withAccess(
      url: target.resolvedUrl,
      size: target.sizeBytes,
      headers: headers,
    );
  }

  static T _exact<T>(Iterable<T> matches) {
    final values = matches.toList();
    if (values.length != 1) {
      throw const DownloadUserError(
        title: 'Selected file unavailable',
        description:
            'The exact saved file could not be identified. Retry later or choose a replacement from the anime page.',
      );
    }
    return values.single;
  }
}
