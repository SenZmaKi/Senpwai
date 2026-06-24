import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:senpwai/downloads/manager.dart';
import 'package:senpwai/downloads/models.dart';
import 'package:senpwai/notifications/app_notification_service.dart';
import 'package:senpwai/settings/settings.dart';
import 'package:senpwai/shared/app_lifecycle.dart';
import 'package:senpwai/ui/pages/settings_page/settings_formatters.dart';

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
    ref.listen(AppLifecycleNotifier.provider, (_, next) {
      _onLifecycleChanged(next);
    });
    return widget.child;
  }

  void _handleDownloadStateChanged(
    DownloadManagerState? previous,
    DownloadManagerState next,
  ) {
    final notificationSettings = ref.read(
      AppSettingsNotifier.provider.select((s) => s.notifications),
    );
    if (!notificationSettings.enabled) {
      _cancelAllProgressNotifications();
      return;
    }
    if (!_shouldShowNotifications()) {
      _cancelAllProgressNotifications();
      _rememberItemStatuses(next);
      return;
    }

    _handleRemovedItems(next);
    final desiredProgressIds = switch (notificationSettings.downloadStyle) {
      DownloadNotificationStyle.batchSummary => _handleBatchSummary(
        previous,
        next,
      ),
      DownloadNotificationStyle.eachDownload => _handleEachDownload(next),
      DownloadNotificationStyle.completionOnly => <int>{},
    };
    if (notificationSettings.downloadStyle ==
        DownloadNotificationStyle.completionOnly) {
      _handleTerminalItems(next);
    }
    _cancelObsoleteProgressNotifications(desiredProgressIds);
  }

  Set<int> _handleBatchSummary(
    DownloadManagerState? previous,
    DownloadManagerState next,
  ) {
    _handleTerminalBatches(previous, next);

    final activeBatchId = next.activeBatchId;
    if (activeBatchId == null) return const {};

    final batch = _batchById(next, activeBatchId);
    if (batch == null) return const {};

    final items = _itemsForBatch(
      next,
      batch,
    ).where((item) => !item.status.isTerminal).toList();
    if (items.isEmpty) return const {};

    final id = _batchNotificationId(batch.id);
    _maybeShowBatchProgress(id, batch, items);
    return {id};
  }

  Set<int> _handleEachDownload(DownloadManagerState next) {
    final desiredIds = <int>{};
    for (final item in next.items) {
      final id = _downloadNotificationId(item.id);
      if (item.status == DownloadQueueStatus.downloading ||
          item.status == DownloadQueueStatus.paused) {
        desiredIds.add(id);
        _maybeShowItemProgress(id, item);
        continue;
      }
      _handleTerminalItem(item);
    }
    return desiredIds;
  }

  void _handleTerminalItems(DownloadManagerState next) {
    for (final item in next.items) {
      _handleTerminalItem(item);
    }
  }

  void _handleTerminalItem(DownloadQueueItem item) {
    final previousStatus = _lastItemStatuses[item.id];
    _lastItemStatuses[item.id] = item.status;
    if (!item.status.isTerminal) return;
    if (previousStatus == item.status) return;

    _lastProgressUpdates.remove(item.id);
    final id = _downloadNotificationId(item.id);
    _activeProgressNotificationIds.remove(id);
    unawaitedNotification(_replaceProgressWithFinalNotification(id, item));
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
      unawaitedNotification(
        AppNotificationService.instance.showEvent(
          id: id,
          title: failed > 0 ? 'Batch finished with errors' : 'Batch completed',
          body: failed > 0 || cancelled > 0
              ? '$completed completed · $failed failed · $cancelled cancelled'
              : batch.title,
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
    final paused =
        items.isNotEmpty &&
        items.every((item) => item.status == DownloadQueueStatus.paused);

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
        ),
        progress: progress,
        paused: paused,
        targetType: NotificationActionTargetType.batch,
        targetId: batch.id,
      ),
    );
  }

  void _maybeShowItemProgress(int id, DownloadQueueItem item) {
    final now = DateTime.now();
    final lastUpdate = _lastProgressUpdates[item.id];
    final previousStatus = _lastItemStatuses[item.id];
    _lastItemStatuses[item.id] = item.status;
    final statusChanged = previousStatus != item.status;
    final completed = item.progress >= 1;
    final shouldUpdate =
        lastUpdate == null ||
        statusChanged ||
        completed ||
        now.difference(lastUpdate) >= _minimumProgressInterval;

    if (!shouldUpdate) return;

    _lastProgressUpdates[item.id] = now;
    _activeProgressNotificationIds.add(id);
    unawaitedNotification(
      AppNotificationService.instance.showDownloadProgress(
        id: id,
        title: item.displayTitle,
        body: _itemProgressBody(item),
        progress: item.progress,
        paused: item.status == DownloadQueueStatus.paused,
        targetType: NotificationActionTargetType.download,
        targetId: item.id,
      ),
    );
  }

  Future<void> _replaceProgressWithFinalNotification(
    int id,
    DownloadQueueItem item,
  ) async {
    await AppNotificationService.instance.cancel(id);
    switch (item.status) {
      case DownloadQueueStatus.completed:
        await AppNotificationService.instance.showDownloadCompleted(
          id: id,
          title: 'Download completed',
          body: item.displayTitle,
        );
      case DownloadQueueStatus.failed:
        await AppNotificationService.instance.showDownloadFailed(
          id: id,
          title: item.errorTitle ?? 'Download failed',
          body: item.errorDescription ?? item.displayTitle,
        );
      case DownloadQueueStatus.cancelled:
        await AppNotificationService.instance.showEvent(
          id: id,
          title: 'Download cancelled',
          body: item.displayTitle,
        );
      case DownloadQueueStatus.preparing ||
          DownloadQueueStatus.queued ||
          DownloadQueueStatus.downloading ||
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

  void _onLifecycleChanged(AppLifecycleState state) {
    if (!_shouldShowNotifications(state)) {
      _cancelAllProgressNotifications();
      return;
    }
    _handleDownloadStateChanged(
      null,
      ref.read(DownloadManagerNotifier.provider),
    );
  }

  bool _shouldShowNotifications([AppLifecycleState? state]) {
    final lifecycleState = state ?? ref.read(AppLifecycleNotifier.provider);
    return lifecycleState != AppLifecycleState.resumed;
  }

  void _rememberItemStatuses(DownloadManagerState state) {
    for (final item in state.items) {
      _lastItemStatuses[item.id] = item.status;
    }
  }

  String _batchProgressBody({
    required List<DownloadQueueItem> items,
    required double progress,
    required int downloadedBytes,
    required int totalBytes,
    required double bytesPerSecond,
    required bool paused,
  }) {
    final activeCount = items
        .where(
          (item) =>
              item.status == DownloadQueueStatus.downloading ||
              item.status == DownloadQueueStatus.paused,
        )
        .length;
    final percent = (progress * 100).round().clamp(0, 100);
    final downloaded = formatBytes(downloadedBytes);
    final total = totalBytes > 0 ? formatBytes(totalBytes) : 'Unknown';
    if (paused) {
      return 'Paused · $activeCount items · $percent% · $downloaded / $total';
    }
    final speed = bytesPerSecond <= 0
        ? 'Starting...'
        : '${formatBytes(bytesPerSecond.round())}/s';
    return '$activeCount items · $percent% · $downloaded / $total · $speed';
  }

  String _itemProgressBody(DownloadQueueItem item) {
    final percent = (item.progress * 100).round().clamp(0, 100);
    final downloaded = formatBytes(item.downloadedBytes);
    final total = item.totalBytes > 0
        ? formatBytes(item.totalBytes)
        : 'Unknown';
    if (item.status == DownloadQueueStatus.paused) {
      return 'Paused at $percent% · $downloaded / $total';
    }
    final speed = item.bytesPerSecond <= 0
        ? 'Starting...'
        : '${formatBytes(item.bytesPerSecond.round())}/s';
    return '$percent% · $downloaded / $total · $speed';
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
