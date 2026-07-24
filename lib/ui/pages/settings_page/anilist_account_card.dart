import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:senpwai/shared/persistence/app_image_cache.dart';
import 'package:senpwai/ui/components/anime_cover_image.dart';
import 'package:senpwai/ui/components/confirm_dialog.dart';
import 'package:senpwai/ui/components/toast.dart';
import 'package:senpwai/ui/pages/settings_page/settings_tile.dart';
import 'package:senpwai/ui/shared/anilist.dart';

class AnilistAccountCard extends ConsumerWidget {
  final String? searchQuery;

  const AnilistAccountCard({super.key, this.searchQuery});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final anilist = ref.watch(AnilistNotifier.provider);
    final viewer = anilist.viewer;

    return SettingsGroupCard(
      title: 'AniList Account',
      icon: Icons.account_circle_outlined,
      description: 'Your connected AniList profile',
      searchQuery: searchQuery,
      searchTerms: [
        'profile username connected log in login log out logout',
        if (viewer != null) viewer.name,
      ],
      children: [
        if (anilist.isAuthLoading)
          const SettingsTile(
            icon: Icons.sync_rounded,
            title: 'Refreshing AniList',
            subtitle: 'Updating your account state...',
            trailing: SizedBox.square(
              dimension: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          )
        else if (anilist.isAuthenticated && viewer != null)
          _ProfileRow(
            name: viewer.name,
            avatarUrl: viewer.avatarUrl,
            onLogout: () => unawaited(_confirmLogout(context, ref)),
          )
        else
          SettingsTile(
            icon: Icons.link_off_rounded,
            title: 'AniList not connected',
            subtitle: 'Connect your AniList account',
            trailing: FilledButton.icon(
              onPressed: () => unawaited(_login(context, ref)),
              icon: const Icon(Icons.login_rounded, size: 18),
              label: const Text('Log in'),
            ),
          ),
      ],
    );
  }

  Future<void> _login(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(AnilistNotifier.provider.notifier).login();
    } on Object catch (error, stackTrace) {
      if (!context.mounted) return;
      AppToast.showError(
        context,
        title: 'AniList login failed',
        description: error.toString(),
        copyPayload: formatErrorForCopy(error, stackTrace),
      );
    }
  }

  Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Log out of AniList?',
      message:
          'Senpwai will remove your saved AniList session from this device.',
      confirmLabel: 'Log out',
      destructive: true,
    );
    if (!confirmed || !context.mounted) return;

    try {
      await ref.read(AnilistNotifier.provider.notifier).logout();
      if (!context.mounted) return;
      AppToast.showInfo(context, title: 'Logged out of AniList');
    } on Object catch (error, stackTrace) {
      if (!context.mounted) return;
      AppToast.showError(
        context,
        title: 'AniList logout failed',
        description: error.toString(),
        copyPayload: formatErrorForCopy(error, stackTrace),
      );
    }
  }
}

class _ProfileRow extends StatelessWidget {
  final String name;
  final String? avatarUrl;
  final VoidCallback onLogout;

  const _ProfileRow({
    required this.name,
    required this.avatarUrl,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final resolvedAvatarUrl = normalizeImageUrl(avatarUrl);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
            backgroundImage: resolvedAvatarUrl == null
                ? null
                : CachedNetworkImageProvider(
                    resolvedAvatarUrl,
                    cacheManager: AppImageCache.manager,
                  ),
            child: resolvedAvatarUrl == null
                ? const Icon(Icons.person_outline_rounded)
                : null,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 12),
          OutlinedButton.icon(
            onPressed: onLogout,
            icon: const Icon(Icons.logout_rounded, size: 18),
            label: const Text('Log out'),
          ),
        ],
      ),
    );
  }
}
