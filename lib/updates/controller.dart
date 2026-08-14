import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:pub_semver/pub_semver.dart';
import 'package:senpwai/settings/notifier.dart';
import 'package:senpwai/shared/log.dart';
import 'package:senpwai/shared/persistence/app_persistence.dart';
import 'package:senpwai/updates/downloader.dart';
import 'package:senpwai/updates/manifest_repository.dart';
import 'package:senpwai/updates/macos_update_bridge.dart';
import 'package:senpwai/updates/models.dart';
import 'package:senpwai/updates/platform_installer.dart';
import 'package:senpwai/updates/update_repository.dart';

final _log = Logger('senpwai.updates');

class UpdateController extends Notifier<UpdateState> {
  static final provider = NotifierProvider<UpdateController, UpdateState>(
    UpdateController.new,
  );

  late final UpdateRepository _repository;
  late final UpdateManifestRepository _manifestRepository;
  late final UpdatePlatformInstaller _installer;
  final UpdateDownloader _downloader = UpdateDownloader();
  final MacOsUpdateBridge _macOsBridge = const MacOsUpdateBridge();
  StreamSubscription<Map<String, Object?>>? _macOsSubscription;
  bool _initialized = false;
  bool _busy = false;

  @override
  UpdateState build() {
    _repository = UpdateRepository(paths: AppPersistence.paths);
    _manifestRepository = UpdateManifestRepository(paths: AppPersistence.paths);
    _installer = UpdatePlatformInstaller.current();
    ref.listen(
      AppSettingsNotifier.provider.select(
        (settings) => settings.updates.automaticallyDownload,
      ),
      (_, enabled) {
        if (Platform.isMacOS) {
          unawaited(_macOsBridge.setAutomaticallyDownload(enabled));
          return;
        }
        if (enabled && state.phase == UpdatePhase.available) {
          unawaited(download());
        }
      },
    );
    Future.microtask(_initialize);
    return const UpdateState();
  }

  Future<void> _initialize() async {
    if (_initialized) return;
    _initialized = true;
    final packageInfo = await PackageInfo.fromPlatform();
    final currentBuild = int.tryParse(packageInfo.buildNumber) ?? 0;
    state = state.copyWith(
      currentVersion: packageInfo.version,
      currentBuild: currentBuild,
    );

    if (Platform.isMacOS) {
      _macOsSubscription = _macOsBridge.events.listen(_handleMacOsEvent);
      ref.onDispose(() => _macOsSubscription?.cancel());
      await _macOsBridge.start(
        automaticallyDownload: ref
            .read(AppSettingsNotifier.provider)
            .updates
            .automaticallyDownload,
      );
      return;
    }

    final prepared = await _repository.loadPrepared();
    if (prepared != null) {
      final currentVersion = Version.parse(packageInfo.version);
      final preparedVersion = Version.parse(prepared.version);
      final alreadyInstalled =
          currentVersion > preparedVersion ||
          (currentVersion == preparedVersion && currentBuild >= prepared.build);
      if (alreadyInstalled) {
        await _repository.clearPrepared();
        final file = File(prepared.filePath);
        if (await file.exists()) await file.delete();
      } else {
        final release = AppRelease(
          version: preparedVersion,
          build: prepared.build,
          channel: 'stable',
          mandatory: false,
          notes: '',
          artifacts: [prepared.artifact],
        );
        state = state.copyWith(
          phase: UpdatePhase.ready,
          release: release,
          artifact: prepared.artifact,
          bytesReceived: prepared.artifact.sizeBytes,
          totalBytes: prepared.artifact.sizeBytes,
          clearError: true,
        );
        return;
      }
    }
    await check();
  }

  Future<void> check({bool userInitiated = false}) async {
    if (Platform.isMacOS) {
      state = state.copyWith(phase: UpdatePhase.checking, clearError: true);
      try {
        await _macOsBridge.check();
      } catch (error) {
        state = state.copyWith(
          phase: UpdatePhase.failed,
          error: _friendlyError(error),
        );
      }
      return;
    }
    if (_busy || state.phase == UpdatePhase.downloading) return;
    _busy = true;
    state = state.copyWith(phase: UpdatePhase.checking, clearError: true);
    try {
      final manifest = await _manifestRepository.fetch();
      final candidate = manifest.latestCompatible(
        currentVersion: state.currentVersion,
        currentBuild: state.currentBuild,
      );
      if (candidate == null) {
        state = state.copyWith(
          phase: UpdatePhase.idle,
          bytesReceived: 0,
          totalBytes: 0,
          clearError: true,
        );
        return;
      }
      state = state.copyWith(
        phase: UpdatePhase.available,
        release: candidate.release,
        artifact: candidate.artifact,
        bytesReceived: 0,
        totalBytes: candidate.artifact.sizeBytes,
        clearError: true,
      );
      if (ref
          .read(AppSettingsNotifier.provider)
          .updates
          .automaticallyDownload) {
        Future.microtask(download);
      }
    } catch (error, stackTrace) {
      _log.warningWithMetadata(
        'Could not check for app updates',
        metadata: {
          'error': error.toString(),
          'stackTrace': stackTrace.toString(),
        },
      );
      state = state.copyWith(
        phase: userInitiated ? UpdatePhase.failed : UpdatePhase.idle,
        error: userInitiated ? _friendlyError(error) : null,
        clearError: !userInitiated,
      );
    } finally {
      _busy = false;
    }
  }

