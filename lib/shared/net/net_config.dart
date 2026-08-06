import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';
import 'package:http_cache_file_store/http_cache_file_store.dart';
import 'package:logging/logging.dart';
import 'package:senpwai/shared/log.dart';
import 'package:senpwai/shared/net/http_transport.dart';
import 'package:senpwai/shared/net/user_agents.dart';
import 'package:senpwai/shared/persistence/app_paths.dart';

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
  Duration cacheMaxStale = Duration(hours: 1);
  late final HttpTransportConfig transport;
  final AppPaths? paths;
  CacheStore? cacheStore;

  NetConfig({this.paths}) {
    transport = HttpTransportConfig(userAgent: getRandomUserAgent());
  }

  String get userAgent => transport.userAgent;

  static NetConfig? _instance;

  static void initialize({required AppPaths paths}) {
    _instance = NetConfig(paths: paths);
  }

  static NetConfig getInstance() {
    return _instance ??= NetConfig();
  }

  CacheOptions buildCacheOptions({
    bool allowPostMethod = false,
    CachePolicy policy = CachePolicy.forceCache,
  }) {
    cacheStore ??= paths == null
        ? MemCacheStore()
        : FileCacheStore(paths!.networkDioCacheDirectory.path);
    return CacheOptions(
      store: cacheStore,
      policy: policy,
      maxStale: cacheMaxStale,
      allowPostMethod: allowPostMethod,
      keyBuilder: _cacheKeyBuilder,
    );
  }

  void attachToDio(Dio dio) {
    transport.attachToDio(dio);
    dio.interceptors.add(DioCacheInterceptor(options: buildCacheOptions()));
  }

  void updateCacheMaxStale(Duration maxStale) {
    cacheMaxStale = maxStale;
  }

  void logCache() async {
    if (cacheStore == null) {
      _log.info("Cache is not initialized yet.");
      return;
    }
    final allEntries = await cacheStore!.getFromPath(RegExp('.*'));
    _log.infoWithMetadata(
      'Cache summary',
      metadata: {
        'entries': allEntries.length,
        'staleEntries': allEntries.where((entry) => entry.isStaled()).length,
      },
    );
  }
}
