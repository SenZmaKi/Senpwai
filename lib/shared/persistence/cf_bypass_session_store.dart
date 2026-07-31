import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:logging/logging.dart';
import 'package:senpwai/shared/log.dart';

final _log = Logger('senpwai.persistence.cf_bypass_session_store');

class CfBypassStoredCookie {
  final String name;
  final String value;
  final String domain;
  final String path;
  final bool? isSecure;
  final bool? isHttpOnly;
  final DateTime? expires;

  const CfBypassStoredCookie({
    required this.name,
    required this.value,
    required this.domain,
    required this.path,
    this.isSecure,
    this.isHttpOnly,
    this.expires,
  });

  bool isExpiredAt(DateTime now) => expires != null && !expires!.isAfter(now);

  Map<String, dynamic> toJson() => {
    'name': name,
    'value': value,
    'domain': domain,
    'path': path,
    if (isSecure != null) 'isSecure': isSecure,
    if (isHttpOnly != null) 'isHttpOnly': isHttpOnly,
    if (expires != null) 'expires': expires!.toUtc().toIso8601String(),
  };

  factory CfBypassStoredCookie.fromJson(Map<String, dynamic> json) {
    return CfBypassStoredCookie(
      name: json['name'] as String? ?? '',
      value: json['value'] as String? ?? '',
      domain: json['domain'] as String? ?? '',
      path: json['path'] as String? ?? '/',
      isSecure: json['isSecure'] as bool?,
      isHttpOnly: json['isHttpOnly'] as bool?,
      expires: DateTime.tryParse(json['expires'] as String? ?? ''),
    );
  }
}

class CfBypassHostSession {
  final String host;
  final String networkKey;
  final String? userAgent;
  final List<CfBypassStoredCookie> cookies;
  final DateTime savedAt;

  const CfBypassHostSession({
    required this.host,
    required this.networkKey,
    required this.cookies,
    required this.savedAt,
    this.userAgent,
  });

  CfBypassHostSession withoutExpiredCookies(DateTime now) {
    return CfBypassHostSession(
      host: host,
      networkKey: networkKey,
      userAgent: userAgent,
      cookies: cookies.where((cookie) => !cookie.isExpiredAt(now)).toList(),
      savedAt: savedAt,
    );
  }

  bool isUsableAt(DateTime now, Duration fallbackMaxAge) {
    if (userAgent == null || userAgent!.isEmpty) return false;
    if (now.difference(savedAt) > fallbackMaxAge) return false;
    return cookies.any(
      (cookie) => _isBypassProofCookie(cookie.name) && !cookie.isExpiredAt(now),
    );
  }

  Map<String, dynamic> toJson() => {
    if (userAgent != null) 'userAgent': userAgent,
    'cookies': cookies.map((cookie) => cookie.toJson()).toList(),
    'savedAt': savedAt.toUtc().toIso8601String(),
  };

