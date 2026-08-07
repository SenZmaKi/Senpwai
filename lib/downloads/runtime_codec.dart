import 'dart:convert';
import 'dart:typed_data';

import 'package:senpwai/downloads/models.dart';
import 'package:senpwai/settings/settings.dart';

class DownloadRuntimeCodec {
  const DownloadRuntimeCodec._();

  static Map<String, Object?> encodeState(DownloadManagerState state) => {
    'items': state.items.map(encodeItem).toList(),
    'batches': state.batches.map(encodeBatchQueue).toList(),
    'activeBatchId': state.activeBatchId,
  };

  static DownloadManagerState decodeState(Map<Object?, Object?> map) {
    return DownloadManagerState(
      items: _list(map['items']).map((item) => decodeItem(_map(item))).toList(),
      batches: _list(
        map['batches'],
      ).map((batch) => decodeBatchQueue(_map(batch))).toList(),
      activeBatchId: _stringOrNull(map['activeBatchId']),
    );
  }

  static Map<String, Object?> encodeItem(DownloadQueueItem item) => {
    'id': item.id,
    'batchId': item.batchId,
    'source': item.source.name,
    'animeTitle': item.animeTitle,
    'displayTitle': item.displayTitle,
    'destinationDirectory': item.destinationDirectory,
    'status': item.status.name,
    'totalBytes': item.totalBytes,
    'downloadedBytes': item.downloadedBytes,
    'bytesPerSecond': item.bytesPerSecond,
    'errorTitle': item.errorTitle,
    'errorDescription': item.errorDescription,
    'errorCopyPayload': item.errorCopyPayload,
    'createdAt': item.createdAt.toIso8601String(),
    'filePaths': item.filePaths,
    'torrentStats': item.torrentStats == null
        ? null
        : encodeTorrentStats(item.torrentStats!),
    'seedingTargetReached': item.seedingTargetReached,
  };

  static DownloadQueueItem decodeItem(Map<Object?, Object?> map) {
    return DownloadQueueItem(
      id: _string(map['id']),
      batchId: _string(map['batchId']),
      source: _enumValue(AnimeSource.values, map['source'], AnimeSource.nyaa),
      animeTitle: _string(map['animeTitle']),
      displayTitle: _string(map['displayTitle']),
      destinationDirectory: _string(map['destinationDirectory']),
      status: _enumValue(
        DownloadQueueStatus.values,
        map['status'],
        DownloadQueueStatus.queued,
      ),
      totalBytes: _int(map['totalBytes']),
      downloadedBytes: _int(map['downloadedBytes']),
      bytesPerSecond: _double(map['bytesPerSecond']),
      createdAt: DateTime.tryParse(_string(map['createdAt'])) ?? DateTime.now(),
      filePaths: _stringList(map['filePaths']),
      errorTitle: _stringOrNull(map['errorTitle']),
      errorDescription: _stringOrNull(map['errorDescription']),
      errorCopyPayload: _stringOrNull(map['errorCopyPayload']),
      torrentStats: map['torrentStats'] == null
          ? null
          : decodeTorrentStats(_map(map['torrentStats'])),
      seedingTargetReached: map['seedingTargetReached'] == true,
    );
  }

  static Map<String, Object?> encodeBatchQueue(DownloadBatchQueue batch) => {
    'id': batch.id,
    'title': batch.title,
    'source': batch.source.name,
    'createdAt': batch.createdAt.toIso8601String(),
    'itemIds': batch.itemIds,
  };

  static DownloadBatchQueue decodeBatchQueue(Map<Object?, Object?> map) {
    return DownloadBatchQueue(
      id: _string(map['id']),
      title: _string(map['title']),
      source: _enumValue(AnimeSource.values, map['source'], AnimeSource.nyaa),
      createdAt: DateTime.tryParse(_string(map['createdAt'])) ?? DateTime.now(),
      itemIds: _stringList(map['itemIds']),
    );
  }

  static Map<String, Object?> encodeTorrentStats(TorrentLiveStats stats) => {
    'uploadBytesPerSecond': stats.uploadBytesPerSecond,
    'numSeeds': stats.numSeeds,
    'numPeers': stats.numPeers,
    'listSeeds': stats.listSeeds,
    'listPeers': stats.listPeers,
    'totalUploaded': stats.totalUploaded,
  };

  static TorrentLiveStats decodeTorrentStats(Map<Object?, Object?> map) {
    return TorrentLiveStats(
      uploadBytesPerSecond: _double(map['uploadBytesPerSecond']),
      numSeeds: _int(map['numSeeds']),
      numPeers: _int(map['numPeers']),
      listSeeds: _int(map['listSeeds']),
      listPeers: _int(map['listPeers']),
      totalUploaded: _int(map['totalUploaded']),
    );
  }

  static Map<String, Object?> encodePreparedBatch(PreparedDownloadBatch batch) {
    return {
      'jobs': batch.jobs.map(encodePreparedJob).toList(),
      'notices': batch.notices.map(encodeNotice).toList(),
    };
  }

