import 'dart:convert';
import 'dart:io';

import 'package:logging/logging.dart';
import 'package:senpwai/shared/log.dart';

final _log = Logger('senpwai.persistence.cf_bypass_session_store');

class CfBypassHostSession {
  final String host;
  final String? userAgent;

  const CfBypassHostSession({required this.host, this.userAgent});

  Map<String, dynamic> toJson() => {
    if (userAgent != null) 'userAgent': userAgent,
  };

  factory CfBypassHostSession.fromJson(String host, Object? json) {
    if (json is! Map<String, dynamic>) {
      return CfBypassHostSession(host: host);
    }
    return CfBypassHostSession(
      host: host,
      userAgent: json['userAgent'] as String?,
    );
  }
}

class CfBypassSessionStore {
  final File file;
  Map<String, CfBypassHostSession>? _sessions;

  CfBypassSessionStore({required this.file});

  Future<Map<String, CfBypassHostSession>> load() async {
    final cached = _sessions;
    if (cached != null) return cached;

    if (!await file.exists()) {
      _sessions = {};
      return _sessions!;
    }

    try {
      final decoded = jsonDecode(await file.readAsString());
      final hosts = decoded is Map<String, dynamic>
          ? decoded['hosts'] as Map<String, dynamic>?
          : null;
      _sessions = {
        for (final entry in (hosts ?? const <String, dynamic>{}).entries)
          entry.key: CfBypassHostSession.fromJson(entry.key, entry.value),
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
      _sessions = {};
    }

    return _sessions!;
  }

  Future<void> rememberHost(String host, {String? userAgent}) async {
    final sessions = await load();
    sessions[host] = CfBypassHostSession(host: host, userAgent: userAgent);
    await _save(sessions);
  }

  Future<void> clear() async {
    _sessions = {};
    if (await file.exists()) {
      await file.delete();
    }
  }

  Future<void> _save(Map<String, CfBypassHostSession> sessions) async {
    await file.parent.create(recursive: true);
    const encoder = JsonEncoder.withIndent('  ');
    await file.writeAsString(
      encoder.convert({
        'version': 1,
        'hosts': {
          for (final entry in sessions.entries) entry.key: entry.value.toJson(),
        },
      }),
      flush: true,
    );
  }
}
