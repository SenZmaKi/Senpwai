import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

String? normalizeImageUrl(String? imageUrl) {
  final trimmed = imageUrl?.trim();
  if (trimmed == null || trimmed.isEmpty) {
    return null;
  }
  return trimmed;
}

class AnimeCoverImage extends StatelessWidget {
  final String? imageUrl;
  final Color placeholderColor;
  final double noImageIconSize;
  final BoxFit fit;

  const AnimeCoverImage({
    super.key,
    required this.imageUrl,
    required this.placeholderColor,
    this.noImageIconSize = 40,
    this.fit = BoxFit.cover,
  });

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final resolvedImageUrl = normalizeImageUrl(imageUrl);
    if (resolvedImageUrl != null) {
      return CachedNetworkImage(
        imageUrl: resolvedImageUrl,
        fit: fit,
        placeholder: (_, __) =>
            Container(color: placeholderColor.withValues(alpha: 0.3)),
        errorWidget: (_, __, ___) => Container(
          color: placeholderColor.withValues(alpha: 0.3),
          child: Icon(
            Icons.broken_image,
            color: onSurface.withValues(alpha: 0.3),
          ),
        ),
      );
    }
    return Container(
      color: placeholderColor.withValues(alpha: 0.3),
      child: Icon(
        Icons.movie_outlined,
        size: noImageIconSize,
        color: onSurface.withValues(alpha: 0.2),
      ),
    );
  }
}
