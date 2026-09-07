import 'dart:async';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:senpwai/shared/net/download/download.dart';
import 'package:senpwai/shared/net/download/download_state.dart';
import 'package:senpwai/shared/net/download/shared.dart';
import 'package:senpwai/shared/persistence/app_paths.dart';
import 'package:senpwai/updates/models.dart';
import 'package:senpwai/updates/update_repository.dart';

enum UpdateTransferPhase {
  idle,
  downloading,
  verifying,
  completed,
  cancelled,
  failed,
}

class UpdateTransferState {
  final UpdateTransferPhase phase;
  final AppRelease? release;
  final UpdateArtifact? artifact;
  final int bytesReceived;
  final int totalBytes;
  final String? error;

  const UpdateTransferState({
    this.phase = UpdateTransferPhase.idle,
    this.release,
    this.artifact,
    this.bytesReceived = 0,
    this.totalBytes = 0,
    this.error,
  });

  bool get isActive =>
      phase == UpdateTransferPhase.downloading ||
      phase == UpdateTransferPhase.verifying;

  Map<String, Object?> toJson() => {
    'phase': phase.name,
    'release': release?.toJson(),
    'artifact': artifact?.toJson(),
    'bytesReceived': bytesReceived,
    'totalBytes': totalBytes,
    'error': error,
  };

  factory UpdateTransferState.fromJson(Map<Object?, Object?> json) {
    final phaseName = json['phase'];
    final releaseJson = json['release'];
    final artifactJson = json['artifact'];
    return UpdateTransferState(
      phase: UpdateTransferPhase.values.firstWhere(
        (value) => value.name == phaseName,
        orElse: () => UpdateTransferPhase.idle,
      ),
      release: releaseJson is Map
          ? AppRelease.fromJson(Map<String, dynamic>.from(releaseJson))
          : null,
      artifact: artifactJson is Map
          ? UpdateArtifact.fromJson(Map<String, dynamic>.from(artifactJson))
          : null,
      bytesReceived: json['bytesReceived'] as int? ?? 0,
      totalBytes: json['totalBytes'] as int? ?? 0,
      error: json['error'] as String?,
    );
  }
}

class UpdateTransfer {
  final AppPaths paths;
  final Dio dio;
  final _stateController = StreamController<UpdateTransferState>.broadcast();
  Download? _download;
  Future<void>? _activeFuture;
  var _state = const UpdateTransferState();

  UpdateTransfer({required this.paths, required this.dio});

  UpdateTransferState get currentState => _state;
  Stream<UpdateTransferState> get stateStream => _stateController.stream;

  Future<void> download(AppRelease release, UpdateArtifact artifact) async {
    if (_state.isActive) {
      if (_state.release?.version == release.version &&
          _state.release?.build == release.build) {
        final activeFuture = _activeFuture;
        if (activeFuture != null) return activeFuture;
        return;
      }
      throw StateError('Another update download is already running.');
    }

    final operation = _downloadInternal(release, artifact);
    _activeFuture = operation;
    try {
      await operation;
    } finally {
      if (identical(_activeFuture, operation)) _activeFuture = null;
    }
  }

  Future<void> _downloadInternal(
    AppRelease release,
    UpdateArtifact artifact,
  ) async {
    final repository = UpdateRepository(paths: paths);
    final partialFile = repository.partialArtifactFile(artifact);
    final artifactFile = repository.artifactFile(artifact);
    var received = 0;
    var lastProgressAt = DateTime.fromMillisecondsSinceEpoch(0);
    _publish(
      UpdateTransferState(
        phase: UpdateTransferPhase.downloading,
        release: release,
        artifact: artifact,
        totalBytes: artifact.sizeBytes,
      ),
    );

    final download = Download(
      params: DownloadParams(
        url: artifact.url.toString(),
        targetFile: partialFile,
        sizeBytes: artifact.sizeBytes,
        numberOfParts: _recommendedPartCount(artifact.sizeBytes),
        headers: const {'Cache-Control': 'no-cache'},
      ),
      dio: dio,
    );
    _download = download;
    final progressSubscription = download.state.progressStream.listen((event) {
      received = (received + event.bytesDownloaded).clamp(
        0,
        artifact.sizeBytes,
      );
      final now = DateTime.now();
      if (received != artifact.sizeBytes &&
          now.difference(lastProgressAt) < const Duration(milliseconds: 100)) {
        return;
      }
      lastProgressAt = now;
      _publish(
        UpdateTransferState(
          phase: UpdateTransferPhase.downloading,
          release: release,
          artifact: artifact,
          bytesReceived: received,
          totalBytes: artifact.sizeBytes,
        ),
      );
    });

    try {
      await download.startAndWait();
      if (download.state.status == DownloadStatus.cancelled) {
        _publish(
          UpdateTransferState(
            phase: UpdateTransferPhase.cancelled,
            release: release,
            artifact: artifact,
            totalBytes: artifact.sizeBytes,
          ),
        );
        return;
      }
      if (download.state.status != DownloadStatus.completed) {
        throw StateError('The update download did not complete.');
      }
      _publish(
        UpdateTransferState(
          phase: UpdateTransferPhase.verifying,
          release: release,
          artifact: artifact,
          bytesReceived: artifact.sizeBytes,
          totalBytes: artifact.sizeBytes,
        ),
      );
      await _verify(partialFile, artifact);
      if (await artifactFile.exists()) await artifactFile.delete();
      await partialFile.rename(artifactFile.path);
      await repository.savePrepared(
        PreparedUpdate(
          version: release.version.toString(),
          build: release.build,
          artifact: artifact,
          filePath: artifactFile.path,
          platformPrepared: false,
        ),
      );
      _publish(
        UpdateTransferState(
          phase: UpdateTransferPhase.completed,
          release: release,
          artifact: artifact,
          bytesReceived: artifact.sizeBytes,
          totalBytes: artifact.sizeBytes,
        ),
      );
    } on Object catch (error) {
      _publish(
        UpdateTransferState(
          phase: UpdateTransferPhase.failed,
          release: release,
          artifact: artifact,
          bytesReceived: received,
          totalBytes: artifact.sizeBytes,
          error: '$error',
        ),
      );
      rethrow;
    } finally {
      await progressSubscription.cancel();
      if (identical(_download, download)) _download = null;
    }
  }

  Future<void> cancel() async => _download?.state.cancel();

  Future<void> dispose() async {
    await _download?.state.cancel();
    await _stateController.close();
  }

  void _publish(UpdateTransferState state) {
    _state = state;
    if (!_stateController.isClosed) _stateController.add(state);
  }

  static int _recommendedPartCount(int sizeBytes) {
    if (sizeBytes < 16 * 1024 * 1024) return 1;
    if (sizeBytes < 64 * 1024 * 1024) return 2;
    return 4;
  }

  static Future<void> _verify(File file, UpdateArtifact artifact) async {
    final size = await file.length();
    if (size != artifact.sizeBytes) {
      throw FormatException(
        'Update size mismatch: expected ${artifact.sizeBytes} bytes, received $size.',
      );
    }
    final digest = await sha256.bind(file.openRead()).first;
    if (digest.toString() != artifact.sha256) {
      throw const FormatException('Update checksum verification failed.');
    }
  }
}
