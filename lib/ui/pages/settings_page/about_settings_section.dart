import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:senpwai/settings/settings.dart';
import 'package:senpwai/ui/components/toast.dart';
import 'package:senpwai/ui/pages/settings_page/settings_tile.dart';
import 'package:senpwai/ui/pages/settings_page/settings_controls.dart';
import 'package:senpwai/updates/updates.dart';
import 'package:url_launcher/url_launcher.dart';

class AboutSettingsSection extends ConsumerWidget {
  final AppSettings settings;
  final AppSettingsNotifier notifier;
  final String? searchQuery;

  const AboutSettingsSection({
    super.key,
    required this.settings,
    required this.notifier,
    this.searchQuery,
  });

  static const _discordUrl = 'https://discord.gg/e9UxkuyDX2';
  static const _githubUrl = 'https://github.com/SenZmaKi/Senpwai';
  static const _redditUrl = 'https://reddit.com/r/Senpwai';
  static const _githubSponsorsUrl = 'https://github.com/sponsors/SenZmaKi';
  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _checkForUpdates(BuildContext context, WidgetRef ref) async {
    await ref
        .read(UpdateController.provider.notifier)
        .check(userInitiated: true);
    if (!context.mounted) return;
    final result = ref.read(UpdateController.provider);
    if (result.phase == UpdatePhase.idle) {
      AppToast.showInfo(
        context,
        title: 'Senpwai is up to date',
        description: 'Version ${result.currentVersion} is the latest release.',
      );
    } else if (result.phase == UpdatePhase.failed) {
      AppToast.showError(
        context,
        title: 'Could not check for updates',
        description: result.error ?? 'Try again later.',
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sq = searchQuery;
    final theme = Theme.of(context);
    final updateState = ref.watch(UpdateController.provider);
    final currentVersion = updateState.currentVersion.isEmpty
        ? '—'
        : updateState.currentVersion;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeroCard(theme, currentVersion),
        const SizedBox(height: 16),
        SettingsGroupCard(
          title: 'Updates & Releases',
          icon: Icons.system_update_rounded,
          description: 'Version details and update checks',
          searchQuery: sq,
          children: [
            SettingsTile(
              icon: Icons.code_rounded,
              title: 'Current Version',
              subtitle: 'v$currentVersion',
              keywords: 'version build latest release update',
              searchQuery: sq,
            ),
            SettingsTile(
              icon: Icons.published_with_changes_rounded,
              title: 'Check for Updates',
              subtitle: updateState.phase == UpdatePhase.checking
                  ? 'Checking for updates...'
                  : _updateStatusDescription(updateState),
              keywords: 'check updates new version download upgrade github',
              searchQuery: sq,
              trailing: updateState.phase == UpdatePhase.checking
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.chevron_right, size: 20),
              onTap: () => unawaited(_checkForUpdates(context, ref)),
            ),
            SettingsTile(
              icon: Icons.downloading_rounded,
              title: 'Download updates automatically',
              subtitle:
                  'Checks in the background; anime download limits do not apply',
              keywords: 'automatic updates background download app speed limit',
              searchQuery: sq,
              trailing: AsyncSwitch(
                value: settings.updates.automaticallyDownload,
                onChanged: notifier.setAutomaticallyDownloadUpdates,
              ),
            ),
            SettingsTile(
              icon: Icons.notes_rounded,
              title: 'Release Notes',
              subtitle: 'View full release notes & changelog on GitHub',
              keywords: 'release notes changelog github updates',
              searchQuery: sq,
              trailing: const Icon(Icons.open_in_new_rounded, size: 18),
              onTap: () =>
                  _openUrl('https://github.com/SenZmaKi/Senpwai/releases'),
            ),
          ],
        ),
        SettingsGroupCard(
          title: 'Social Links & Community',
          icon: Icons.groups_rounded,
          description: 'Join the community, report bugs, or suggest features',
          searchQuery: sq,
          children: [
            SettingsTile(
              leadingWidget: Image.asset(
                'assets/images/link_icons/discord.png',
                width: 24,
                height: 24,
                fit: BoxFit.contain,
              ),
              title: 'Discord',
              subtitle: _discordUrl,
              keywords: 'discord server chat community support bug report',
              searchQuery: sq,
              trailing: const Icon(Icons.open_in_new_rounded, size: 18),
              onTap: () => _openUrl(_discordUrl),
            ),
            SettingsTile(
              leadingWidget: Image.asset(
                'assets/images/link_icons/github.png',
                width: 24,
                height: 24,
                fit: BoxFit.contain,
              ),
              title: 'GitHub',
              subtitle: _githubUrl,
              keywords: 'github code repo issues source report bug feature',
              searchQuery: sq,
              trailing: const Icon(Icons.open_in_new_rounded, size: 18),
              onTap: () => _openUrl(_githubUrl),
            ),
            SettingsTile(
              leadingWidget: Image.asset(
                'assets/images/link_icons/reddit.png',
                width: 24,
                height: 24,
                fit: BoxFit.contain,
              ),
              title: 'Reddit',
              subtitle: 'r/Senpwai ($_redditUrl)',
              keywords: 'reddit subreddit community discussion forum',
              searchQuery: sq,
              trailing: const Icon(Icons.open_in_new_rounded, size: 18),
              onTap: () => _openUrl(_redditUrl),
            ),
          ],
        ),
        SettingsGroupCard(
          title: 'Support & Sponsorship',
          icon: Icons.volunteer_activism_rounded,
          description: 'Help support ongoing development',
          searchQuery: sq,
          children: [
            SettingsTile(
              leadingWidget: SvgPicture.asset(
                'assets/images/link_icons/github-sponsors.svg',
                width: 24,
                height: 24,
                fit: BoxFit.contain,
              ),
              title: 'GitHub Sponsors',
              subtitle: _githubSponsorsUrl,
              keywords: 'sponsor github donate support development',
              searchQuery: sq,
              trailing: const Icon(Icons.open_in_new_rounded, size: 18),
              onTap: () => _openUrl(_githubSponsorsUrl),
            ),
            SettingsTile(
              icon: Icons.star_rounded,
              title: 'Star on GitHub',
              subtitle:
                  'Starring the repository helps other weebs discover Senpwai',
              keywords: 'star github repository support open source',
              searchQuery: sq,
              trailing: const Icon(Icons.open_in_new_rounded, size: 18),
              onTap: () => _openUrl(_githubUrl),
            ),
          ],
        ),
        SettingsGroupCard(
          title: 'Licenses & Legal',
          icon: Icons.gavel_rounded,
          description: 'Open source disclosures and third-party libraries',
          searchQuery: sq,
          children: [
            SettingsTile(
              icon: Icons.description_outlined,
              title: 'Open Source Licenses',
              subtitle: 'View third-party package licenses and disclosures',
              keywords: 'licenses open source legal copyright packages',
              searchQuery: sq,
              trailing: const Icon(Icons.chevron_right, size: 20),
              onTap: () {
                showLicensePage(
                  context: context,
                  applicationName: 'Senpwai',
                  applicationVersion: currentVersion,
                );
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildHeroCard(ThemeData theme, String currentVersion) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.12),
        ),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.asset(
              'assets/images/senpwai-icon.png',
              width: 56,
              height: 56,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Senpwai',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'v$currentVersion · Free & Open-Source Anime Downloader',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'A less annoying way to download anime',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _updateStatusDescription(UpdateState state) => switch (state.phase) {
    UpdatePhase.available => '${state.release?.displayVersion} is available',
    UpdatePhase.downloading => 'Downloading ${state.release?.displayVersion}',
    UpdatePhase.verifying => 'Verifying the downloaded update',
    UpdatePhase.preparing => 'Preparing the update for the next launch',
    UpdatePhase.ready => '${state.release?.displayVersion} is ready to install',
    UpdatePhase.installing => 'Installing ${state.release?.displayVersion}',
    UpdatePhase.failed => state.error ?? 'Update check failed',
    _ => 'Check for the latest Senpwai release',
  };
}
