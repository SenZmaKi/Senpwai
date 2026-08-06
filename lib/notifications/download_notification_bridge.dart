import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:senpwai/downloads/manager.dart';
import 'package:senpwai/downloads/models.dart';
import 'package:senpwai/notifications/app_notification_service.dart';
import 'package:senpwai/settings/settings.dart';
import 'package:senpwai/ui/pages/settings_page/settings_formatters.dart';
import 'package:windows_taskbar/windows_taskbar.dart';

class DownloadNotificationBridge extends ConsumerStatefulWidget {
  final Widget child;
  final VoidCallback onOpenDownloads;

  const DownloadNotificationBridge({
    required this.child,
    required this.onOpenDownloads,
    super.key,
  });

  @override
  ConsumerState<DownloadNotificationBridge> createState() =>
      _DownloadNotificationBridgeState();
}

class _DownloadNotificationBridgeState
    extends ConsumerState<DownloadNotificationBridge> {
  static const _minimumProgressInterval = Duration(seconds: 1);

  final Map<String, DateTime> _lastProgressUpdates = {};
  final Map<String, DownloadQueueStatus> _lastItemStatuses = {};
  final Set<String> _terminalBatchesNotified = {};
  final Set<int> _activeProgressNotificationIds = {};
  StreamSubscription<NotificationActionEvent>? _actionSubscription;
  int? _lastTaskbarMode;
  int? _lastTaskbarCompleted;
  int? _lastTaskbarTotal;
  DateTime? _lastTaskbarProgressUpdate;

  @override
  void initState() {
    super.initState();
    _actionSubscription = AppNotificationService.instance.actionStream.listen(
      _handleNotificationAction,
    );
    for (final event
        in AppNotificationService.instance.takePendingActionEvents()) {
      Future.microtask(() => _handleNotificationAction(event));
    }
  }

  @override
  void dispose() {
    if (Platform.isWindows) {
      unawaited(_setWindowsTaskbarMode(TaskbarProgressMode.noProgress));
    }
    unawaited(_actionSubscription?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(DownloadManagerNotifier.provider, _handleDownloadStateChanged);
    ref.listen(AppSettingsNotifier.provider.select((s) => s.notifications), (
      _,
      next,
    ) {
      if (!next.enabled) _cancelAllProgressNotifications();
    });
    return widget.child;
  }

  void _handleDownloadStateChanged(
    DownloadManagerState? previous,
    DownloadManagerState next,
  ) {
    _updateWindowsTaskbarProgress(next);
    final notificationSettings = ref.read(
      AppSettingsNotifier.provider.select((s) => s.notifications),
    );
    if (!notificationSettings.enabled) {
      _cancelAllProgressNotifications();
      return;
    }
    if (Platform.isAndroid) return;
    _handleRemovedItems(next);
    final desiredProgressIds = switch (notificationSettings.downloadStyle) {
      DownloadNotificationStyle.batchCompletion => _handleBatchSummary(
        previous,
        next,
        notifyTerminalBatches: true,
      ),
      DownloadNotificationStyle.episodeCompletion => _handleBatchSummary(
        previous,
        next,
        notifyTerminalBatches: false,
      ),
    };
    if (notificationSettings.downloadStyle ==
        DownloadNotificationStyle.episodeCompletion) {
      _handleTerminalItems(next);
    }
    _cancelObsoleteProgressNotifications(desiredProgressIds);
  }

  Set<int> _handleBatchSummary(
    DownloadManagerState? previous,
    DownloadManagerState next, {
    required bool notifyTerminalBatches,
  }) {
    if (notifyTerminalBatches) {
      _handleTerminalBatches(previous, next);
    }

    final activeBatchId = next.activeBatchId;
    var batch = activeBatchId == null ? null : _batchById(next, activeBatchId);
    if (batch == null) {
      for (final candidate in next.batches) {
        if (_itemsForBatch(
          next,
          candidate,
        ).any((item) => item.isSeedingPhase)) {
          batch = candidate;
          break;
        }
      }
    }
    if (batch == null) return const {};

    final items = _itemsForBatch(next, batch);
    if (items.isEmpty || items.every((item) => item.status.isTerminal)) {
      return const {};
    }

    final id = _batchNotificationId(batch.id);
    _maybeShowBatchProgress(id, batch, items);
    return {id};
  }

  void _handleTerminalItems(DownloadManagerState next) {
    for (final item in next.items) {
      _handleTerminalItem(next, item);
    }
  }

  void _handleTerminalItem(DownloadManagerState state, DownloadQueueItem item) {
    final previousStatus = _lastItemStatuses[item.id];
    _lastItemStatuses[item.id] = item.status;
    if (!item.status.isTerminal) return;
    if (previousStatus == item.status) return;

    _lastProgressUpdates.remove(item.id);
    final id = _downloadNotificationId(item.id);
    _activeProgressNotificationIds.remove(id);
    unawaitedNotification(
      _replaceProgressWithFinalNotification(
        id,
        item,
        _batchById(state, item.batchId),
      ),
    );
  }

  void _handleRemovedItems(DownloadManagerState next) {
    final visibleIds = {for (final item in next.items) item.id};
    for (final id in _lastItemStatuses.keys.toList()) {
      if (visibleIds.contains(id)) continue;
      _lastItemStatuses.remove(id);
      _lastProgressUpdates.remove(id);
      final notificationId = _downloadNotificationId(id);
      _activeProgressNotificationIds.remove(notificationId);
      unawaitedNotification(
        AppNotificationService.instance.cancel(notificationId),
      );
    }
  }

  void _handleTerminalBatches(
    DownloadManagerState? previous,
    DownloadManagerState next,
  ) {
    final previousBatches = previous?.batches ?? const <DownloadBatchQueue>[];
    if (previousBatches.isEmpty) return;

    final activeBatchIds = {for (final batch in next.batches) batch.id};
    for (final batch in previousBatches) {
      if (activeBatchIds.contains(batch.id)) continue;
      if (!_terminalBatchesNotified.add(batch.id)) continue;

      final items = _itemsForBatch(next, batch);
      if (items.isEmpty) continue;
      final failed = items
          .where((item) => item.status == DownloadQueueStatus.failed)
          .length;
      final cancelled = items
          .where((item) => item.status == DownloadQueueStatus.cancelled)
          .length;
      final completed = items
          .where((item) => item.status == DownloadQueueStatus.completed)
          .length;
      final id = _batchNotificationId(batch.id);
      _activeProgressNotificationIds.remove(id);
      final hasIssue = failed > 0 || cancelled > 0;
      unawaitedNotification(
        AppNotificationService.instance.showUserEvent(
          id: id,
          title: batch.title,
          body: hasIssue
              ? '${failed > 0 ? 'Batch finished with errors' : 'Batch cancelled'} · $completed completed · $failed failed · $cancelled cancelled'
              : 'Batch completed',
          level: hasIssue ? UserEventLevel.warning : UserEventLevel.info,
        ),
      );
    }
  }

  void _maybeShowBatchProgress(
    int id,
    DownloadBatchQueue batch,
    List<DownloadQueueItem> items,
  ) {
    final now = DateTime.now();
    final lastUpdate = _lastProgressUpdates[batch.id];
    if (lastUpdate != null &&
        now.difference(lastUpdate) < _minimumProgressInterval) {
      return;
    }

    _lastProgressUpdates[batch.id] = now;
    _activeProgressNotificationIds.add(id);
    final totalBytes = items.fold<int>(0, (sum, item) => sum + item.totalBytes);
    final downloadedBytes = items.fold<int>(
      0,
      (sum, item) => sum + item.downloadedBytes,
    );
    final bytesPerSecond = items.fold<double>(
      0,
      (sum, item) => sum + item.bytesPerSecond,
    );
    final progress = totalBytes <= 0 ? 0.0 : downloadedBytes / totalBytes;
    final activeItems = items.where((item) => !item.status.isTerminal).toList();
    final paused =
        activeItems.isNotEmpty &&
        activeItems.every((item) => item.status == DownloadQueueStatus.paused);
    final seeding =
        activeItems.isNotEmpty &&
        activeItems.every((item) => item.isSeedingPhase);

    unawaitedNotification(
      AppNotificationService.instance.showDownloadProgress(
        id: id,
        title: batch.title,
        body: _batchProgressBody(
          items: items,
          progress: progress,
          downloadedBytes: downloadedBytes,
          totalBytes: totalBytes,
          bytesPerSecond: bytesPerSecond,
          paused: paused,
          seeding: seeding,
        ),
        progress: progress,
        paused: paused,
        targetType: NotificationActionTargetType.batch,
        targetId: batch.id,
      ),
    );
  }

  Future<void> _replaceProgressWithFinalNotification(
    int id,
    DownloadQueueItem item,
    DownloadBatchQueue? batch,
  ) async {
    await AppNotificationService.instance.cancel(id);
    switch (item.status) {
      case DownloadQueueStatus.completed:
        await AppNotificationService.instance.showDownloadCompleted(
          id: id,
          title: item.displayTitle,
          body: _terminalEpisodeBody(item, batch),
        );
      case DownloadQueueStatus.failed:
        await AppNotificationService.instance.showDownloadFailed(
          id: id,
          title: item.displayTitle,
          body: _terminalEpisodeBody(item, batch),
        );
      case DownloadQueueStatus.cancelled:
        await AppNotificationService.instance.showUserEvent(
          id: id,
          title: item.displayTitle,
          body: _terminalEpisodeBody(item, batch),
          level: UserEventLevel.warning,
        );
      case DownloadQueueStatus.preparing ||
          DownloadQueueStatus.queued ||
          DownloadQueueStatus.downloading ||
          DownloadQueueStatus.seeding ||
          DownloadQueueStatus.paused:
        break;
    }
  }

  void _handleNotificationAction(NotificationActionEvent event) {
    final manager = ref.read(DownloadManagerNotifier.provider.notifier);
    switch (event.kind) {
      case NotificationActionKind.open:
        widget.onOpenDownloads();
        return;
      case NotificationActionKind.pause:
        if (event.targetId == null) return;
        if (event.targetType == NotificationActionTargetType.batch) {
          unawaited(manager.pauseBatch(event.targetId!));
        } else {
          unawaited(manager.pause(event.targetId!));
        }
      case NotificationActionKind.resume:
        if (event.targetId == null) return;
        if (event.targetType == NotificationActionTargetType.batch) {
          unawaited(manager.resumeBatch(event.targetId!));
        } else {
          unawaited(manager.resume(event.targetId!));
        }
      case NotificationActionKind.cancel:
        if (event.targetId == null) return;
        if (event.targetType == NotificationActionTargetType.batch) {
          unawaited(manager.cancelBatch(event.targetId!));
        } else {
          unawaited(manager.cancel(event.targetId!));
        }
    }
  }

  String _batchProgressBody({
    required List<DownloadQueueItem> items,
    required double progress,
    required int downloadedBytes,
    required int totalBytes,
    required double bytesPerSecond,
    required bool paused,
    required bool seeding,
  }) {
    final activeCount = items.where((item) => !item.status.isTerminal).length;
    final doneCount = items.length - activeCount;
    final percent = (progress * 100).round().clamp(0, 100);
    final downloaded = formatBytes(downloadedBytes);
    final total = totalBytes > 0 ? formatBytes(totalBytes) : 'Unknown';
    final countText = doneCount > 0
        ? '$activeCount active · $doneCount done'
        : '$activeCount active';
    if (paused) {
      final label = seeding ? 'Seeding paused' : 'Paused';
      return '$label · $countText · $percent% · $downloaded / $total';
    }
    if (seeding) {
      return 'Seeding · $countText · $percent% · $downloaded / $total';
    }
    final speed = bytesPerSecond <= 0
        ? 'Starting...'
        : '${formatBytes(bytesPerSecond.round())}/s';
    return '$countText · $percent% · $downloaded / $total · $speed';
  }

  String _terminalEpisodeBody(
    DownloadQueueItem item,
    DownloadBatchQueue? batch,
  ) {
    final status = switch (item.status) {
      DownloadQueueStatus.completed => 'Download completed',
      DownloadQueueStatus.failed => item.errorTitle ?? 'Download failed',
      DownloadQueueStatus.cancelled => 'Download cancelled',
      _ => 'Download updated',
    };
    final parts = [
      status,
      if (batch != null) batch.title,
      if (item.status == DownloadQueueStatus.failed &&
          item.errorDescription != null)
        item.errorDescription!,
    ];
    return parts.join(' · ');
  }

  void _cancelAllProgressNotifications() {
    _cancelObsoleteProgressNotifications(const {});
  }

  void _cancelObsoleteProgressNotifications(Set<int> desiredIds) {
    for (final id in _activeProgressNotificationIds.toList()) {
      if (desiredIds.contains(id)) continue;
      _activeProgressNotificationIds.remove(id);
      unawaitedNotification(AppNotificationService.instance.cancel(id));
    }
  }

  void _updateWindowsTaskbarProgress(DownloadManagerState state) {
    if (!Platform.isWindows) return;
    unawaited(_setWindowsTaskbarProgress(state).catchError((_) {}));
  }

  Future<void> _setWindowsTaskbarProgress(DownloadManagerState state) async {
    final activeBatchId = state.activeBatchId;
    final activeBatch = activeBatchId == null
        ? null
        : _batchById(state, activeBatchId);
    if (activeBatch == null) {
      await _setWindowsTaskbarMode(TaskbarProgressMode.noProgress);
      return;
    }

    final items = _itemsForBatch(state, activeBatch);
    final activeItems = items.where((item) => !item.status.isTerminal).toList();
    if (items.isEmpty || activeItems.isEmpty) {
      await _setWindowsTaskbarMode(TaskbarProgressMode.noProgress);
      return;
    }

    final totalBytes = items.fold<int>(0, (sum, item) => sum + item.totalBytes);
    final downloadedBytes = items.fold<int>(
      0,
      (sum, item) => sum + item.downloadedBytes,
    );
    final mode =
        activeItems.every((item) => item.status == DownloadQueueStatus.paused)
        ? TaskbarProgressMode.paused
        : TaskbarProgressMode.normal;

    if (totalBytes <= 0) {
      await _setWindowsTaskbarMode(TaskbarProgressMode.indeterminate);
      return;
    }

    final completed = downloadedBytes.clamp(0, totalBytes);
    if (_lastTaskbarMode == mode &&
        _lastTaskbarCompleted == completed &&
        _lastTaskbarTotal == totalBytes) {
      return;
    }

    final now = DateTime.now();
    final lastUpdate = _lastTaskbarProgressUpdate;
    if (_lastTaskbarMode == mode &&
        lastUpdate != null &&
        now.difference(lastUpdate) < _minimumProgressInterval) {
      return;
    }
    _lastTaskbarProgressUpdate = now;

    await WindowsTaskbar.setProgress(completed, totalBytes);
    await WindowsTaskbar.setProgressMode(mode);
    _lastTaskbarMode = mode;
    _lastTaskbarCompleted = completed;
    _lastTaskbarTotal = totalBytes;
  }

  Future<void> _setWindowsTaskbarMode(int mode) async {
    if (_lastTaskbarMode == mode &&
        _lastTaskbarCompleted == null &&
        _lastTaskbarTotal == null) {
      return;
    }
    await WindowsTaskbar.setProgressMode(mode);
    _lastTaskbarMode = mode;
    _lastTaskbarCompleted = null;
    _lastTaskbarTotal = null;
    _lastTaskbarProgressUpdate = null;
  }

  DownloadBatchQueue? _batchById(DownloadManagerState state, String id) {
    for (final batch in state.batches) {
      if (batch.id == id) return batch;
    }
    return null;
  }

  List<DownloadQueueItem> _itemsForBatch(
    DownloadManagerState state,
    DownloadBatchQueue batch,
  ) {
    final byId = {for (final item in state.items) item.id: item};
    return [
      for (final id in batch.itemIds)
        if (byId[id] != null) byId[id]!,
    ];
  }

  int _downloadNotificationId(String downloadId) =>
      _stableNotificationId('download:$downloadId');

  int _batchNotificationId(String batchId) =>
      _stableNotificationId('batch:$batchId');

  int _stableNotificationId(String value) {
    var hash = 0x811c9dc5;
    for (final codeUnit in value.codeUnits) {
      hash ^= codeUnit;
      hash = (hash * 0x01000193) & 0x7fffffff;
    }
    return hash;
  }
}
