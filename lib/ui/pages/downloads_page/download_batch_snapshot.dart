import 'package:senpwai/downloads/models.dart';

/// A read-only roll-up of a batch and its items.
/// Built fresh per render — cheap, no state of its own.
class DownloadBatchSnapshot {
  final DownloadBatchQueue batch;
  final List<DownloadQueueItem> items;

  const DownloadBatchSnapshot({required this.batch, required this.items});

  int get activeCount => items.where((i) => !i.status.isTerminal).length;
  int get doneCount => items.length - activeCount;
  int get completedCount =>
      items.where((i) => i.status == DownloadQueueStatus.completed).length;
  int get failedCount =>
      items.where((i) => i.status == DownloadQueueStatus.failed).length;
  int get queuedCount =>
      items.where((i) => i.status == DownloadQueueStatus.queued).length;
  int get downloadingCount =>
      items.where((i) => i.status == DownloadQueueStatus.downloading).length;
  int get pausedCount =>
      items.where((i) => i.status == DownloadQueueStatus.paused).length;

  int get totalBytes => items.fold(0, (s, i) => s + i.totalBytes);
  int get downloadedBytes => items.fold(0, (s, i) => s + i.downloadedBytes);
  double get bytesPerSecond =>
      items.fold(0.0, (s, i) => s + i.bytesPerSecond);

  bool get hasTorrentStats => items.any((i) => i.torrentStats != null);

  double get uploadBytesPerSecond => items.fold(
        0.0,
        (s, i) => s + (i.torrentStats?.uploadBytesPerSecond ?? 0),
      );

  int get numSeeds =>
      items.fold(0, (s, i) => s + (i.torrentStats?.numSeeds ?? 0));

  int get numPeers =>
      items.fold(0, (s, i) => s + (i.torrentStats?.numPeers ?? 0));

  double get progress {
    if (totalBytes <= 0) return 0;
    return downloadedBytes.clamp(0, totalBytes) / totalBytes;
  }

  /// Aggregate ETA in seconds across all active items.
  int? get etaSeconds {
    if (bytesPerSecond <= 0) return null;
    final remaining = totalBytes - downloadedBytes;
    if (remaining <= 0) return null;
    return (remaining / bytesPerSecond).round();
  }

  DownloadQueueItem? get nextItem {
    for (final i in items) {
      if (i.status == DownloadQueueStatus.downloading) return i;
    }
    for (final i in items) {
      if (i.status == DownloadQueueStatus.queued ||
          i.status == DownloadQueueStatus.preparing) {
        return i;
      }
    }
    return null;
  }

  DownloadQueueStatus get status {
    if (items.isEmpty) return DownloadQueueStatus.cancelled;
    if (downloadingCount > 0) return DownloadQueueStatus.downloading;
    if (pausedCount > 0) return DownloadQueueStatus.paused;
    if (queuedCount > 0) return DownloadQueueStatus.queued;
    if (failedCount > 0 && completedCount == 0) {
      return DownloadQueueStatus.failed;
    }
    if (items.every((i) => i.status == DownloadQueueStatus.completed)) {
      return DownloadQueueStatus.completed;
    }
    if (items.every((i) => i.status == DownloadQueueStatus.cancelled)) {
      return DownloadQueueStatus.cancelled;
    }
    return DownloadQueueStatus.completed;
  }

  bool get isTerminal =>
      items.isNotEmpty && items.every((i) => i.status.isTerminal);

  bool get canPause => downloadingCount > 0;
  bool get canResume => pausedCount > 0;
}

List<DownloadBatchSnapshot> buildBatchSnapshots(DownloadManagerState state) {
  final byId = {for (final item in state.items) item.id: item};
  final out = <DownloadBatchSnapshot>[];
  for (final batch in state.batches) {
    final items = <DownloadQueueItem>[
      for (final id in batch.itemIds)
        if (byId[id] != null) byId[id]!,
    ];
    if (items.isEmpty) continue;
    out.add(DownloadBatchSnapshot(batch: batch, items: items));
  }
  return out;
}
