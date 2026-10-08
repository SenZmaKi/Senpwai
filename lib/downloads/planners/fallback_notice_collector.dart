import 'package:senpwai/downloads/models.dart';

/// Collects per-episode fallback decisions and turns them into concise,
/// source-level notices once planning has finished.
class FallbackNoticeCollector {
  final String sourceName;
  final Map<String, List<int>> _audioEpisodesBySelection = {};
  final Map<String, List<int>> _qualityEpisodesBySelection = {};
  final List<int> _skippedEpisodes = [];
  String? _requiredPreferences;
  String? _requestedAudio;
  String? _requestedQuality;

  FallbackNoticeCollector({required this.sourceName});

  void recordAudio({
    required int episodeNumber,
    required String requested,
    required String selected,
  }) {
    _requestedAudio = requested;
    (_audioEpisodesBySelection[selected] ??= []).add(episodeNumber);
  }

  void recordQuality({
    required int episodeNumber,
    required String requested,
    required String selected,
  }) {
    _requestedQuality = requested;
    (_qualityEpisodesBySelection[selected] ??= []).add(episodeNumber);
  }

  void recordSkipped(int episodeNumber, DownloadRequest request) {
    _skippedEpisodes.add(episodeNumber);
    _requiredPreferences = [
      if (!request.allowAudioFallback) '${request.language} audio',
      if (!request.allowQualityFallback) '${request.resolution} quality',
    ].join(' and ');
  }

  List<DownloadNotice> build() => [
    if (_skippedEpisodes.isNotEmpty)
      DownloadNotice(
        level: DownloadNoticeLevel.warning,
        title: 'Episodes skipped',
        description:
            '$sourceName ${_episodeListLabel(_skippedEpisodes..sort())} '
            'could not be confirmed in $_requiredPreferences and were skipped because fallback is disabled.',
      ),
    if (_audioEpisodesBySelection.isNotEmpty)
      DownloadNotice(
        level: DownloadNoticeLevel.warning,
        title: 'Audio fallback',
        description: _description(
          requested: _requestedAudio!,
          episodesBySelection: _audioEpisodesBySelection,
        ),
      ),
    if (_qualityEpisodesBySelection.isNotEmpty)
      DownloadNotice(
        level: DownloadNoticeLevel.warning,
        title: 'Quality fallback',
        description: _description(
          requested: _requestedQuality!,
          episodesBySelection: _qualityEpisodesBySelection,
        ),
      ),
  ];

  String _description({
    required String requested,
    required Map<String, List<int>> episodesBySelection,
  }) {
    final allEpisodes =
        episodesBySelection.values.expand((items) => items).toList()..sort();
    if (episodesBySelection.length == 1) {
      final selected = episodesBySelection.keys.single;
      return '$sourceName ${_episodeListLabel(allEpisodes)} '
          '${allEpisodes.length == 1 ? 'is' : 'are'} not available in '
          '$requested; using $selected.';
    }

    final selections = episodesBySelection.entries
        .map((entry) {
          final episodes = entry.value..sort();
          return '${_episodeListLabel(episodes)} use ${entry.key}';
        })
        .join('; ');
    return '$sourceName ${_episodeListLabel(allEpisodes)} '
        '${allEpisodes.length == 1 ? 'is' : 'are'} not available in '
        '$requested. $selections.';
  }
}

String _episodeListLabel(List<int> episodes) {
  final ranges = <String>[];
  var rangeStart = episodes.first;
  var rangeEnd = rangeStart;
  for (final episode in episodes.skip(1)) {
    if (episode == rangeEnd + 1) {
      rangeEnd = episode;
      continue;
    }
    ranges.add(
      rangeStart == rangeEnd ? '$rangeStart' : '$rangeStart–$rangeEnd',
    );
    rangeStart = rangeEnd = episode;
  }
  ranges.add(rangeStart == rangeEnd ? '$rangeStart' : '$rangeStart–$rangeEnd');
  return '${episodes.length == 1 ? 'episode' : 'episodes'} ${ranges.join(', ')}';
}
