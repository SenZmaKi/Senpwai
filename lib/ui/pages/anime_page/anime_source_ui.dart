import 'package:flutter/material.dart';
import 'package:senpwai/downloads/models.dart';

extension AnimeSourceUiExtension on AnimeSource {
  Color get color => switch (this) {
    AnimeSource.animepahe => const Color(0xFFFF8C00),
    AnimeSource.tokyoinsider => const Color(0xFF43A047),
    AnimeSource.nyaa => const Color(0xFF2196F3),
  };

  String get iconAsset => switch (this) {
    AnimeSource.animepahe => 'assets/images/animepahe-icon.png',
    AnimeSource.tokyoinsider => 'assets/images/tokyoinsider-icon.ico',
    AnimeSource.nyaa => 'assets/images/nyaa-icon.png',
  };
}
