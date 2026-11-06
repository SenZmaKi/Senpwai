import 'package:flutter/foundation.dart';
import 'package:senpwai/downloads/models.dart';

String? activeTorrentOwner(
  Map<String, PreparedDownloadJob> jobs,
  Iterable<String> activeIds,
  Uint8List bytes, {
  String? exceptId,
}) {
  for (final id in activeIds) {
    if (id == exceptId) continue;
    if (jobs[id] case PreparedTorrentDownloadJob(:final torrentData)) {
      if (listEquals(torrentData, bytes)) return id;
    }
  }
  return null;
}
