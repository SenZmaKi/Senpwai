// ignore_for_file: avoid_print, implementation_imports

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cf_bypass/src/cf_detection.dart';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:dotenv/dotenv.dart' as dotenv;

const _skipCookieManagerExtraKey = 'skipCookieManager';

Future<void> main(List<String> args) async {
  final options = ReplayOptions.parse(args);
  if (options.showHelp) {
    print(ReplayOptions.usage);
    return;
  }

  final replay = AnimePaheReplay(options);
  await replay.seed();

  print('AnimePahe CF replay');
  print('Host: ${options.host}');
  print('Queries: ${options.queries.join(' -> ')}');
  print('Seeded UA: ${replay.hasUserAgent ? 'yes' : 'no'}');
  print('Seeded cookies: ${replay.seededCookieNames.join(', ')}');
  print('');

  for (final query in options.queries) {
    final result = await replay.search(query);
    result.printSummary();
    print('');
    if (result.detection.isProtected && options.stopOnChallenge) {
      print(
        'Stopping because this request returned ${result.detection.kind.name}. '
        'Run with --continue-on-challenge to replay the remaining queries.',
      );
      break;
    }
  }
}

class AnimePaheReplay {
  final ReplayOptions options;
  final CookieJar cookieJar = CookieJar();
  late final Dio dio;
  String? _userAgent;
  String? _rememberedCookieHeader;
  final seededCookieNames = <String>{};

  AnimePaheReplay(this.options) {
    dio = Dio(
      BaseOptions(
        followRedirects: true,
        responseType: ResponseType.plain,
        receiveDataWhenStatusError: true,
        validateStatus: (_) => true,
      ),
    );
    (dio.httpClientAdapter as IOHttpClientAdapter).createHttpClient = () =>
        HttpClient()
          ..maxConnectionsPerHost = 25
          ..idleTimeout = const Duration(minutes: 3);
    dio.interceptors.add(_ReplayCookieManager(cookieJar));
    dio.interceptors.add(
      DioCacheInterceptor(
        options: CacheOptions(
          store: MemCacheStore(),
          policy: CachePolicy.noCache,
          maxStale: const Duration(hours: 1),
        ),
      ),
    );
  }

  bool get hasUserAgent => _userAgent != null && _userAgent!.isNotEmpty;

  Future<void> seed() async {
    if (!options.noEnv) await _seedFromEnv();
    if (options.userAgent != null) _userAgent = options.userAgent;
    if (options.cookieHeader != null) {
      _rememberedCookieHeader = options.cookieHeader;
      seededCookieNames.addAll(_cookieNamesFromHeader(options.cookieHeader));
      await _saveCookieHeader(options.cookieHeader!, Uri.parse(options.origin));
    }
  }

  Future<void> _seedFromEnv() async {
    final env = dotenv.DotEnv(includePlatformEnvironment: true, quiet: true);
    final envPath = options.envPath;
    if (File(envPath).existsSync()) {
      env.load([envPath]);
    } else {
      env.load();
    }

    final userAgent = env['ANIMEPAHE_USER_AGENT'];
    if (userAgent != null && userAgent.isNotEmpty) _userAgent = userAgent;

    final cookiesRaw = env['ANIMEPAHE_COOKIES'];
    if (cookiesRaw == null || cookiesRaw.isEmpty) return;

    for (final entry in cookiesRaw.split('|')) {
      final domainAndPairs = _splitDomainCookieEntry(entry);
      if (domainAndPairs == null) continue;
      final (domain, pairs) = domainAndPairs;
      final sourceUri = Uri.parse(
        domain.startsWith('http') ? domain : 'https://$domain',
      );
      final sourceHost = _normalizeHost(sourceUri.host);
      final targetUri = _isSameOrParentHost(sourceHost, options.host)
          ? Uri.parse(options.origin)
          : sourceUri;
      await _saveCookieHeader(pairs, targetUri);
      if (_isSameOrParentHost(sourceHost, options.host)) {
        _rememberedCookieHeader = _mergeCookieHeaders(
          _rememberedCookieHeader,
          pairs,
        );
      }
      seededCookieNames.addAll(_cookieNamesFromHeader(pairs));
    }
  }

