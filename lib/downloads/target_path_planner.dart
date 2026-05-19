import 'dart:io';

import 'package:collection/collection.dart';
import 'package:path/path.dart' as path;
import 'package:senpwai/anilist/models.dart';
import 'package:senpwai/anitomy/anitomy.dart' as anitomy_parser;
import 'package:senpwai/shared/platform_paths.dart';

class ResolvedAnimeDownloadLocation {
  final String rootDirectory;
  final String seriesDirectory;
  final String episodeDirectory;
  final String seriesTitle;
  final String httpJobTitle;
  final int? seasonNumber;
  final String? variantFolderName;

  const ResolvedAnimeDownloadLocation({
    required this.rootDirectory,
    required this.seriesDirectory,
    required this.episodeDirectory,
    required this.seriesTitle,
    required this.httpJobTitle,
    this.seasonNumber,
    this.variantFolderName,
  });

  String get torrentSaveDirectory => seriesDirectory;
}

class PlannedEpisodeDownloadTarget {
  final String directory;
  final String fileName;

  const PlannedEpisodeDownloadTarget({
    required this.directory,
    required this.fileName,
  });

  String get filePath => path.join(directory, fileName);
}

class DownloadTargetPlanner {
  const DownloadTargetPlanner();

  static Directory defaultDownloadRootDirectory() =>
      defaultAnimeDownloadsRootDirectory();

  Future<ResolvedAnimeDownloadLocation> resolveAnimeLocation({
    required AnilistAnimeBase anime,
    required String downloadRoot,
  }) async {
    final rootDirectory = path.normalize(downloadRoot);
    final titleCandidates = _titleCandidates(anime.title);
    final parsedCandidates = titleCandidates
        .map(_parseAnimeTitle)
        .whereType<_ParsedAnimeTitle>()
        .toList();
    final directFolderCandidates = {
      for (final candidate in titleCandidates) sanitizePathSegment(candidate),
    };
    final fallbackTitle = sanitizePathSegment(
      anime.title.english ?? anime.title.display,
    );

    for (final parsed in parsedCandidates) {
      final existingSeriesDirectory = await _detectChildDirectory(
        Directory(rootDirectory),
        [parsed.baseTitle],
      );
      if (existingSeriesDirectory != null) {
        final existingEpisodeDirectory = await _detectExistingEpisodeDirectory(
          parentSeriesDirectory: existingSeriesDirectory,
          parsed: parsed,
          directFolderCandidates: directFolderCandidates,
        );
        if (existingEpisodeDirectory != null) {
          return ResolvedAnimeDownloadLocation(
            rootDirectory: rootDirectory,
            seriesDirectory: existingSeriesDirectory.path,
            episodeDirectory: existingEpisodeDirectory.path,
            seriesTitle: parsed.baseTitle,
            httpJobTitle: parsed.baseTitle,
            seasonNumber: parsed.seasonNumber,
            variantFolderName: parsed.variantFolderName,
          );
        }
        final defaultEpisodeDirectory = _defaultEpisodeDirectory(
          baseSeriesDirectory: existingSeriesDirectory.path,
          parsed: parsed,
        );
        return ResolvedAnimeDownloadLocation(
          rootDirectory: rootDirectory,
          seriesDirectory: existingSeriesDirectory.path,
          episodeDirectory: defaultEpisodeDirectory,
          seriesTitle: parsed.baseTitle,
          httpJobTitle: parsed.baseTitle,
          seasonNumber: parsed.seasonNumber,
          variantFolderName: parsed.variantFolderName,
        );
      }
    }

    String? matchedTitleCandidate;
    for (final candidate in titleCandidates) {
      final directMatch = await _detectChildDirectory(
        Directory(rootDirectory),
        [sanitizePathSegment(candidate)],
      );
      if (directMatch == null) continue;
      matchedTitleCandidate = candidate;
      final sanitizedMatchedTitle = sanitizePathSegment(matchedTitleCandidate);
      return ResolvedAnimeDownloadLocation(
        rootDirectory: rootDirectory,
        seriesDirectory: directMatch.path,
        episodeDirectory: directMatch.path,
        seriesTitle: sanitizedMatchedTitle,
        httpJobTitle: sanitizedMatchedTitle,
        seasonNumber: null,
        variantFolderName: null,
      );
    }

    final parsed = parsedCandidates.firstOrNull;
    final defaultSeriesTitle = parsed?.baseTitle ?? fallbackTitle;
    final defaultSeriesDirectory = path.join(rootDirectory, defaultSeriesTitle);
    final defaultEpisodeDirectory = _defaultEpisodeDirectory(
      baseSeriesDirectory: defaultSeriesDirectory,
      parsed: parsed,
    );
    return ResolvedAnimeDownloadLocation(
      rootDirectory: rootDirectory,
      seriesDirectory: defaultSeriesDirectory,
      episodeDirectory: defaultEpisodeDirectory,
      seriesTitle: defaultSeriesTitle,
      httpJobTitle: fallbackTitle,
      seasonNumber: parsed?.seasonNumber,
      variantFolderName: parsed?.variantFolderName,
    );
  }

