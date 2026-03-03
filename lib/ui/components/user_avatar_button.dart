import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:senpwai/anilist/anilist.dart';

class UserAvatarButton extends StatelessWidget {
  final AnilistViewer? viewer;
  final bool isLoading;
  final VoidCallback onTap;

  const UserAvatarButton({
    super.key,
    this.viewer,
    this.isLoading = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (isLoading) {
      return const SizedBox(
        width: 34,
        height: 34,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }

    if (viewer?.avatarUrl != null) {
      return Tooltip(
        message: viewer?.name ?? 'Profile',
        child: GestureDetector(
          onTap: onTap,
          child: CircleAvatar(
            radius: 17,
            backgroundImage: CachedNetworkImageProvider(viewer!.avatarUrl!),
          ),
        ),
      );
    }

    return Tooltip(
      message: 'Login with AniList',
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: const Icon(Icons.login, size: 16),
        label: const Text('Login'),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          minimumSize: const Size(0, 34),
          textStyle: theme.textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
          side: BorderSide(color: theme.colorScheme.primary),
        ),
      ),
    );
  }
}
