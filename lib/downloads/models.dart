import 'dart:typed_data';

import 'package:path/path.dart' as path;
import 'package:senpwai/anilist/models.dart';
import 'package:senpwai/downloads/nyaa_recovery.dart';
import 'package:senpwai/sources/shared/shared.dart';

enum AnimeSource { animepahe, tokyoinsider, nyaa }

extension AnimeSourceExtension on AnimeSource {
  String get label => switch (this) {
    AnimeSource.animepahe => 'AnimePahe',
    AnimeSource.tokyoinsider => 'TokyoInsider',
    AnimeSource.nyaa => 'Nyaa',
  };
}

enum DownloadQueueStatus {
  preparing,
  // Enqueued and waiting its turn. Has never been the first batch in the
  // queue — has not started downloading yet. Distinct from [paused], which
  // implies the item was running and got stopped.
  queued,
  downloading,
  paused,
  completed,
  failed,
  cancelled,
}

extension DownloadQueueStatusExtension on DownloadQueueStatus {
  bool get isTerminal => switch (this) {
    DownloadQueueStatus.completed ||
    DownloadQueueStatus.failed ||
    DownloadQueueStatus.cancelled => true,
    _ => false,
  };

  String get label => switch (this) {
    DownloadQueueStatus.preparing => 'Preparing',
    DownloadQueueStatus.queued => 'Queued',
    DownloadQueueStatus.downloading => 'Downloading',
    DownloadQueueStatus.paused => 'Paused',
    DownloadQueueStatus.completed => 'Completed',
    DownloadQueueStatus.failed => 'Failed',
    DownloadQueueStatus.cancelled => 'Cancelled',
  };
}

enum DownloadNoticeLevel { info, warning }

class DownloadNotice {
  final DownloadNoticeLevel level;
  final String title;
  final String? description;

  const DownloadNotice({
    required this.level,
    required this.title,
    this.description,
  });
}

class DownloadUserError implements Exception {
  final String title;
  final String description;
  final Object? cause;
  final StackTrace? stackTrace;

  const DownloadUserError({
    required this.title,
    required this.description,
    this.cause,
    this.stackTrace,
  });

  String? get copyPayload {
    if (cause == null) return null;
    final buffer = StringBuffer()
      ..writeln('Error: $cause')
      ..writeln('Type: ${cause.runtimeType}');
    if (stackTrace != null) {
      buffer
        ..writeln()
        ..writeln('Stack trace:')
        ..write(stackTrace);
    }
    return buffer.toString();
  }

  @override
  String toString() => '$title: $description';
}

sealed class PreparedDownloadJob {
  final AnimeSource source;
  final String animeTitle;
  final String displayTitle;
  final String destinationDirectory;
  final int totalBytes;

  const PreparedDownloadJob({
    required this.source,
    required this.animeTitle,
    required this.displayTitle,
    required this.destinationDirectory,
    required this.totalBytes,
  });
}

final class PreparedHttpDownloadJob extends PreparedDownloadJob {
  final String resolvedUrl;
  final String fileName;
  final int? episodeNumber;
  final Map<String, dynamic> headers;

  const PreparedHttpDownloadJob({
    required super.source,
    required super.animeTitle,
    required super.displayTitle,
    required super.destinationDirectory,
    required super.totalBytes,
    required this.resolvedUrl,
    required this.fileName,
    this.headers = const {},
    this.episodeNumber,
  });

  String get targetFilePath => path.join(destinationDirectory, fileName);
}

class TorrentReviewMetadata {
  final int? episodeNumber;
  final Resolution? resolution;
  final int? seeders;
  final String? languageLabel;
  final bool isBatch;

  const TorrentReviewMetadata({
    this.episodeNumber,
    this.resolution,
    this.seeders,
    this.languageLabel,
    this.isBatch = false,
  });
}

final class PreparedTorrentDownloadJob extends PreparedDownloadJob {
  final Uint8List torrentData;
  final String torrentName;
  final List<int> selectedFileIndices;
  final List<String> selectedFilePaths;
  final Map<int, String> renamedFilePaths;
  final TorrentReviewMetadata? reviewMetadata;

  const PreparedTorrentDownloadJob({
    required super.source,
    required super.animeTitle,
    required super.displayTitle,
    required super.destinationDirectory,
    required super.totalBytes,
    required this.torrentData,
    required this.torrentName,
    required this.selectedFileIndices,
    required this.selectedFilePaths,
    this.renamedFilePaths = const {},
    this.reviewMetadata,
  });
}

class PreparedDownloadBatch {
  final List<PreparedDownloadJob> jobs;
  final List<DownloadNotice> notices;
  final List<NyaaEpisodeResolutionIssue> nyaaEpisodeIssues;

  const PreparedDownloadBatch({
    required this.jobs,
    this.notices = const [],
    this.nyaaEpisodeIssues = const [],
  });

  bool get requiresUserInteraction => nyaaEpisodeIssues.isNotEmpty;

  PreparedDownloadBatch copyWith({
    List<PreparedDownloadJob>? jobs,
    List<DownloadNotice>? notices,
    List<NyaaEpisodeResolutionIssue>? nyaaEpisodeIssues,
  }) {
    return PreparedDownloadBatch(
      jobs: jobs ?? this.jobs,
      notices: notices ?? this.notices,
      nyaaEpisodeIssues: nyaaEpisodeIssues ?? this.nyaaEpisodeIssues,
    );
  }
}