  PlannedEpisodeDownloadTarget planEpisodeFile({
    required String directory,
    required String jobTitle,
    required String sourceFileName,
    required String resolvedUrl,
    String? dedupeSuffix,
  }) {
    final extension = _resolveFileExtension(
      sourceFileName: sourceFileName,
      resolvedUrl: resolvedUrl,
    );
    final baseName = dedupeSuffix == null
        ? jobTitle
        : '$jobTitle $dedupeSuffix';
    final fileName = '${sanitizePathSegment(baseName)}$extension';
    return PlannedEpisodeDownloadTarget(
      directory: directory,
      fileName: fileName,
    );
  }

  static String sanitizePathSegment(String value) {
    final withReadableColon = value.replaceAll(':', ' -');
    final withoutIllegalCharacters = withReadableColon
        .replaceAll(RegExp(r'[\\/*?"<>|]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim()
        .replaceAll(RegExp(r'[. ]+$'), '');
    final fallback = value
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim()
        .replaceAll(RegExp(r'[. ]+$'), '');
    final sanitized =
        (withoutIllegalCharacters.isNotEmpty
                ? withoutIllegalCharacters
                : fallback.isNotEmpty
                ? fallback
                : 'Anime')
            .trim();
    return sanitized.length > 255
        ? sanitized.substring(0, 255).trim()
        : sanitized;
  }

  static List<String> _titleCandidates(AnilistTitle title) {
    final values = <String>[];
    void add(String? candidate) {
      if (candidate == null) return;
      final trimmed = candidate.trim();
      if (trimmed.isEmpty || values.contains(trimmed)) return;
      values.add(trimmed);
    }

    add(title.english);
    add(title.romaji);
    add(title.native);
    add(title.display);
    return values;
  }

  static _ParsedAnimeTitle? _parseAnimeTitle(String title) {
    final parsed = anitomy_parser.parseFilename(title);
    final parsedTitle = sanitizePathSegment(parsed.title ?? title);
    if (parsedTitle.isEmpty) return null;

    final typeNames = parsed.animeTypes
        .map(_formatAnimeTypeFolderName)
        .where((value) => value.isNotEmpty)
        .toList();
    final uniqueTypeNames = typeNames.toSet().toList();
    return _ParsedAnimeTitle(
      baseTitle: parsedTitle,
      seasonNumber: uniqueTypeNames.isEmpty ? parsed.season ?? 1 : 1,
      typeNames: uniqueTypeNames,
    );
  }

  static Future<Directory?> _detectChildDirectory(
    Directory parentDirectory,
    Iterable<String> folderNameCandidates,
  ) async {
    if (!await parentDirectory.exists()) return null;
    final normalizedCandidates = folderNameCandidates
        .map(_normalizeForMatch)
        .where((value) => value.isNotEmpty)
        .toSet();
    if (normalizedCandidates.isEmpty) return null;

    await for (final entity in parentDirectory.list(followLinks: false)) {
      if (entity is! Directory) continue;
      final entityName = path.basename(entity.path);
      if (normalizedCandidates.contains(_normalizeForMatch(entityName))) {
        return entity;
      }
    }
    return null;
  }

  static Future<Directory?> _detectExistingEpisodeDirectory({
    required Directory parentSeriesDirectory,
    required _ParsedAnimeTitle parsed,
    required Set<String> directFolderCandidates,
  }) {
    final variantCandidates = <String>{
      ..._variantFolderCandidates(parsed),
      ...directFolderCandidates,
    };
    return _detectChildDirectory(parentSeriesDirectory, variantCandidates);
  }

  static String _defaultEpisodeDirectory({
    required String baseSeriesDirectory,
    required _ParsedAnimeTitle? parsed,
  }) {
    if (parsed == null) return baseSeriesDirectory;
    if (parsed.variantFolderName != null) {
      return path.join(baseSeriesDirectory, parsed.variantFolderName!);
    }
    if (parsed.seasonNumber > 1) {
      return path.join(
        baseSeriesDirectory,
        'Season ${parsed.seasonNumber.toString().padLeft(2, '0')}',
      );
    }
    return baseSeriesDirectory;
  }

  static Iterable<String> _variantFolderCandidates(
    _ParsedAnimeTitle parsed,
  ) sync* {
    if (parsed.variantFolderName != null) {
      yield parsed.variantFolderName!;
      yield '${parsed.baseTitle} ${parsed.variantFolderName!}';
      return;
    }
    if (parsed.seasonNumber <= 1) return;
    final season = parsed.seasonNumber;
    final paddedSeason = season.toString().padLeft(2, '0');
    const prefixes = ['Season', 'SN', 'Sn', 'S'];
    for (final prefix in prefixes) {
      final plain = prefix == 'S' ? '$prefix$season' : '$prefix $season';
      final padded = prefix == 'S'
          ? '$prefix$paddedSeason'
          : '$prefix $paddedSeason';
      yield plain;
      yield padded;
      yield '${parsed.baseTitle} $plain';
      yield '${parsed.baseTitle} $padded';
    }
  }

  static String _resolveFileExtension({
    required String sourceFileName,
    required String resolvedUrl,
  }) {
    final sourceExtension = path.extension(
      path.basename(sourceFileName.trim()),
    );
    if (sourceExtension.isNotEmpty) {
      return sourceExtension.toLowerCase();
    }
    final resolvedPath = Uri.tryParse(resolvedUrl)?.path ?? resolvedUrl;
    final resolvedExtension = path.extension(path.basename(resolvedPath));
    if (resolvedExtension.isNotEmpty) {
      return resolvedExtension.toLowerCase();
    }
    return '.bin';
  }

  static String _formatAnimeTypeFolderName(String type) {
    final sanitized = sanitizePathSegment(type);
    if (sanitized.isEmpty) return '';
    return switch (sanitized.toLowerCase()) {
      'special' => 'Specials',
      'specials' => 'Specials',
      'ova' => 'OVA',
      'oad' => 'OAD',
      'ona' => 'ONA',
      'movie' => 'Movie',
      _ => sanitized,
    };
  }

  static String _normalizeForMatch(String value) {
    final sanitized = sanitizePathSegment(value).toLowerCase();
    return sanitized.replaceAll(RegExp(r'[\s._-]+'), '');
  }
}

class _ParsedAnimeTitle {
  final String baseTitle;
  final int seasonNumber;
  final List<String> typeNames;

  const _ParsedAnimeTitle({
    required this.baseTitle,
    required this.seasonNumber,
    required this.typeNames,
  });

  String? get variantFolderName => typeNames.firstOrNull;
}
