import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:senpwai/settings/settings.dart';
import 'package:senpwai/shared/persistence/app_persistence.dart';
import 'package:senpwai/ui/components/confirm_dialog.dart';
import 'package:senpwai/ui/components/toast.dart';
import 'package:senpwai/ui/pages/settings_page/settings_controls.dart';
import 'package:senpwai/ui/pages/settings_page/settings_formatters.dart';
import 'package:senpwai/ui/pages/settings_page/settings_tile.dart';

class StorageSettingsSection extends ConsumerStatefulWidget {
  final AppSettings settings;
  final AppSettingsNotifier notifier;

  const StorageSettingsSection({
    super.key,
    required this.settings,
    required this.notifier,
  });

  @override
  ConsumerState<StorageSettingsSection> createState() =>
      _StorageSettingsSectionState();
}

class _StorageSettingsSectionState
    extends ConsumerState<StorageSettingsSection> {
  late Future<AppStorageUsage> _usageFuture = _loadUsage();
  int _httpCacheAgeResetToken = 0;

  Future<AppStorageUsage> _loadUsage() =>
      calculateAppStorageUsage(AppPersistence.paths);

  void _refresh() {
    setState(() {
      _usageFuture = _loadUsage();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AppStorageUsage>(
      future: _usageFuture,
      builder: (context, snapshot) {
        final usage = snapshot.data;
        return Column(
          children: [
            SettingsTile(
              icon: Icons.image_outlined,
              title: 'Image Cache Limit',
              subtitle:
                  '${_imageCacheLimitLabel(widget.settings.storage.imageCacheMaxBytes)} · Current usage: ${_size(usage?.imageCacheBytes)}',
              trailing: NumberSettingField(
                value: _bytesToMegabytes(
                  widget.settings.storage.imageCacheMaxBytes,
                ),
                min: 0,
                unit: 'MB',
                onSubmitted: (value) => unawaited(
                  widget.notifier.setImageCacheMaxBytes(megabytes(value)),
                ),
              ),
            ),
            SettingsTile(
              icon: Icons.http_rounded,
              title: 'HTTP Cache Age',
              subtitle: 'Current usage: ${_size(usage?.httpCacheBytes)}',
              trailing: NumberSettingField(
                value: widget.settings.storage.httpCacheMaxAge.inHours,
                min: -999999,
                allowNegative: true,
                resetToken: _httpCacheAgeResetToken,
                unit: 'hours',
                onSubmitted: (value) => unawaited(_setHttpCacheAge(value)),
              ),
            ),
            SettingsTile(
              icon: Icons.delete_sweep_outlined,
              title: 'Clear Image Cache',
              subtitle: _size(usage?.imageCacheBytes),
              trailing: const Icon(Icons.chevron_right, size: 20),
              onTap: () => unawaited(
                _confirmAndRun(
                  title: 'Clear image cache?',
                  message:
                      'Cached covers and banners will be downloaded again.',
                  action: AppPersistence.clearImageCache,
                ),
              ),
            ),
            SettingsTile(
              icon: Icons.cleaning_services_outlined,
              title: 'Clear HTTP Cache',
              subtitle: _size(usage?.httpCacheBytes),
              trailing: const Icon(Icons.chevron_right, size: 20),
              onTap: () => unawaited(
                _confirmAndRun(
                  title: 'Clear HTTP cache?',
                  message: 'Cached network responses will be removed.',
                  action: AppPersistence.clearHttpCache,
                ),
              ),
            ),
            SettingsTile(
              icon: Icons.cloud_off_outlined,
              title: 'Clear Cloudflare Sessions',
              subtitle: _size(usage?.cloudflareSessionBytes),
              trailing: const Icon(Icons.chevron_right, size: 20),
              onTap: () => unawaited(
                _confirmAndRun(
                  title: 'Clear Cloudflare sessions?',
                  message:
                      'Cloudflare cookies and bypass sessions will be removed.',
                  action: AppPersistence.clearNetworkSession,
                ),
              ),
            ),
            SettingsTile(
              icon: Icons.layers_clear_outlined,
              title: 'Clear App Cache and Sessions',
              subtitle: _size(usage?.appCacheAndSessionBytes),
              trailing: const Icon(Icons.chevron_right, size: 20),
              onTap: () => unawaited(
                _confirmAndRun(
                  title: 'Clear app cache and sessions?',
                  message:
                      'This keeps settings, AniList login, and downloaded anime.',
                  action: AppPersistence.clearAppCacheAndSessions,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _confirmAndRun({
    required String title,
    required String message,
    required Future<void> Function() action,
  }) async {
    final confirmed = await showConfirmDialog(
      context,
      title: title,
      message: message,
      confirmLabel: 'Clear',
      destructive: true,
    );
    if (!confirmed) return;
    await action();
    if (!mounted) return;
    _refresh();
    AppToast.showInfo(context, title: 'Storage cleared');
  }

  String _size(int? bytes) =>
      bytes == null ? 'Calculating...' : formatBytes(bytes);

  Future<void> _setHttpCacheAge(int hours) async {
    final wasReset = await widget.notifier.setHttpCacheMaxAge(
      Duration(hours: hours),
    );
    if (!mounted || !wasReset) return;
    setState(() => _httpCacheAgeResetToken++);
    AppToast.showWarning(
      context,
      title: 'Cache age reset',
      description: 'HTTP cache age must be greater than zero hours.',
    );
  }
}

int _bytesToMegabytes(int bytes) => (bytes / (1024 * 1024)).round();

String _imageCacheLimitLabel(int bytes) =>
    bytes == 0 ? 'Unlimited' : 'Limit: ${formatBytes(bytes)}';