class EnqueuedDownloadsResult {
  final int queuedCount;
  final List<DownloadNotice> notices;
  final String? batchId;

  const EnqueuedDownloadsResult({
    required this.queuedCount,
    this.notices = const [],
    this.batchId,
  });
}

/// Live torrent-only swarm stats sourced from libtorrent. Present only for
/// torrent downloads; HTTP downloads leave [DownloadQueueItem.torrentStats]
/// null.
class TorrentLiveStats {
  final double uploadBytesPerSecond;
  final int numSeeds;
  final int numPeers;
  final int listSeeds;
  final int listPeers;
  final int totalUploaded;

  const TorrentLiveStats({
    required this.uploadBytesPerSecond,
    required this.numSeeds,
    required this.numPeers,
    required this.listSeeds,
    required this.listPeers,
    required this.totalUploaded,
  });

  static const zero = TorrentLiveStats(
    uploadBytesPerSecond: 0,
    numSeeds: 0,
    numPeers: 0,
    listSeeds: 0,
    listPeers: 0,
    totalUploaded: 0,
  );
}

class DownloadQueueItem {
  final String id;
  final String batchId;
  final AnimeSource source;
  final String animeTitle;
  final String displayTitle;
  final String destinationDirectory;
  final DownloadQueueStatus status;
  final int totalBytes;
  final int downloadedBytes;
  final double bytesPerSecond;
  final String? errorTitle;
  final String? errorDescription;
  final String? errorCopyPayload;
  final DateTime createdAt;
  final List<String> filePaths;
  final TorrentLiveStats? torrentStats;

  const DownloadQueueItem({
    required this.id,
    required this.batchId,
    required this.source,
    required this.animeTitle,
    required this.displayTitle,
    required this.destinationDirectory,
    required this.status,
    required this.totalBytes,
    required this.downloadedBytes,
    required this.bytesPerSecond,
    required this.createdAt,
    this.filePaths = const [],
    this.errorTitle,
    this.errorDescription,
    this.errorCopyPayload,
    this.torrentStats,
  });

  bool get isTorrent => source == AnimeSource.nyaa;

  double get progress =>
      totalBytes <= 0 ? 0 : downloadedBytes.clamp(0, totalBytes) / totalBytes;

  DownloadQueueItem copyWith({
    DownloadQueueStatus? status,
    int? totalBytes,
    int? downloadedBytes,
    double? bytesPerSecond,
    String? errorTitle,
    String? errorDescription,
    String? errorCopyPayload,
    bool clearError = false,
    List<String>? filePaths,
    TorrentLiveStats? torrentStats,
  }) {
    return DownloadQueueItem(
      id: id,
      batchId: batchId,
      source: source,
      animeTitle: animeTitle,
      displayTitle: displayTitle,
      destinationDirectory: destinationDirectory,
      status: status ?? this.status,
      totalBytes: totalBytes ?? this.totalBytes,
      downloadedBytes: downloadedBytes ?? this.downloadedBytes,
      bytesPerSecond: bytesPerSecond ?? this.bytesPerSecond,
      createdAt: createdAt,
      filePaths: filePaths ?? this.filePaths,
      errorTitle: clearError ? null : (errorTitle ?? this.errorTitle),
      errorDescription: clearError
          ? null
          : (errorDescription ?? this.errorDescription),
      errorCopyPayload: clearError
          ? null
          : (errorCopyPayload ?? this.errorCopyPayload),
      torrentStats: torrentStats ?? this.torrentStats,
    );
  }
}

class DownloadBatchQueue {
  final String id;
  final String title;
  final AnimeSource source;
  final DateTime createdAt;
  final List<String> itemIds;

  const DownloadBatchQueue({
    required this.id,
    required this.title,
    required this.source,
    required this.createdAt,
    required this.itemIds,
  });

  DownloadBatchQueue copyWith({
    String? title,
    AnimeSource? source,
    List<String>? itemIds,
  }) {
    return DownloadBatchQueue(
      id: id,
      title: title ?? this.title,
      source: source ?? this.source,
      createdAt: createdAt,
      itemIds: itemIds ?? this.itemIds,
    );
  }
}

class DownloadManagerState {
  final List<DownloadQueueItem> items;
  final List<DownloadBatchQueue> batches;
  final String? activeBatchId;

  const DownloadManagerState({
    this.items = const [],
    this.batches = const [],
    this.activeBatchId,
  });

  DownloadManagerState copyWith({
    List<DownloadQueueItem>? items,
    List<DownloadBatchQueue>? batches,
    String? activeBatchId,
    bool clearActiveBatchId = false,
  }) {
    return DownloadManagerState(
      items: items ?? this.items,
      batches: batches ?? this.batches,
      activeBatchId: clearActiveBatchId
          ? null
          : (activeBatchId ?? this.activeBatchId),
    );
  }
}

class DownloadRequest {
  final AnilistAnimeBase anime;
  final AnimeSource source;
  final int startEpisode;
  final int endEpisode;
  final String downloadFolder;
  final String httpJobTitle;
  final Resolution resolution;
  final Language language;

  const DownloadRequest({
    required this.anime,
    required this.source,
    required this.startEpisode,
    required this.endEpisode,
    required this.downloadFolder,
    required this.httpJobTitle,
    required this.resolution,
    required this.language,
  });
}