  Future<void> download() async {
    if (Platform.isMacOS) {
      await _macOsBridge.download();
      return;
    }
    if (_busy || state.phase != UpdatePhase.available) return;
    final release = state.release;
    final artifact = state.artifact;
    if (release == null || artifact == null) return;
    _busy = true;
    final partialFile = _repository.partialArtifactFile(artifact);
    final artifactFile = _repository.artifactFile(artifact);
    state = state.copyWith(
      phase: UpdatePhase.downloading,
      bytesReceived: 0,
      totalBytes: artifact.sizeBytes,
      clearError: true,
    );
    try {
      await _downloader.download(
        artifact: artifact,
        destination: partialFile,
        onProgress: (received, total) {
          state = state.copyWith(bytesReceived: received, totalBytes: total);
        },
      );
      state = state.copyWith(phase: UpdatePhase.verifying);
      await _downloader.verify(partialFile, artifact);
      if (await artifactFile.exists()) await artifactFile.delete();
      await partialFile.rename(artifactFile.path);
      var prepared = PreparedUpdate(
        version: release.version.toString(),
        build: release.build,
        artifact: artifact,
        filePath: artifactFile.path,
        platformPrepared: false,
      );
      await _repository.savePrepared(prepared);

      state = state.copyWith(phase: UpdatePhase.preparing);
      final platformPrepared = await _installer.prepare(artifactFile, release);
      prepared = prepared.copyWith(platformPrepared: platformPrepared);
      await _repository.savePrepared(prepared);
      state = state.copyWith(
        phase: UpdatePhase.ready,
        bytesReceived: artifact.sizeBytes,
        totalBytes: artifact.sizeBytes,
        clearError: true,
      );
    } on UpdateDownloadCancelled {
      if (await partialFile.exists()) await partialFile.delete();
      state = state.copyWith(
        phase: UpdatePhase.available,
        bytesReceived: 0,
        totalBytes: artifact.sizeBytes,
        clearError: true,
      );
    } catch (error, stackTrace) {
      _log.severeWithMetadata(
        'Could not prepare app update',
        metadata: {
          'error': error.toString(),
          'stackTrace': stackTrace.toString(),
        },
      );
      state = state.copyWith(
        phase: UpdatePhase.failed,
        error: _friendlyError(error),
      );
    } finally {
      _busy = false;
    }
  }

  void cancelDownload() {
    if (Platform.isMacOS) {
      unawaited(_macOsBridge.cancelDownload());
      return;
    }
    if (state.phase == UpdatePhase.downloading) _downloader.cancel();
  }

  Future<UpdateInstallDisposition?> installAndRestart() async {
    if (Platform.isMacOS) {
      state = state.copyWith(phase: UpdatePhase.installing, clearError: true);
      try {
        await _macOsBridge.installAndRestart();
        return UpdateInstallDisposition.applicationWillRestart;
      } catch (error) {
        state = state.copyWith(
          phase: UpdatePhase.failed,
          error: _friendlyError(error),
        );
        return null;
      }
    }
    if (_busy || state.phase != UpdatePhase.ready) return null;
    final release = state.release;
    final artifact = state.artifact;
    if (release == null || artifact == null) return null;
    final prepared = await _repository.loadPrepared();
    if (prepared == null) {
      state = state.copyWith(
        phase: UpdatePhase.failed,
        error: 'The prepared update is missing. Download it again.',
      );
      return null;
    }
    _busy = true;
    state = state.copyWith(phase: UpdatePhase.installing, clearError: true);
    try {
      final disposition = await _installer.installAndRestart(
        File(prepared.filePath),
        release,
      );
      if (disposition == UpdateInstallDisposition.externalInstallerOpened) {
        state = state.copyWith(phase: UpdatePhase.ready);
      }
      return disposition;
    } catch (error, stackTrace) {
      _log.severeWithMetadata(
        'Could not install app update',
        metadata: {
          'error': error.toString(),
          'stackTrace': stackTrace.toString(),
        },
      );
      state = state.copyWith(
        phase: UpdatePhase.failed,
        error: _friendlyError(error),
      );
      return null;
    } finally {
      _busy = false;
    }
  }

  Future<void> retry() async {
    if (state.release != null && state.artifact != null) {
      state = state.copyWith(phase: UpdatePhase.available, clearError: true);
      await download();
      return;
    }
    await check(userInitiated: true);
  }

  String _friendlyError(Object error) {
    if (error is FileSystemException && error.message.isNotEmpty) {
      return error.message;
    }
    return error.toString().replaceFirst(RegExp(r'^Exception:\s*'), '');
  }

  void _handleMacOsEvent(Map<String, Object?> event) {
    final phase = switch (event['phase']) {
      'checking' => UpdatePhase.checking,
      'available' => UpdatePhase.available,
      'downloading' => UpdatePhase.downloading,
      'verifying' => UpdatePhase.verifying,
      'preparing' => UpdatePhase.preparing,
      'ready' => UpdatePhase.ready,
      'installing' => UpdatePhase.installing,
      'failed' => UpdatePhase.failed,
      _ => UpdatePhase.idle,
    };
    final version = event['version'] as String?;
    final build = int.tryParse(event['build']?.toString() ?? '') ?? 0;
    final release = version == null
        ? state.release
        : AppRelease(
            version: Version.parse(version),
            build: build,
            channel: 'stable',
            mandatory: false,
            notes: event['notes'] as String? ?? '',
            artifacts: const [],
          );
    state = state.copyWith(
      phase: phase,
      release: release,
      bytesReceived: (event['bytesReceived'] as num?)?.toInt() ?? 0,
      totalBytes: (event['totalBytes'] as num?)?.toInt() ?? 0,
      error: event['error'] as String?,
      clearError: event['error'] == null,
    );
  }
}
