import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:dio/dio.dart';
import 'package:logging/logging.dart';
import 'package:senpwai/shared/log.dart';
import 'package:senpwai/shared/persistence/app_paths.dart';

final _log = Logger('senpwai.source_directory');

/// Signed, remotely hosted source endpoints. This intentionally contains no
/// parsers or executable behavior: a source redesign still requires an app
/// update.
class SourceDirectory {
  static const _directoryUri =
      'https://senzmaki.github.io/Senpwai/source-directory.json';
  static const _publicKeyBase64 =
      'tK5qjqlCFmgyiPDwWt3d6zccUuO7fYHsGqxkDUM6lcU=';
  static const _refreshInterval = Duration(hours: 24);

  static SourceDirectory _instance = SourceDirectory.defaults();

  final int version;
  final DateTime expiresAt;
  final SourceEndpoint animePahe;
  final SourceEndpoint kwik;
  final SourceEndpoint nyaa;
  final SourceEndpoint tokyoInsider;

  SourceDirectory({
    required this.version,
    required this.expiresAt,
    required this.animePahe,
    required this.kwik,
    required this.nyaa,
    required this.tokyoInsider,
  });

  factory SourceDirectory.defaults() => SourceDirectory(
    version: 0,
    expiresAt: DateTime.utc(2100),
    animePahe: const SourceEndpoint(
      baseUrl: 'https://animepahe.pw',
      apiEntryPoint: 'https://animepahe.pw/api?m=',
      allowedHosts: {'animepahe.pw'},
    ),
    kwik: const SourceEndpoint(
      baseUrl: 'https://kwik.cx',
      allowedHosts: {'kwik.cx'},
    ),
    nyaa: const SourceEndpoint(
      baseUrl: 'https://nyaa.si',
      allowedHosts: {'nyaa.si'},
      maxConcurrentRequests: 5,
    ),
    tokyoInsider: const SourceEndpoint(
      baseUrl: 'https://www.tokyoinsider.com',
      allowedHosts: {'www.tokyoinsider.com'},
    ),
  );

  static SourceDirectory get instance => _instance;

  static Future<void> initialize({required AppPaths paths}) async {
    final repository = _SourceDirectoryRepository(paths: paths);
    final cached = await repository.loadCached();
    if (cached != null) {
      _instance = cached;
      _log.infoWithMetadata(
        'Using cached source directory',
        metadata: {'version': cached.version, 'expiresAt': cached.expiresAt},
      );
    }
    if (!await repository.shouldRefresh()) return;

    try {
      final fetched = await repository.fetchRemote();
      _instance = fetched;
      await repository.save();
      _log.infoWithMetadata(
        'Updated source directory',
        metadata: {'version': fetched.version, 'expiresAt': fetched.expiresAt},
      );
    } catch (error, stackTrace) {
      _log.warningWithMetadata(
        'Could not refresh source directory; retaining the last valid directory',
        metadata: {'error': error.toString()},
      );
      _log.fine('Source directory refresh stack trace: $stackTrace');
    }
  }

  factory SourceDirectory.fromJson(Map<String, dynamic> json) {
    final expiresAt = DateTime.tryParse(json['expiresAt'] as String? ?? '');
    final sources = json['sources'];
    if (expiresAt == null || sources is! Map<String, dynamic>) {
      throw const FormatException('Invalid source directory payload.');
    }
    final directory = SourceDirectory(
      version: json['version'] as int? ?? 0,
      expiresAt: expiresAt.toUtc(),
      animePahe: SourceEndpoint.fromJson(_source(sources, 'animepahe')),
      kwik: SourceEndpoint.fromJson(_source(sources, 'kwik')),
      nyaa: SourceEndpoint.fromJson(_source(sources, 'nyaa')),
      tokyoInsider: SourceEndpoint.fromJson(_source(sources, 'tokyoinsider')),
    );
    directory._validate();
    return directory;
  }

  static Map<String, dynamic> _source(Map<String, dynamic> sources, String id) {
    final source = sources[id];
    if (source is! Map<String, dynamic>) {
      throw FormatException('Missing source directory entry: $id.');
    }
    return source;
  }

  void _validate() {
    if (!expiresAt.isAfter(DateTime.now().toUtc())) {
      throw const FormatException('Source directory has expired.');
    }
    for (final endpoint in [animePahe, kwik, nyaa, tokyoInsider]) {
      endpoint.validate();
    }
  }
}

class SourceEndpoint {
  final String baseUrl;
  final String? apiEntryPoint;
  final Set<String> allowedHosts;
  final int? maxConcurrentRequests;

  const SourceEndpoint({
    required this.baseUrl,
    this.apiEntryPoint,
    required this.allowedHosts,
    this.maxConcurrentRequests,
  });

