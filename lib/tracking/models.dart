import 'package:flutter/foundation.dart';
import 'package:senpwai/anilist/models.dart';
import 'package:senpwai/downloads/models.dart';
import 'package:senpwai/sources/shared/shared.dart';

enum TrackingEventLevel { info, warning, error }

enum TrackingEventKind {
  queued,
  reviewNeeded,
  warning,
  failed,
  finishedTracking,
}

@immutable
class TrackingEvent {
  final String id;
  final TrackingEventKind kind;
  final TrackingEventLevel level;
  final String title;
  final String description;

  const TrackingEvent({
    required this.id,
    required this.kind,
    required this.level,
    required this.title,
    required this.description,
  });

  factory TrackingEvent.create({
    required TrackingEventKind kind,
    required TrackingEventLevel level,
    required String title,
    required String description,
  }) {
    return TrackingEvent(
      id: '${DateTime.now().microsecondsSinceEpoch}-${kind.name}',
      kind: kind,
      level: level,
      title: title,
      description: description,
    );
  }
}

@immutable
class TrackedAnime {
  final int anilistId;
  final AnilistAnime animeSnapshot;
  final AnimeSource? preferredSource;
  final bool sourceSelectedByUser;
  final Resolution resolution;
  final Language language;
  final String downloadFolder;
  final String httpJobTitle;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? lastCheckedAt;
  final String? lastError;
  final String? completionBatchId;

  const TrackedAnime({
    required this.anilistId,
    required this.animeSnapshot,
    required this.downloadFolder,
    required this.httpJobTitle,
    required this.resolution,
    required this.language,
    required this.createdAt,
    required this.updatedAt,
    this.preferredSource,
    this.sourceSelectedByUser = false,
    this.lastCheckedAt,
    this.lastError,
    this.completionBatchId,
  });

  factory TrackedAnime.fromJson(Map<String, dynamic> json) {
    final animeJson = _mapValue(json['animeSnapshot']);
    final anime = AnilistAnime.fromJson(animeJson);
    final now = DateTime.now();
    return TrackedAnime(
      anilistId: _intValue(json['anilistId'], anime.id),
      animeSnapshot: anime,
      preferredSource: _enumOrNull(AnimeSource.values, json['preferredSource']),
      sourceSelectedByUser: _boolValue(json['sourceSelectedByUser'], false),
      resolution: _enumValue(
        Resolution.values,
        json['resolution'],
        Resolution.res1080p,
      ),
      language: _enumValue(
        Language.values,
        json['language'],
        Language.japanese,
      ),
      downloadFolder: _stringValue(json['downloadFolder'], ''),
      httpJobTitle: _stringValue(json['httpJobTitle'], anime.title.display),
      createdAt: _dateTimeValue(json['createdAt'], now),
      updatedAt: _dateTimeValue(json['updatedAt'], now),
      lastCheckedAt: _nullableDateTimeValue(json['lastCheckedAt']),
      lastError: _nullableStringValue(json['lastError']),
      completionBatchId: _nullableStringValue(json['completionBatchId']),
    );
  }

  Map<String, dynamic> toJson() => {
    'anilistId': anilistId,
    'animeSnapshot': animeSnapshot.toMap(),
    'preferredSource': preferredSource?.name,
    'sourceSelectedByUser': sourceSelectedByUser,
    'resolution': resolution.name,
    'language': language.name,
    'downloadFolder': downloadFolder,
    'httpJobTitle': httpJobTitle,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'lastCheckedAt': lastCheckedAt?.toIso8601String(),
    'lastError': lastError,
    'completionBatchId': completionBatchId,
  };

  TrackedAnime copyWith({
    AnilistAnime? animeSnapshot,
    AnimeSource? preferredSource,
    bool? sourceSelectedByUser,
    Resolution? resolution,
    Language? language,
    String? downloadFolder,
    String? httpJobTitle,
    DateTime? updatedAt,
    DateTime? lastCheckedAt,
    String? lastError,
    String? completionBatchId,
    bool clearPreferredSource = false,
    bool clearLastError = false,
    bool clearCompletionBatchId = false,
  }) {
    return TrackedAnime(
      anilistId: anilistId,
      animeSnapshot: animeSnapshot ?? this.animeSnapshot,
      preferredSource: clearPreferredSource
          ? null
          : (preferredSource ?? this.preferredSource),
      sourceSelectedByUser:
          sourceSelectedByUser ??
          (clearPreferredSource ? false : this.sourceSelectedByUser),
      resolution: resolution ?? this.resolution,
      language: language ?? this.language,
      downloadFolder: downloadFolder ?? this.downloadFolder,
      httpJobTitle: httpJobTitle ?? this.httpJobTitle,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastCheckedAt: lastCheckedAt ?? this.lastCheckedAt,
      lastError: clearLastError ? null : (lastError ?? this.lastError),
      completionBatchId: clearCompletionBatchId
          ? null
          : (completionBatchId ?? this.completionBatchId),
    );
  }
}

@immutable
class TrackingState {
  final List<TrackedAnime> trackedAnime;
  final bool checkInProgress;
  final DateTime? lastCheckStartedAt;
  final DateTime? lastCheckCompletedAt;
  final TrackingEvent? latestEvent;

  const TrackingState({
    this.trackedAnime = const [],
    this.checkInProgress = false,
    this.lastCheckStartedAt,
    this.lastCheckCompletedAt,
    this.latestEvent,
  });

  bool isTracked(int anilistId) =>
      trackedAnime.any((tracked) => tracked.anilistId == anilistId);

  TrackedAnime? trackedById(int anilistId) {
    for (final tracked in trackedAnime) {
      if (tracked.anilistId == anilistId) return tracked;
    }
    return null;
  }

  TrackingState copyWith({
    List<TrackedAnime>? trackedAnime,
    bool? checkInProgress,
    DateTime? lastCheckStartedAt,
    DateTime? lastCheckCompletedAt,
    TrackingEvent? latestEvent,
  }) {
    return TrackingState(
      trackedAnime: trackedAnime ?? this.trackedAnime,
      checkInProgress: checkInProgress ?? this.checkInProgress,
      lastCheckStartedAt: lastCheckStartedAt ?? this.lastCheckStartedAt,
      lastCheckCompletedAt: lastCheckCompletedAt ?? this.lastCheckCompletedAt,
      latestEvent: latestEvent ?? this.latestEvent,
    );
  }
}

Map<String, dynamic> _mapValue(Object? value) =>
    value is Map<String, dynamic> ? value : const {};

String _stringValue(Object? value, String fallback) {
  if (value is String && value.trim().isNotEmpty) return value;
  return fallback;
}

String? _nullableStringValue(Object? value) {
  if (value is! String) return null;
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

int _intValue(Object? value, int fallback) =>
    value is num ? value.toInt() : fallback;

bool _boolValue(Object? value, bool fallback) =>
    value is bool ? value : fallback;

T _enumValue<T extends Enum>(List<T> values, Object? value, T fallback) =>
    _enumOrNull(values, value) ?? fallback;

T? _enumOrNull<T extends Enum>(List<T> values, Object? value) {
  if (value is! String) return null;
  for (final item in values) {
    if (item.name == value) return item;
  }
  return null;
}

DateTime _dateTimeValue(Object? value, DateTime fallback) =>
    _nullableDateTimeValue(value) ?? fallback;

DateTime? _nullableDateTimeValue(Object? value) {
  if (value is! String) return null;
  return DateTime.tryParse(value);
}