  static PreparedDownloadBatch decodePreparedBatch(Map<Object?, Object?> map) {
    return PreparedDownloadBatch(
      jobs: _list(
        map['jobs'],
      ).map((job) => decodePreparedJob(_map(job))).toList(),
      notices: _list(
        map['notices'],
      ).map((notice) => decodeNotice(_map(notice))).toList(),
    );
  }

  static Map<String, Object?> encodePreparedJob(PreparedDownloadJob job) {
    final base = <String, Object?>{
      'source': job.source.name,
      'animeTitle': job.animeTitle,
      'displayTitle': job.displayTitle,
      'destinationDirectory': job.destinationDirectory,
      'totalBytes': job.totalBytes,
    };
    return switch (job) {
      PreparedHttpDownloadJob() => {
        ...base,
        'type': 'http',
        'resolvedUrl': job.resolvedUrl,
        'fileName': job.fileName,
        'episodeNumber': job.episodeNumber,
        'headers': jsonEncode(job.headers),
      },
      PreparedTorrentDownloadJob() => {
        ...base,
        'type': 'torrent',
        'torrentData': base64Encode(job.torrentData),
        'torrentName': job.torrentName,
        'selectedFileIndices': job.selectedFileIndices,
        'selectedFilePaths': job.selectedFilePaths,
        'renamedFilePaths': job.renamedFilePaths,
      },
    };
  }

  static PreparedDownloadJob decodePreparedJob(Map<Object?, Object?> map) {
    final source = _enumValue(
      AnimeSource.values,
      map['source'],
      AnimeSource.nyaa,
    );
    final type = _string(map['type']);
    if (type == 'http') {
      return PreparedHttpDownloadJob(
        source: source,
        animeTitle: _string(map['animeTitle']),
        displayTitle: _string(map['displayTitle']),
        destinationDirectory: _string(map['destinationDirectory']),
        totalBytes: _int(map['totalBytes']),
        resolvedUrl: _string(map['resolvedUrl']),
        fileName: _string(map['fileName']),
        episodeNumber: _nullableInt(map['episodeNumber']),
        headers: _decodeHeaders(_string(map['headers'])),
      );
    }
    return PreparedTorrentDownloadJob(
      source: source,
      animeTitle: _string(map['animeTitle']),
      displayTitle: _string(map['displayTitle']),
      destinationDirectory: _string(map['destinationDirectory']),
      totalBytes: _int(map['totalBytes']),
      torrentData: Uint8List.fromList(
        base64Decode(_string(map['torrentData'])),
      ),
      torrentName: _string(map['torrentName']),
      selectedFileIndices: _intList(map['selectedFileIndices']),
      selectedFilePaths: _stringList(map['selectedFilePaths']),
      renamedFilePaths: _intStringMap(map['renamedFilePaths']),
    );
  }

  static Map<String, Object?> encodeNotice(DownloadNotice notice) => {
    'level': notice.level.name,
    'title': notice.title,
    'description': notice.description,
  };

  static DownloadNotice decodeNotice(Map<Object?, Object?> map) {
    return DownloadNotice(
      level: _enumValue(
        DownloadNoticeLevel.values,
        map['level'],
        DownloadNoticeLevel.info,
      ),
      title: _string(map['title']),
      description: _stringOrNull(map['description']),
    );
  }

  static Map<String, Object?> encodeEnqueuedResult(
    EnqueuedDownloadsResult result,
  ) => {
    'queuedCount': result.queuedCount,
    'notices': result.notices.map(encodeNotice).toList(),
    'batchId': result.batchId,
  };

  static EnqueuedDownloadsResult decodeEnqueuedResult(
    Map<Object?, Object?> map,
  ) {
    return EnqueuedDownloadsResult(
      queuedCount: _int(map['queuedCount']),
      notices: _list(
        map['notices'],
      ).map((notice) => decodeNotice(_map(notice))).toList(),
      batchId: _stringOrNull(map['batchId']),
    );
  }

  static Map<String, Object?> encodeTorrentSettings(
    TorrentPreferences settings,
  ) => {
    'maxDownloadBytesPerSecond': settings.maxDownloadBytesPerSecond,
    'maxUploadBytesPerSecond': settings.maxUploadBytesPerSecond,
    'maxActiveDownloads': settings.maxActiveDownloads,
    'maxActiveSeeds': settings.maxActiveSeeds,
    'maxConnections': settings.maxConnections,
    'seedRatioLimit': settings.seedRatioLimit,
    'seedTimeLimitMinutes': settings.seedTimeLimitMinutes,
    'seedingMode': settings.seedingMode.name,
    'torrentPort': settings.torrentPort,
    'encryptionMode': settings.encryptionMode.name,
    'anonymousMode': settings.anonymousMode,
    'enableIncomingTcp': settings.enableIncomingTcp,
    'enableIncomingUtp': settings.enableIncomingUtp,
    'enableOutgoingTcp': settings.enableOutgoingTcp,
    'enableOutgoingUtp': settings.enableOutgoingUtp,
    'enableDht': settings.enableDht,
    'enableLsd': settings.enableLsd,
    'enableUpnp': settings.enableUpnp,
    'enableNatPmp': settings.enableNatPmp,
    'proxyMode': settings.proxyMode.name,
    'proxyHost': settings.proxyHost,
    'proxyPort': settings.proxyPort,
    'proxyUsername': settings.proxyUsername,
    'proxyPassword': settings.proxyPassword,
  };

