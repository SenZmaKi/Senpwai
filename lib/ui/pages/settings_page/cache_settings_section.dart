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

class CacheSettingsSection extends ConsumerStatefulWidget {
  final AppSettings settings;
  final AppSettingsNotifier notifier;
  final String? searchQuery;

  const CacheSettingsSection({
    super.key,
    required this.settings,
    required this.notifier,
    this.searchQuery,
  });

  @override
  ConsumerState<CacheSettingsSection> createState() =>
      _CacheSettingsSectionState();
}

class _CacheSettingsSectionState extends ConsumerState<CacheSettingsSection> {
  late Future<AppStorageUsage> _usageFuture = _loadUsage();

  Future<AppStorageUsage> _loadUsage() =>
      calculateAppStorageUsage(AppPersistence.paths);

  void _refresh() {
    setState(() {
      _usageFuture = _loadUsage();
    });
  }

  @override
  Widget build(BuildContext context) {
    final storage = widget.settings.storage;
    final sq = widget.searchQuery;
    return FutureBuilder<AppStorageUsage>(
      future: _usageFuture,
      builder: (context, snapshot) {
        final usage = snapshot.data;
        return Column(
          children: [
            SettingsGroupCard(
              title: 'Image Cache',
              icon: Icons.data_usage_rounded,
              description: 'Control artwork storage and disk usage',
              searchQuery: sq,
              children: [
                SettingsTile(
                  icon: Icons.image_outlined,
                  title: 'Image Cache Limit',
                  subtitle:
                      '${_imageCacheLimitLabel(storage.imageCacheMaxBytes)} · Usage: ${_size(usage?.imageCacheBytes)}',
                  searchQuery: sq,
                  trailing: LimitSettingControl(
                    mode: _imageCacheLimitMode(storage.imageCacheMaxBytes),
                    allowsDisabled: false,
                    onModeChanged: (mode) => unawaited(
                      widget.notifier.setImageCacheMaxBytes(
                        mode == LimitMode.unlimited
                            ? 0
                            : _imageCacheLimitForCustomValue(
                                storage.imageCacheMaxBytes,
                              ),
                      ),
                    ),
                    valueField: NumberSettingField(
                      value: _imageCacheMegabytesForCustomValue(
                        storage.imageCacheMaxBytes,
                      ),
                      min: 1,
                      unit: 'MB',
                      zeroValueModeShortcut: true,
                      onSubmitted: (value) => unawaited(
                        widget.notifier.setImageCacheMaxBytes(megabytes(value)),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            SettingsGroupCard(
              title: 'App Cache Durations',
              icon: Icons.schedule_rounded,
              description:
                  'Freshness windows for requests Senpwai deliberately caches',
              searchQuery: sq,
              children: [
                _durationTile(
                  icon: Icons.search_rounded,
                  title: 'Live Search Results',
                  subtitle: 'Anime and torrent search responses',
                  duration: storage.liveSearchCacheTtl,
                  onChanged: widget.notifier.setLiveSearchCacheTtl,
                ),
                _durationTile(
                  icon: Icons.view_list_outlined,
                  title: 'Catalogue Data',
                  subtitle: 'Public catalogue and discovery responses',
                  duration: storage.catalogueCacheTtl,
                  onChanged: widget.notifier.setCatalogueCacheTtl,
                ),
                _durationTile(
                  icon: Icons.menu_book_outlined,
                  title: 'Reference Data',
                  subtitle: 'Filler lists, torrent files, and provider indexes',
                  duration: storage.referenceCacheTtl,
                  onChanged: widget.notifier.setReferenceCacheTtl,
                ),
              ],
            ),
            SettingsGroupCard(
              title: 'Browser Sessions',
              icon: Icons.language_rounded,
              description: 'Embedded browser memory and protected-site data',
              searchQuery: sq,
              children: [
                SettingsTile(
                  icon: Icons.memory_rounded,
                  title: 'Browser Transport Timeout',
                  subtitle:
                      'Close inactive embedded browser sessions to reduce memory use',
                  keywords:
                      'browser transport session memory idle timeout animepahe webview',
                  searchQuery: sq,
                  trailing: NumberSettingField(
                    value:
                        widget.settings.sources.browserTransportIdleTimeoutMinutes,
                    min: SourcePreferences.minBrowserTransportIdleTimeoutMinutes,
                    max: SourcePreferences.maxBrowserTransportIdleTimeoutMinutes,
                    unit: 'min',
                    onSubmitted:
                        widget.notifier.setBrowserTransportIdleTimeoutMinutes,
                  ),
                ),
                SettingsTile(
                  icon: Icons.cloud_off_outlined,
                  title: 'Clear Browser Sessions',
                  subtitle: 'Cookies and protected-site data',
                  searchQuery: sq,
                  trailing: const Icon(Icons.chevron_right, size: 20),
                  onTap: () => unawaited(_confirmAndClearSessions()),
                ),
              ],
            ),
            SettingsGroupCard(
              title: 'Cache Maintenance',
              icon: Icons.cleaning_services_outlined,
              description: 'Remove stored responses and artwork',
              searchQuery: sq,
              children: [
                _clearTile(
                  icon: Icons.delete_sweep_outlined,
                  title: 'Clear Image Cache',
                  subtitle: _size(usage?.imageCacheBytes),
                  message:
                      'Cached covers and banners will be downloaded again.',
                  action: AppPersistence.clearImageCache,
                ),
                _clearTile(
                  icon: Icons.http_rounded,
                  title: 'Clear HTTP Cache',
                  subtitle: _size(usage?.httpCacheBytes),
                  message: 'Cached network responses will be removed.',
                  action: AppPersistence.clearHttpCache,
                ),
                _clearTile(
                  icon: Icons.layers_clear_outlined,
                  title: 'Clear All Caches',
                  subtitle: _size(_totalCacheBytes(usage)),
                  message:
                      'Cached images and network responses will be removed. Browser sessions are kept.',
                  action: AppPersistence.clearCaches,
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  SettingsTile _durationTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Duration duration,
    required FutureOr<Object?> Function(Duration duration) onChanged,
  }) => SettingsTile(
    icon: icon,
    title: title,
    subtitle: subtitle,
    keywords: 'cache ttl freshness max stale duration age',
    searchQuery: widget.searchQuery,
    trailing: NumberSettingField(
      value: duration.inMinutes,
      min: 1,
      unit: 'min',
      onSubmitted: (minutes) {
        final result = onChanged(Duration(minutes: minutes));
        if (result is Future<Object?>) unawaited(result);
      },
    ),
  );

  SettingsTile _clearTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required String message,
    required Future<void> Function() action,
  }) => SettingsTile(
    icon: icon,
    title: title,
    subtitle: subtitle,
    searchQuery: widget.searchQuery,
    trailing: const Icon(Icons.chevron_right, size: 20),
    onTap: () => unawaited(
      _confirmAndClear(title: title, message: message, action: action),
    ),
  );

  Future<void> _confirmAndClearSessions() async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Clear browser sessions?',
      message: 'Protected-site browser cookies and sessions will be removed.',
      confirmLabel: 'Clear',
      destructive: true,
    );
    if (!confirmed) return;
    await AppPersistence.clearNetworkSession();
    if (!mounted) return;
    AppToast.showInfo(context, title: 'Browser sessions cleared');
  }

  Future<void> _confirmAndClear({
    required String title,
    required String message,
    required Future<void> Function() action,
  }) async {
    final confirmed = await showConfirmDialog(
      context,
      title: '$title?',
      message: message,
      confirmLabel: 'Clear',
      destructive: true,
    );
    if (!confirmed) return;
    await action();
    if (!mounted) return;
    _refresh();
    AppToast.showInfo(context, title: '$title complete');
  }

  String _size(int? bytes) =>
      bytes == null ? 'Calculating...' : formatBytes(bytes);

  int? _totalCacheBytes(AppStorageUsage? usage) =>
      usage == null ? null : usage.imageCacheBytes + usage.httpCacheBytes;
}

int _bytesToMegabytes(int bytes) => (bytes / (1024 * 1024)).round();

LimitMode _imageCacheLimitMode(int value) =>
    value <= 0 ? LimitMode.unlimited : LimitMode.limited;

int _imageCacheLimitForCustomValue(int value) =>
    value > 0 ? value : StoragePreferences.defaultImageCacheMaxBytes;

int _imageCacheMegabytesForCustomValue(int bytes) =>
    _bytesToMegabytes(_imageCacheLimitForCustomValue(bytes));

String _imageCacheLimitLabel(int bytes) =>
    bytes == 0 ? 'Unlimited' : 'Limit: ${formatBytes(bytes)}';