  Future<ReplayResult> search(String query) async {
    final uri = Uri.https(options.host, '/api', {
      'm': 'search',
      'q': query,
      'page': '1',
    });
    final stopwatch = Stopwatch()..start();
    final headers = <String, dynamic>{};
    _applyBrowserHeaders(headers, uri);
    if (_userAgent != null) headers['User-Agent'] = _userAgent;

    var cookieHeader = _rememberedCookieHeader;
    final jarCookies = await cookieJar.loadForRequest(uri);
    if (jarCookies.isNotEmpty) {
      cookieHeader = _mergeCookieHeaders(
        jarCookies.map((cookie) => '${cookie.name}=${cookie.value}').join('; '),
        cookieHeader,
      );
    }
    if (cookieHeader != null && cookieHeader.isNotEmpty) {
      headers[HttpHeaders.cookieHeader] = cookieHeader;
    }

    final response = await dio.getUri<dynamic>(
      uri,
      options: Options(
        headers: headers,
        extra: {
          _skipCookieManagerExtraKey: cookieHeader != null,
          ..._noCacheExtra(),
        },
      ),
    );
    stopwatch.stop();

    final responseBody = response.data is String ? response.data as String : '';
    final detection = CfDetector.detect(
      CfDetectionRequest(
        url: uri.toString(),
        statusCode: response.statusCode ?? 0,
        body: responseBody,
        headers: _flatHeaders(response.headers),
        source: 'animepahe-cf-replay',
      ),
    );

    final setCookieNames = _setCookieNames(response.headers);
    final jarCookieNames = (await cookieJar.loadForRequest(
      uri,
    )).map((cookie) => cookie.name).toSet().toList()..sort();

    return ReplayResult(
      query: query,
      uri: uri,
      statusCode: response.statusCode ?? 0,
      elapsed: stopwatch.elapsed,
      detection: detection,
      requestCookieNames: _cookieNamesFromHeader(cookieHeader),
      requestHadUserAgent: headers.containsKey('User-Agent'),
      requestHadBrowserHeaders:
          headers.containsKey('Accept') &&
          headers.containsKey('Accept-Language') &&
          headers.containsKey('Referer'),
      setCookieNames: setCookieNames,
      jarCookieNames: jarCookieNames,
      contentType: response.headers.value(HttpHeaders.contentTypeHeader),
      resultPreview: _previewResponse(responseBody, detection),
    );
  }

  Future<void> _saveCookieHeader(String header, Uri uri) async {
    final cookies = <Cookie>[];
    for (final entry in _cookiePairsFromHeader(header).entries) {
      cookies.add(Cookie(entry.key, entry.value)..path = '/');
    }
    if (cookies.isNotEmpty) await cookieJar.saveFromResponse(uri, cookies);
  }

  bool _isSameOrParentHost(String sourceHost, String targetHost) {
    final normalizedTarget = _normalizeHost(targetHost);
    return sourceHost == normalizedTarget ||
        normalizedTarget.endsWith('.$sourceHost');
  }

  String _normalizeHost(String host) => host.startsWith('.')
      ? host.substring(1).toLowerCase()
      : host.toLowerCase();

  (String, String)? _splitDomainCookieEntry(String entry) {
    final schemeIdx = entry.indexOf('://');
    final separatorIdx = schemeIdx == -1
        ? entry.indexOf(':')
        : entry.indexOf(':', schemeIdx + 3);
    if (separatorIdx <= 0) return null;
    return (
      entry.substring(0, separatorIdx),
      entry.substring(separatorIdx + 1),
    );
  }

  void _applyBrowserHeaders(Map<String, dynamic> headers, Uri uri) {
    headers.putIfAbsent(
      'Accept',
      () => 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
    );
    headers.putIfAbsent('Accept-Language', () => 'en-US,en;q=0.9');
    headers.putIfAbsent('Referer', () => '${uri.scheme}://${uri.host}/');
  }