  factory SourceEndpoint.fromJson(Map<String, dynamic> json) {
    final hosts = json['allowedHosts'];
    if (json['baseUrl'] is! String || hosts is! List) {
      throw const FormatException('Invalid source endpoint.');
    }
    return SourceEndpoint(
      baseUrl: json['baseUrl'] as String,
      apiEntryPoint: json['apiEntryPoint'] as String?,
      allowedHosts: hosts.whereType<String>().toSet(),
      maxConcurrentRequests: json['maxConcurrentRequests'] as int?,
    );
  }

  void validate() {
    final baseUri = Uri.tryParse(baseUrl);
    if (baseUri == null ||
        baseUri.scheme != 'https' ||
        baseUri.host.isEmpty ||
        baseUri.userInfo.isNotEmpty ||
        baseUri.hasPort ||
        !allowedHosts.contains(baseUri.host)) {
      throw FormatException('Invalid source base URL: $baseUrl');
    }
    if (apiEntryPoint != null) {
      final apiUri = Uri.tryParse(apiEntryPoint!);
      if (apiUri == null ||
          apiUri.scheme != 'https' ||
          !allowedHosts.contains(apiUri.host)) {
        throw FormatException('Invalid source API URL: $apiEntryPoint');
      }
    }
    if (allowedHosts.isEmpty ||
        allowedHosts.length > 8 ||
        allowedHosts.any((host) => !RegExp(r'^[a-z0-9.-]+$').hasMatch(host))) {
      throw const FormatException('Invalid source allowed-host list.');
    }
    if (maxConcurrentRequests != null &&
        (maxConcurrentRequests! < 1 || maxConcurrentRequests! > 20)) {
      throw const FormatException('Invalid source concurrency limit.');
    }
  }
}

class _SourceDirectoryRepository {
  final AppPaths paths;

  _SourceDirectoryRepository({required this.paths});

  Future<SourceDirectory?> loadCached() async {
    if (!await paths.sourceDirectoryFile.exists()) return null;
    try {
      return await _decodeAndVerify(
        await paths.sourceDirectoryFile.readAsString(),
      );
    } catch (error) {
      _log.warningWithMetadata(
        'Ignoring invalid cached source directory',
        metadata: {'error': error.toString()},
      );
      return null;
    }
  }

  Future<bool> shouldRefresh() async {
    if (!await paths.sourceDirectoryFetchStateFile.exists()) return true;
    try {
      final state = jsonDecode(
        await paths.sourceDirectoryFetchStateFile.readAsString(),
      );
      final lastFetched = DateTime.tryParse(
        state['lastFetched'] as String? ?? '',
      );
      return lastFetched == null ||
          DateTime.now().toUtc().difference(lastFetched.toUtc()) >=
              SourceDirectory._refreshInterval;
    } catch (_) {
      return true;
    }
  }

  Future<SourceDirectory> fetchRemote() async {
    final dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 8),
        receiveTimeout: const Duration(seconds: 8),
        responseType: ResponseType.plain,
      ),
    );
    try {
      final response = await dio.get<String>(SourceDirectory._directoryUri);
      if (response.statusCode != HttpStatus.ok || response.data == null) {
        throw HttpException(
          'Source directory returned HTTP ${response.statusCode}.',
        );
      }
      return _decodeAndVerify(response.data!);
    } finally {
      dio.close(force: true);
    }
  }

  Future<void> save() async {
    await paths.sourceDirectoryFile.writeAsString(
      _lastVerifiedEnvelope,
      flush: true,
    );
    await paths.sourceDirectoryFetchStateFile.writeAsString(
      jsonEncode({'lastFetched': DateTime.now().toUtc().toIso8601String()}),
      flush: true,
    );
  }

  late String _lastVerifiedEnvelope;

  Future<SourceDirectory> _decodeAndVerify(String envelopeText) async {
    final envelope = jsonDecode(envelopeText);
    if (envelope is! Map<String, dynamic> ||
        envelope['payload'] is! String ||
        envelope['signature'] is! String) {
      throw const FormatException('Invalid source directory envelope.');
    }
    final payload = base64Url.decode(
      base64Url.normalize(envelope['payload'] as String),
    );
    final signatureBytes = base64.decode(envelope['signature'] as String);
    final publicKeyBytes = base64.decode(SourceDirectory._publicKeyBase64);
    final verified = await Ed25519().verify(
      payload,
      signature: Signature(
        signatureBytes,
        publicKey: SimplePublicKey(publicKeyBytes, type: KeyPairType.ed25519),
      ),
    );
    if (!verified) {
      throw const FormatException('Invalid source directory signature.');
    }
    final decoded = jsonDecode(utf8.decode(payload));
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Invalid source directory payload.');
    }
    _lastVerifiedEnvelope = envelopeText;
    return SourceDirectory.fromJson(decoded);
  }
}
