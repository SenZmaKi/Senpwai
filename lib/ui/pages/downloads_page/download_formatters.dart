import 'package:senpwai/downloads/models.dart';

String formatDownloadTitle(String title) {
  return title.replaceFirst(RegExp(r' \(\d+\)(?=(?:\.[^.]*)?$)'), '');
}

String formatDownloadBytes(num bytes) {
  if (bytes >= 1024 * 1024 * 1024) {
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }
  if (bytes >= 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  if (bytes >= 1024) {
    return '${(bytes / 1024).toStringAsFixed(1)} KB';
  }
  return '${bytes.round()} B';
}

String formatDownloadEta(DownloadQueueItem item) {
  if (item.bytesPerSecond <= 0) return 'Waiting';
  final remaining = item.totalBytes - item.downloadedBytes;
  if (remaining <= 0) return 'Finishing';
  return formatEtaSeconds((remaining / item.bytesPerSecond).round());
}

String formatEtaSeconds(int seconds) {
  if (seconds < 60) return '${seconds}s';
  if (seconds < 3600) return '${seconds ~/ 60}m ${seconds % 60}s';
  return '${seconds ~/ 3600}h ${(seconds % 3600) ~/ 60}m';
}

String formatDownloadSpeed(num bytesPerSecond) =>
    '${formatDownloadBytes(bytesPerSecond.round())}/s';

String relativeDownloadTime(DateTime dateTime) {
  final diff = DateTime.now().difference(dateTime);
  if (diff.inSeconds < 60) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  return '${diff.inDays}d ago';
}