  static TorrentPreferences decodeTorrentSettings(Map<Object?, Object?> map) {
    return TorrentPreferences(
      maxDownloadBytesPerSecond: _int(map['maxDownloadBytesPerSecond']),
      maxUploadBytesPerSecond: _int(map['maxUploadBytesPerSecond']),
      maxActiveDownloads: _queueLimit(map['maxActiveDownloads'], 1),
      maxActiveSeeds: _queueLimit(map['maxActiveSeeds'], 5),
      maxConnections: _positiveInt(map['maxConnections'], 200),
      seedRatioLimit: _nonNegativeInt(map['seedRatioLimit'], 200),
      seedTimeLimitMinutes: _nonNegativeInt(
        map['seedTimeLimitMinutes'],
        24 * 60,
      ),
      seedingMode: _enum(
        TorrentSeedingMode.values,
        map['seedingMode'],
        TorrentSeedingMode.untilTarget,
      ),
      torrentPort: _port(map['torrentPort'], 6881),
      encryptionMode: _enum(
        TorrentEncryptionMode.values,
        map['encryptionMode'],
        TorrentEncryptionMode.enabled,
      ),
      anonymousMode: _bool(map['anonymousMode'], false),
      enableIncomingTcp: _bool(map['enableIncomingTcp'], true),
      enableIncomingUtp: _bool(map['enableIncomingUtp'], true),
      enableOutgoingTcp: _bool(map['enableOutgoingTcp'], true),
      enableOutgoingUtp: _bool(map['enableOutgoingUtp'], true),
      enableDht: _bool(map['enableDht'], true),
      enableLsd: _bool(map['enableLsd'], true),
      enableUpnp: _bool(map['enableUpnp'], true),
      enableNatPmp: _bool(map['enableNatPmp'], true),
      proxyMode: _enum(
        TorrentProxyMode.values,
        map['proxyMode'],
        TorrentProxyMode.none,
      ),
      proxyHost: _string(map['proxyHost']),
      proxyPort: _port(map['proxyPort'], 0),
      proxyUsername: _string(map['proxyUsername']),
      proxyPassword: _string(map['proxyPassword']),
    );
  }
}

Map<Object?, Object?> _map(Object? value) =>
    value is Map ? value.cast<Object?, Object?>() : const {};

List<Object?> _list(Object? value) =>
    value is List ? value.cast<Object?>() : const [];

String _string(Object? value) => value is String ? value : '';

String? _stringOrNull(Object? value) => value is String ? value : null;

int _int(Object? value) => value is int ? value : 0;

int? _nullableInt(Object? value) => value is int ? value : null;

double _double(Object? value) => value is num ? value.toDouble() : 0;

int _nonNegativeInt(Object? value, int fallback) {
  final parsed = value is int ? value : fallback;
  return parsed < 0 ? fallback : parsed;
}

int _queueLimit(Object? value, int fallback) {
  final parsed = _int(value);
  return parsed < -1 ? fallback : parsed;
}

int _positiveInt(Object? value, int fallback) {
  final parsed = value is int ? value : fallback;
  return parsed <= 0 ? fallback : parsed;
}

int _port(Object? value, int fallback) {
  final parsed = value is int ? value : fallback;
  return parsed < 0 || parsed > 65535 ? fallback : parsed;
}

T _enum<T extends Enum>(List<T> values, Object? value, T fallback) {
  if (value is! String) return fallback;
  for (final candidate in values) {
    if (candidate.name == value) return candidate;
  }
  return fallback;
}

bool _bool(Object? value, bool fallback) => value is bool ? value : fallback;

List<String> _stringList(Object? value) =>
    _list(value).whereType<String>().toList();

List<int> _intList(Object? value) => _list(value).whereType<int>().toList();

Map<int, String> _intStringMap(Object? value) {
  if (value is! Map) return const {};
  return {
    for (final entry in value.entries)
      if (int.tryParse(entry.key.toString()) != null)
        int.parse(entry.key.toString()): entry.value.toString(),
  };
}

Map<String, dynamic> _decodeHeaders(String encoded) {
  final decoded = jsonDecode(encoded);
  if (decoded is! Map) return const {};
  return decoded.cast<String, dynamic>();
}

T _enumValue<T extends Enum>(List<T> values, Object? value, T fallback) {
  if (value is! String) return fallback;
  for (final candidate in values) {
    if (candidate.name == value) return candidate;
  }
  return fallback;
}
