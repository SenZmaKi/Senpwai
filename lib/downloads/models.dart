import 'dart:typed_data';

import 'package:path/path.dart' as path;
import 'package:senpwai/anilist/models.dart';
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

final class PreparedTorrentDownloadJob extends PreparedDownloadJob {
  final Uint8List torrentData;
  final String torrentName;
  final List<int> selectedFileIndices;
  final List<String> selectedFilePaths;

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
  });
}

class PreparedDownloadBatch {
  final List<PreparedDownloadJob> jobs;
  final List<DownloadNotice> notices;
  final bool requiresUserReview;

  const PreparedDownloadBatch({
    required this.jobs,
    this.notices = const [],
    this.requiresUserReview = false,
  });
}

class EnqueuedDownloadsResult {
  final int queuedCount;
  final List<DownloadNotice> notices;

  const EnqueuedDownloadsResult({
    required this.queuedCount,
    this.notices = const [],
  });
}

class DownloadQueueItem {
  final String id;
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

  const DownloadQueueItem({
    required this.id,
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
  });

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
  }) {
    return DownloadQueueItem(
      id: id,
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
    );
  }
}

class DownloadManagerState {
  final List<DownloadQueueItem> items;

  const DownloadManagerState({this.items = const []});

  DownloadManagerState copyWith({List<DownloadQueueItem>? items}) {
    return DownloadManagerState(items: items ?? this.items);
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
