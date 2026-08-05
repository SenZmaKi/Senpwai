import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:senpwai/settings/settings.dart';
import 'package:senpwai/ui/pages/settings_page/appearance_settings.dart';
import 'package:senpwai/ui/pages/settings_page/content_download_settings.dart';
import 'package:senpwai/ui/pages/settings_page/settings_category_nav.dart';
import 'package:senpwai/ui/pages/settings_page/settings_search_results.dart';
import 'package:senpwai/ui/pages/settings_page/settings_tile.dart';
import 'package:senpwai/ui/pages/settings_page/source_settings_section.dart';
import 'package:senpwai/ui/pages/settings_page/storage_settings_section.dart';
import 'package:senpwai/ui/pages/settings_page/torrent_settings_section.dart';
import 'package:senpwai/ui/pages/settings_page/tracking_settings_section.dart';
import 'package:senpwai/ui/shared/responsive.dart';

class SettingsPage extends ConsumerStatefulWidget {
  final ValueChanged<bool>? onMobileCategoryChanged;

  const SettingsPage({super.key, this.onMobileCategoryChanged});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  SettingsCategory _desktopCategory = SettingsCategory.appearance;
  SettingsCategory? _mobileCategory;

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  void _setMobileCategory(SettingsCategory? category) {
    setState(() => _mobileCategory = category);
    widget.onMobileCategoryChanged?.call(category != null);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(AppSettingsNotifier.provider);
    final notifier = ref.read(AppSettingsNotifier.provider.notifier);
    final isWide = MediaQuery.of(context).size.width >= 800;
    final pad = horizontalPadding(context);

    return PopScope(
      canPop: isWide || _mobileCategory == null,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _mobileCategory != null) {
          setState(() => _mobileCategory = null);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) widget.onMobileCategoryChanged?.call(false);
          });
        }
      },
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(pad, 16, pad, 16),
            child: isWide
                ? _buildDesktopLayout(context, settings, notifier)
                : _buildMobileLayout(context, settings, notifier),
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopLayout(
    BuildContext context,
    AppSettings settings,
    AppSettingsNotifier notifier,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(context),
        const SizedBox(height: 16),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 260,
                child: SingleChildScrollView(
                  child: SettingsCategoryNav(
                    activeCategory: _desktopCategory,
                    onSelect: (cat) => setState(() {
                      _desktopCategory = cat;
                      _searchController.clear();
                      _searchQuery = '';
                    }),
                  ),
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: _buildCategoryContent(
                  context,
                  _desktopCategory,
                  settings,
                  notifier,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMobileLayout(
    BuildContext context,
    AppSettings settings,
    AppSettingsNotifier notifier,
  ) {
    if (_searchQuery.isNotEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(context),
          const SizedBox(height: 16),
          Expanded(child: _buildSearchResults(settings, notifier)),
        ],
      );
    }

    if (_mobileCategory != null) {
      final cat = _mobileCategory!;
      final theme = Theme.of(context);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: IconButton(
                  icon: const Icon(Icons.arrow_back_rounded),
                  tooltip: 'Back to Settings',
                  onPressed: () => _setMobileCategory(null),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      cat.title,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      cat.subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.6,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: SingleChildScrollView(
              child: _buildCategoryWidget(cat, settings, notifier),
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(context),
        const SizedBox(height: 16),
        Expanded(
          child: SingleChildScrollView(
            child: SettingsCategoryNav(
              isSidebar: false,
              onSelect: _setMobileCategory,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Settings',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Configure application preferences and engine options',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        SizedBox(
          width: 200,
          child: TextField(
            controller: _searchController,
            onChanged: (val) => setState(() => _searchQuery = val.trim()),
            decoration: InputDecoration(
              hintText: 'Search...',
              prefixIcon: const Icon(Icons.search_rounded, size: 18),
              isDense: true,
              suffixIcon: _searchQuery.isNotEmpty
                  ? MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 16),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      ),
                    )
                  : null,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryContent(
    BuildContext context,
    SettingsCategory cat,
    AppSettings settings,
    AppSettingsNotifier notifier,
  ) {
    if (_searchQuery.isNotEmpty) {
      return _buildSearchResults(settings, notifier);
    }

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SettingsSectionTitle(
                title: cat.title,
                icon: cat.icon,
                description: cat.subtitle,
              ),
              const SizedBox(height: 16),
              _buildCategoryWidget(cat, settings, notifier),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryWidget(
    SettingsCategory cat,
    AppSettings settings,
    AppSettingsNotifier notifier,
  ) {
    return switch (cat) {
      SettingsCategory.appearance => AppearanceSettings(
        settings: settings,
        notifier: notifier,
      ),
      SettingsCategory.content => ContentDownloadSettings(
        settings: settings,
        notifier: notifier,
      ),
      SettingsCategory.torrent => TorrentSettingsSection(
        settings: settings,
        notifier: notifier,
      ),
      SettingsCategory.sources => SourceSettingsSection(
        settings: settings,
        notifier: notifier,
      ),
      SettingsCategory.tracking => TrackingSettingsSection(
        settings: settings,
        notifier: notifier,
      ),
      SettingsCategory.system => StorageSettingsSection(
        settings: settings,
        notifier: notifier,
      ),
    };
  }

  Widget _buildSearchResults(
    AppSettings settings,
    AppSettingsNotifier notifier,
  ) {
    return SettingsSearchResults(
      query: _searchQuery,
      settings: settings,
      notifier: notifier,
      onClear: () {
        _searchController.clear();
        setState(() => _searchQuery = '');
      },
    );
  }
}