  Map<String, dynamic> _noCacheExtra() {
    return CacheOptions(
      store: MemCacheStore(),
      policy: CachePolicy.noCache,
    ).toExtra();
  }
}

class _ReplayCookieManager extends CookieManager {
  _ReplayCookieManager(super.cookieJar);

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (options.extra[_skipCookieManagerExtraKey] == true) {
      handler.next(options);
      return;
    }
    await super.onRequest(options, handler);
  }

  @override
  Future<void> onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) async {
    await super.onResponse(response, handler);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    await super.onError(err, handler);
  }
}

class ReplayResult {
  final String query;
  final Uri uri;
  final int statusCode;
  final Duration elapsed;
  final CfDetectionResult detection;
  final List<String> requestCookieNames;
  final bool requestHadUserAgent;
  final bool requestHadBrowserHeaders;
  final List<String> setCookieNames;
  final List<String> jarCookieNames;
  final String? contentType;
  final String resultPreview;

  const ReplayResult({
    required this.query,
    required this.uri,
    required this.statusCode,
    required this.elapsed,
    required this.detection,
    required this.requestCookieNames,
    required this.requestHadUserAgent,
    required this.requestHadBrowserHeaders,
    required this.setCookieNames,
    required this.jarCookieNames,
    required this.contentType,
    required this.resultPreview,
  });

  void printSummary() {
    print('Request: $query');
    print('URL: $uri');
    print(
      'Sent: ua=${requestHadUserAgent ? 'yes' : 'no'}, '
      'browserHeaders=${requestHadBrowserHeaders ? 'yes' : 'no'}, '
      'cookies=${requestCookieNames.isEmpty ? '(none)' : requestCookieNames.join(', ')}',
    );
    print(
      'Response: $statusCode in ${elapsed.inMilliseconds}ms, '
      'contentType=${contentType ?? '(none)'}',
    );
    print(
      'CF: kind=${detection.kind.name}, '
      'indicators=${detection.matchedIndicators.isEmpty ? '(none)' : detection.matchedIndicators.join(', ')}',
    );
    print(
      'Set-Cookie: ${setCookieNames.isEmpty ? '(none)' : setCookieNames.join(', ')}',
    );
    print(
      'Jar after response: ${jarCookieNames.isEmpty ? '(none)' : jarCookieNames.join(', ')}',
    );
    print('Preview: $resultPreview');
  }
}

class ReplayOptions {
  final String host;
  final String envPath;
  final bool noEnv;
  final bool showHelp;
  final bool stopOnChallenge;
  final String? userAgent;
  final String? cookieHeader;
  final List<String> queries;

  const ReplayOptions({
    required this.host,
    required this.envPath,
    required this.noEnv,
    required this.showHelp,
    required this.stopOnChallenge,
    required this.userAgent,
    required this.cookieHeader,
    required this.queries,
  });

  String get origin => 'https://$host/';

  static const usage = '''
Usage:
  dart run tool/animepahe_cf_replay.dart [options]

Options:
  --query <text>                 Add a query to replay. Can be repeated.
  --first <text>                 First query. Default: Witch Hat Atelier.
  --second <text>                Second query. Default: Jujutsu Kaisen.
  --host <host>                  AnimePaHe host. Default: animepahe.pw.
  --env <path>                   Env file to read. Default: .env.
  --no-env                       Do not read ANIMEPAHE_* values from env.
  --user-agent <ua>              Seed a solved browser user-agent.
  --cookie-header <header>       Seed solved Cookie header. Values are not printed.
  --continue-on-challenge        Continue after a CF challenge response.
  --help                         Show this help.

Env support:
  ANIMEPAHE_USER_AGENT=<ua>
  ANIMEPAHE_COOKIES=animepahe.pw:name=value; other=value|other.host:a=b
''';

