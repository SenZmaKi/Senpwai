import 'package:flutter/material.dart';
import 'package:senpwai/anilist/enums.dart';
import 'package:senpwai/anilist/models.dart';

class MediaListStatusDot extends StatelessWidget {
  final AnilistAnimeBase anime;
  final double size;
  final double trailingGap;

  const MediaListStatusDot({
    super.key,
    required this.anime,
    this.size = 10,
    this.trailingGap = 5,
  });

  @override
  Widget build(BuildContext context) {
    final a = anime;
    final listStatus = a is AnilistAnimeWithListEntry
        ? a.listEntry?.status
        : null;

    if (listStatus == null) return const SizedBox.shrink();

    final color = statusColor(listStatus);

    return Padding(
      padding: EdgeInsets.only(right: trailingGap),
      child: Tooltip(
        message: listStatus.toDisplayLabel(),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 4),
            ],
          ),
        ),
      ),
    );
  }

  static Color statusColor(AnilistMediaListStatus status) => switch (status) {
    AnilistMediaListStatus.current => const Color(0xFF68D639),
    AnilistMediaListStatus.planning => const Color(0xFF02A9FF),
    AnilistMediaListStatus.completed => const Color(0xFF9256F3),
    AnilistMediaListStatus.dropped => const Color(0xFFFF6F60),
    AnilistMediaListStatus.paused => const Color(0xFFE85D75),
    AnilistMediaListStatus.repeating => const Color(0xFFCC7ED3),
  };
}