  factory CfBypassHostSession.fromJson(
    String host,
    String networkKey,
    Map<String, dynamic> json,
  ) {
    final rawCookies = json['cookies'];
    return CfBypassHostSession(
      host: host,
      networkKey: networkKey,
      userAgent: json['userAgent'] as String?,
      cookies: rawCookies is List
          ? rawCookies
                .whereType<Map<String, dynamic>>()
                .map(CfBypassStoredCookie.fromJson)
                .where(
                  (cookie) => cookie.name.isNotEmpty && cookie.value.isNotEmpty,
                )
                .toList()
          : const [],
      savedAt:
          DateTime.tryParse(json['savedAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    );
  }
}

class CfBypassSessionStore {
  static const currentStoreVersion = 3;
  static const maxProfilesPerHost = 8;
  static const fallbackMaxProfileAge = Duration(days: 7);

  final File file;
  Map<String, Map<String, CfBypassHostSession>>? _profilesByHost;
  Set<String> _knownHosts = {};
  Future<void> _operationTail = Future.value();

  CfBypassSessionStore({required this.file});

  Future<bool> hasProfiles() {
    return _serialized(() async {
      final profiles = await _loadAll();
      if (_prune(profiles)) await _save(profiles);
      return profiles.values.any((hostProfiles) => hostProfiles.isNotEmpty);
    });
  }

  Future<Map<String, CfBypassHostSession>> loadForNetwork(String networkKey) {
    return _serialized(() async {
      final profiles = await _loadAll();
      if (_prune(profiles)) await _save(profiles);
      return {
        for (final entry in profiles.entries)
          if (entry.value[networkKey] case final session?) entry.key: session,
      };
    });
  }

  Future<Set<String>> hosts() {
    return _serialized(() async {
      await _loadAll();
      return Set.unmodifiable(_knownHosts);
    });
  }

  Future<void> rememberHost(
    String host, {
    required String networkKey,
    required List<CfBypassStoredCookie> cookies,
    String? userAgent,
  }) {
    return _serialized(() async {
      final profiles = await _loadAll();
      _knownHosts.add(host);
      final now = DateTime.now().toUtc();
      final hostProfiles = profiles.putIfAbsent(host, () => {});
      hostProfiles[networkKey] = CfBypassHostSession(
        host: host,
        networkKey: networkKey,
        userAgent: userAgent,
        cookies: cookies.where((cookie) => !cookie.isExpiredAt(now)).toList(),
        savedAt: now,
      );
      _prune(profiles, now: now);
      await _save(profiles);
    });
  }

  Future<void> forgetHost(String host, {required String networkKey}) {
    return _serialized(() async {
      final profiles = await _loadAll();
      final hostProfiles = profiles[host];
      if (hostProfiles == null || hostProfiles.remove(networkKey) == null) {
        return;
      }
      if (hostProfiles.isEmpty) profiles.remove(host);
      await _save(profiles);
    });
  }

  Future<void> clear() {
    return _serialized(() async {
      _profilesByHost = {};
      _knownHosts = {};
      for (final candidate in [file, _temporaryFile, _backupFile]) {
        if (await candidate.exists()) await candidate.delete();
      }
    });
  }

  File get _temporaryFile => File('${file.path}.tmp');
  File get _backupFile => File('${file.path}.bak');

  Future<Map<String, Map<String, CfBypassHostSession>>> _loadAll() async {
    final cached = _profilesByHost;
    if (cached != null) return cached;

    if (!await file.exists() && await _backupFile.exists()) {
      await _backupFile.rename(file.path);
    }
    if (!await file.exists()) {
      _profilesByHost = {};
      return _profilesByHost!;
    }

    try {
      final decoded = jsonDecode(await file.readAsString());
      final hosts = decoded is Map<String, dynamic>
          ? decoded['hosts'] as Map<String, dynamic>?
          : null;
      _knownHosts = (hosts ?? const <String, dynamic>{}).keys.toSet();
      final version = decoded is Map<String, dynamic>
          ? decoded['version'] as int?
          : null;
      if (version != currentStoreVersion) {
        _profilesByHost = {};
        await _save(_profilesByHost!);
        _log.infoWithMetadata(
          'Discarded a pre-production CF bypass session store',
          metadata: {'previousVersion': version},
        );
        return _profilesByHost!;
      }
      _profilesByHost = {
        for (final hostEntry in (hosts ?? const <String, dynamic>{}).entries)
          if (hostEntry.value case {'profiles': final Map profiles})
            hostEntry.key: {
              for (final profileEntry in profiles.entries)
                if (profileEntry.key is String &&
                    profileEntry.value is Map<String, dynamic>)
                  profileEntry.key as String: CfBypassHostSession.fromJson(
                    hostEntry.key,
                    profileEntry.key as String,
                    profileEntry.value as Map<String, dynamic>,
                  ),
            },
      };
    } catch (error, stackTrace) {
      _log.warningWithMetadata(
        'Failed to load CF bypass sessions; starting with an empty store',
        metadata: {
          'path': file.path,
          'error': error.toString(),
          'stackTrace': stackTrace.toString(),
        },
      );
      _profilesByHost = {};
    }

    return _profilesByHost!;
  }

  bool _prune(
    Map<String, Map<String, CfBypassHostSession>> profiles, {
    DateTime? now,
  }) {
    final resolvedNow = now ?? DateTime.now().toUtc();
    var changed = false;
    for (final hostEntry in profiles.entries.toList()) {
      final hostProfiles = hostEntry.value;
      for (final profileEntry in hostProfiles.entries.toList()) {
        final session = profileEntry.value;
        if (!session.isUsableAt(resolvedNow, fallbackMaxProfileAge)) {
          hostProfiles.remove(profileEntry.key);
          changed = true;
          continue;
        }
        final filtered = session.withoutExpiredCookies(resolvedNow);
        if (filtered.cookies.length != session.cookies.length) {
          hostProfiles[profileEntry.key] = filtered;
          changed = true;
        }
      }

      if (hostProfiles.length > maxProfilesPerHost) {
        final oldestFirst = hostProfiles.values.toList()
          ..sort((a, b) => a.savedAt.compareTo(b.savedAt));
        for (final session in oldestFirst.take(
          hostProfiles.length - maxProfilesPerHost,
        )) {
          hostProfiles.remove(session.networkKey);
          changed = true;
        }
      }
      if (hostProfiles.isEmpty) profiles.remove(hostEntry.key);
    }
    return changed;
  }

  Future<void> _save(
    Map<String, Map<String, CfBypassHostSession>> profiles,
  ) async {
    await file.parent.create(recursive: true);
    const encoder = JsonEncoder.withIndent('  ');
    await _temporaryFile.writeAsString(
      encoder.convert({
        'version': currentStoreVersion,
        'hosts': {
          for (final host in _knownHosts)
            host: {
              'profiles': {
                for (final profileEntry in (profiles[host] ?? const {}).entries)
                  profileEntry.key: profileEntry.value.toJson(),
              },
            },
        },
      }),
      flush: true,
    );

    if (await _backupFile.exists()) await _backupFile.delete();
    if (await file.exists()) await file.rename(_backupFile.path);
    try {
      await _temporaryFile.rename(file.path);
      if (await _backupFile.exists()) await _backupFile.delete();
    } catch (_) {
      if (!await file.exists() && await _backupFile.exists()) {
        await _backupFile.rename(file.path);
      }
      rethrow;
    }
  }

  Future<T> _serialized<T>(Future<T> Function() operation) {
    final completer = Completer<T>();
    _operationTail = _operationTail.then((_) async {
      try {
        completer.complete(await operation());
      } catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      }
    });
    return completer.future;
  }
}

bool _isBypassProofCookie(String name) {
  return name == 'cf_clearance' || name.toLowerCase().startsWith('__ddg');
}