  factory ReplayOptions.parse(List<String> args) {
    var host = 'animepahe.pw';
    var envPath = '.env';
    var noEnv = false;
    var showHelp = false;
    var stopOnChallenge = true;
    String? userAgent;
    String? cookieHeader;
    String? first;
    String? second;
    final queries = <String>[];

    for (var i = 0; i < args.length; i++) {
      final arg = args[i];
      String takeValue() {
        if (i + 1 >= args.length) {
          throw ArgumentError('Missing value for $arg');
        }
        return args[++i];
      }

      switch (arg) {
        case '--help':
        case '-h':
          showHelp = true;
        case '--host':
          host = takeValue();
        case '--env':
          envPath = takeValue();
        case '--no-env':
          noEnv = true;
        case '--user-agent':
          userAgent = takeValue();
        case '--cookie-header':
          cookieHeader = takeValue();
        case '--query':
          queries.add(takeValue());
        case '--first':
          first = takeValue();
        case '--second':
          second = takeValue();
        case '--continue-on-challenge':
          stopOnChallenge = false;
        default:
          throw ArgumentError('Unknown argument: $arg\n\n$usage');
      }
    }

    if (queries.isEmpty) {
      queries
        ..add(first ?? 'Witch Hat Atelier')
        ..add(second ?? 'Jujutsu Kaisen');
    }

    return ReplayOptions(
      host: host,
      envPath: envPath,
      noEnv: noEnv,
      showHelp: showHelp,
      stopOnChallenge: stopOnChallenge,
      userAgent: userAgent,
      cookieHeader: cookieHeader,
      queries: queries,
    );
  }
}

Map<String, String> _flatHeaders(Headers headers) {
  final flattened = <String, String>{};
  headers.forEach((name, values) {
    flattened[name.toLowerCase()] = values.join(', ');
  });
  return flattened;
}

List<String> _setCookieNames(Headers headers) {
  final values = headers[HttpHeaders.setCookieHeader] ?? const <String>[];
  return values
      .map((header) {
        final eqIdx = header.indexOf('=');
        if (eqIdx <= 0) return null;
        return header.substring(0, eqIdx).trim();
      })
      .whereType<String>()
      .where((name) => name.isNotEmpty)
      .toSet()
      .toList()
    ..sort();
}

List<String> _cookieNamesFromHeader(String? header) {
  if (header == null || header.isEmpty) return const [];
  return _cookiePairsFromHeader(header).keys.toList()..sort();
}

String? _mergeCookieHeaders(String? first, String? second) {
  final pairs = <String, String>{};
  if (first != null) pairs.addAll(_cookiePairsFromHeader(first));
  if (second != null) pairs.addAll(_cookiePairsFromHeader(second));
  if (pairs.isEmpty) return null;
  return pairs.entries.map((entry) => '${entry.key}=${entry.value}').join('; ');
}

Map<String, String> _cookiePairsFromHeader(String header) {
  final pairs = <String, String>{};
  for (final part in header.split(';')) {
    final trimmed = part.trim();
    final eqIdx = trimmed.indexOf('=');
    if (eqIdx <= 0) continue;
    final name = trimmed.substring(0, eqIdx).trim();
    final value = trimmed.substring(eqIdx + 1).trim();
    if (name.isEmpty) continue;
    pairs[name] = value;
  }
  return pairs;
}

String _previewResponse(String body, CfDetectionResult detection) {
  final compact = body.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (detection.isProtected) {
    return compact.length <= 220 ? compact : '${compact.substring(0, 220)}...';
  }

  try {
    final decoded = jsonDecode(body);
    if (decoded case {'data': final List<dynamic> items}) {
      final titles = items
          .take(3)
          .map((item) => item is Map ? item['title'] : null)
          .whereType<Object>()
          .join(' | ');
      return '${items.length} items${titles.isEmpty ? '' : ': $titles'}';
    }
    if (decoded is Map) {
      return 'json keys: ${decoded.keys.take(8).join(', ')}';
    }
  } catch (_) {
    // Fall through to text preview.
  }

  if (compact.length <= 220) return compact;
  return '${compact.substring(0, 220)}...';
}
