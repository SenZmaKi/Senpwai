import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:senpwai/shared/net/browser_transport/routing.dart';
import 'package:senpwai/shared/net/interceptors/cookie_manager.dart';
import 'package:senpwai/shared/persistence/app_paths.dart';
import 'package:senpwai/updates/manifest_repository.dart';

void main() {
  late Directory directory;
  late AppPaths paths;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('senpwai-manifest-');
    paths = await AppPaths.fromRootDirectory(directory);
  });

  tearDown(() => directory.delete(recursive: true));

  test('verifies, parses, and caches a fetched manifest', () async {
    final adapter = _StaticAdapter('signed-envelope');
    final dio = Dio()..httpClientAdapter = adapter;
    String? decodedEnvelope;
    final repository = UpdateManifestRepository(
      paths: paths,
      dio: dio,
      decodeEnvelope: (envelope) async {
        decodedEnvelope = envelope;
        return _manifestJson();
      },
    );

    final manifest = await repository.fetch();

    expect(manifest.schemaVersion, 1);
    expect(decodedEnvelope, 'signed-envelope');
    expect(await paths.updateManifestFile.readAsString(), 'signed-envelope');
    expect(adapter.request?.headers['Cache-Control'], 'no-cache');
    expect(adapter.request?.extra[skipCookieManagerExtraKey], isTrue);
    expect(
      adapter.request?.extra[transportPreferenceExtraKey],
      TransportPreference.native,
    );
  });

  test(
    'does not replace the cached manifest when verification fails',
    () async {
      await paths.updateManifestFile.writeAsString('known-good');
      final dio = Dio()..httpClientAdapter = _StaticAdapter('tampered');
      final repository = UpdateManifestRepository(
        paths: paths,
        dio: dio,
        decodeEnvelope: (_) async =>
            throw const FormatException('Invalid signature'),
      );

      await expectLater(repository.fetch(), throwsFormatException);

      expect(await paths.updateManifestFile.readAsString(), 'known-good');
    },
  );

  test('rejects decoded but expired manifests before caching', () async {
    final dio = Dio()..httpClientAdapter = _StaticAdapter('expired-envelope');
    final repository = UpdateManifestRepository(
      paths: paths,
      dio: dio,
      decodeEnvelope: (_) async =>
          _manifestJson(expiresAt: '2000-01-01T00:00:00Z'),
    );

    await expectLater(repository.fetch(), throwsFormatException);

    expect(await paths.updateManifestFile.exists(), isFalse);
  });
}

Map<String, dynamic> _manifestJson({
  String expiresAt = '2100-01-01T00:00:00Z',
}) => {
  'schemaVersion': 1,
  'generatedAt': '2026-01-01T00:00:00Z',
  'expiresAt': expiresAt,
  'releases': [],
};

class _StaticAdapter implements HttpClientAdapter {
  final String body;
  RequestOptions? request;

  _StaticAdapter(this.body);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    request = options;
    return ResponseBody.fromString(
      body,
      HttpStatus.ok,
      headers: {
        Headers.contentTypeHeader: ['text/plain; charset=utf-8'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
