import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:senpwai/shared/persistence/app_image_cache.dart';

/// Decodes a network image close to its physical render size instead of
/// retaining the source-resolution image in Flutter's in-memory image cache.
class RenderSizedCachedNetworkImage extends StatelessWidget {
  static const _dimensionBucket = 64;

  final String imageUrl;
  final BoxFit fit;
  final Widget Function(BuildContext context, String url)? placeholder;
  final Widget Function(BuildContext context, String url, Object error)?
  errorWidget;

  const RenderSizedCachedNetworkImage({
    super.key,
    required this.imageUrl,
    required this.fit,
    this.placeholder,
    this.errorWidget,
  });

  @override
  Widget build(BuildContext context) {
    final devicePixelRatio = MediaQuery.devicePixelRatioOf(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        return CachedNetworkImage(
          cacheManager: AppImageCache.manager,
          imageUrl: imageUrl,
          fit: fit,
          memCacheWidth: _decodeDimension(
            constraints.hasBoundedWidth ? constraints.maxWidth : null,
            devicePixelRatio,
          ),
          memCacheHeight: _decodeDimension(
            constraints.hasBoundedHeight ? constraints.maxHeight : null,
            devicePixelRatio,
          ),
          placeholder: placeholder,
          errorWidget: errorWidget,
        );
      },
    );
  }

  static int? _decodeDimension(double? logicalSize, double pixelRatio) {
    if (logicalSize == null || !logicalSize.isFinite || logicalSize <= 0) {
      return null;
    }
    final physicalSize = logicalSize * pixelRatio;
    return (physicalSize / _dimensionBucket).ceil() * _dimensionBucket;
  }
}
