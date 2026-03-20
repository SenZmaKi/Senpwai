import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';
import 'package:logging/logging.dart';
import 'package:senpwai/shared/log.dart';
import 'package:senpwai/shared/net/user_agents.dart';
import 'package:senpwai/shared/shared.dart';

final _log = Logger("senpwai.shared.net.net_config");

// The default cache key builder does no take the body into account.
// This causes POST requests to the same URL to be served from the cache
// even if the bodies have different content.
String _cacheKeyBuilder({
  required Uri url,
  Map<String, String>? headers,
  Object? body,
}) {
  final bodyString = body?.toString() ?? '';
  final urlString = url.toString();
  final bytes = utf8.encode('$urlString:$bodyString');
  return sha256.convert(bytes).toString();
}

class NetConfig {
  final maxConnectionsPerHost = 25;
  final idleTimeout = Duration(minutes: 3);
  final cacheMaxStale = Duration(hours: 1);
  final userAgent = getRandomUserAgent();
  MemCacheStore? cacheStore;

  static NetConfig? _instance;

  static NetConfig getInstance() {
    return _instance ??= NetConfig();
  }

  CacheOptions buildCacheOptions({
    bool allowPostMethod = false,
    CachePolicy policy = CachePolicy.forceCache,
  }) {
    cacheStore ??= MemCacheStore();
    return CacheOptions(
      store: cacheStore,
      policy: policy,
      maxStale: cacheMaxStale,
      allowPostMethod: allowPostMethod,
      keyBuilder: _cacheKeyBuilder,
    );
  }

  void attachToDio(Dio dio) {
    (dio.httpClientAdapter as IOHttpClientAdapter).createHttpClient = () =>
        HttpClient()
          ..maxConnectionsPerHost = maxConnectionsPerHost
          ..idleTimeout = idleTimeout;
    dio.interceptors.add(DioCacheInterceptor(options: buildCacheOptions()));
    dio.options.headers["User-Agent"] = userAgent;
  }

  void logCache() async {
    if (cacheStore == null) {
      _log.info("Cache is not initialized yet.");
      return;
    }
    final allEntries = await cacheStore!.getFromPath(RegExp('.*'));
    final Map<String, dynamic> entriesMap = allEntries.fold({}, (map, entry) {
      final key = entry.key.toString();
      if (map[key] == null) {
        map[key] = [];
      }
      map[key]!.add({
        "key": entry.key,
        "url": entry.url,
        "statusCode": entry.statusCode,
        "priority": entry.priority,
        "maxStale": entry.maxStale,
        "isStaled": entry.isStaled(),
      });
      return map;
    });
    _log.infoWithMetadata("Cache entries", metadata: {"entries": entriesMap});
  }
}
