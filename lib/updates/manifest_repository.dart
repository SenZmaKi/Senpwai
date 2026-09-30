import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';
import 'package:senpwai/shared/net/browser_transport/routing.dart';
import 'package:senpwai/shared/net/interceptors/cookie_manager.dart';
import 'package:senpwai/shared/net/net.dart';
import 'package:senpwai/shared/net/net_config.dart';
import 'package:senpwai/shared/persistence/app_paths.dart';
import 'package:senpwai/shared/signed_envelope.dart';
import 'package:senpwai/updates/models.dart';

typedef UpdateManifestDecoder =
    Future<Map<String, dynamic>> Function(String envelope);

class UpdateManifestRepository {
  static const manifestUri = String.fromEnvironment(
    'UPDATE_MANIFEST_URL',
    defaultValue: 'https://senpwai.com/update-manifest.json',
  );

  final AppPaths paths;
  final Dio? _dioOverride;
  final UpdateManifestDecoder _decodeEnvelope;

  UpdateManifestRepository({
    required this.paths,
    Dio? dio,
    UpdateManifestDecoder? decodeEnvelope,
  }) : _dioOverride = dio,
       _decodeEnvelope = decodeEnvelope ?? _decodeUpdateManifestEnvelope;

  Future<UpdateManifest> fetch() async {
    final response = await (_dioOverride ?? GlobalDio.getInstance())
        .get<String>(
          manifestUri,
          options: Options(
            headers: {'Cache-Control': 'no-cache'},
            responseType: ResponseType.plain,
            validateStatus: (status) => status == HttpStatus.ok,
            extra: {
              ...NetConfig.getInstance()
                  .buildCacheOptions(policy: CachePolicy.noCache)
                  .toExtra(),
              skipCookieManagerExtraKey: true,
              transportPreferenceExtraKey: TransportPreference.native,
            },
          ),
        );
    final envelope = response.data;
    if (envelope == null) {
      throw const FormatException('The update manifest response was empty.');
    }
    final manifest = UpdateManifest.fromJson(await _decodeEnvelope(envelope));
    await paths.updateManifestFile.writeAsString(envelope, flush: true);
    return manifest;
  }
}

Future<Map<String, dynamic>> _decodeUpdateManifestEnvelope(String envelope) =>
    decodeSignedJsonEnvelope(
      envelope,
      publicKeyBase64: updateManifestPublicKeyBase64,
    );
