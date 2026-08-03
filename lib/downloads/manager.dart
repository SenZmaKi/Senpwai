import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:senpwai/downloads/android_foreground_runtime.dart';
import 'package:senpwai/downloads/in_process_runtime.dart';
import 'package:senpwai/downloads/isolate_runtime.dart';
import 'package:senpwai/downloads/models.dart';
import 'package:senpwai/settings/settings.dart';
import 'package:senpwai/shared/net/net.dart';
import 'package:senpwai/shared/persistence/app_persistence.dart';
import 'package:senpwai/ui/components/app.dart';
import 'package:senpwai/ui/components/toast.dart';

class DownloadManagerNotifier extends Notifier<DownloadManagerState> {
  static final provider =
      NotifierProvider<DownloadManagerNotifier, DownloadManagerState>(
        DownloadManagerNotifier.new,
      );

  late final DownloadRuntime _runtime;
  StreamSubscription<DownloadManagerState>? _stateSubscription;

  @override
  DownloadManagerState build() {
    final settings = ref.read(AppSettingsNotifier.provider);
    _runtime = Platform.isAndroid
        ? AndroidForegroundDownloadRuntime(
            initialMaxDownloadBytesPerSecond:
                settings.downloads.maxDownloadBytesPerSecond,
            downloadUserAgent: _downloadUserAgent,
            initialTorrentSettings: settings.torrent,
            initialNotificationSettings: settings.notifications,
            onError: _showGlobalError,
          )
        : DownloadIsolateRuntime(
            initialMaxDownloadBytesPerSecond:
                settings.downloads.maxDownloadBytesPerSecond,
            downloadUserAgent: _downloadUserAgent,
            initialTorrentSettings: settings.torrent,
            appDataRootPath: AppPersistence.paths.rootDirectory.path,
            onError: _showGlobalError,
          );
    _stateSubscription = _runtime.stateStream.listen((next) {
      state = next;
    });
    ref.listen(AppSettingsNotifier.provider.select((s) => s.torrent), (
      _,
      next,
    ) {
      _runtime.updateTorrentSettings(next);
    });
    ref.listen(
      AppSettingsNotifier.provider.select(
        (s) => s.downloads.maxDownloadBytesPerSecond,
      ),
      (_, next) {
        _runtime.updateHttpDownloadSettings(
          maxBytesPerSecond: next,
          userAgent: _downloadUserAgent,
        );
      },
    );
    ref.listen(AppSettingsNotifier.provider.select((s) => s.notifications), (
      _,
      next,
    ) {
      _runtime.updateNotificationSettings(next);
    });
    ref.onDispose(() {
      unawaited(_stateSubscription?.cancel());
      unawaited(_runtime.dispose());
    });
    return _runtime.currentState;
  }

  String get _downloadUserAgent =>
      GlobalDio.getInstance().options.headers['User-Agent']?.toString() ?? '';

  Future<EnqueuedDownloadsResult> enqueueBatch(PreparedDownloadBatch batch) {
    return _runtime.enqueueBatch(batch);
  }

  Future<void> pause(String id) => _runtime.pause(id);

  Future<void> resume(String id) => _runtime.resume(id);

  Future<void> cancel(String id) => _runtime.cancel(id);

  Future<void> pauseBatch(String batchId) => _runtime.pauseBatch(batchId);

  Future<void> resumeBatch(String batchId) => _runtime.resumeBatch(batchId);

  Future<void> cancelBatch(String batchId) => _runtime.cancelBatch(batchId);

  void reorder(int oldIndex, int newIndex) {
    _runtime.reorder(oldIndex, newIndex);
  }

  void reorderBatch(int oldIndex, int newIndex) {
    _runtime.reorderBatch(oldIndex, newIndex);
  }

  void reorderBatchItem(String batchId, int oldIndex, int newIndex) {
    _runtime.reorderBatchItem(batchId, oldIndex, newIndex);
  }

  void clearHistory() {
    _runtime.clearHistory();
  }

  void dismiss(String id) {
    _runtime.dismiss(id);
  }

  void seedMockDownloads() {
    if (!kDebugMode) return;
    _runtime.seedMockDownloads();
  }

  void _showGlobalError({
    required String title,
    required String description,
    String? copyPayload,
  }) {
    final context = App.navigatorKey.currentContext;
    if (context == null) return;
    AppToast.showError(
      context,
      title: title,
      description: description,
      copyPayload: copyPayload,
    );
  }
}
