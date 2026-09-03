import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';
import 'package:senpwai/shared/net/interceptors/cf_bypass.dart';
import 'package:senpwai/shared/net/interceptors/cookie_manager.dart';
import 'package:senpwai/shared/net/net.dart';
import 'package:senpwai/shared/net/net_config.dart';
import 'package:senpwai/shared/persistence/app_paths.dart';
import 'package:senpwai/shared/signed_envelope.dart';
import 'package:senpwai/updates/models.dart';

class UpdateManifestRepository {
  static const manifestUri = String.fromEnvironment(
    'UPDATE_MANIFEST_URL',
    defaultValue: 'https://senzmaki.github.io/Senpwai/update-manifest.json',
  );

  final AppPaths paths;

  const UpdateManifestRepository({required this.paths});

  Future<UpdateManifest> fetch() async {
    final response = await GlobalDio.getInstance().get<String>(
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
          skipCfBypassExtraKey: true,
        },
      ),
    );
    final envelope = response.data;
    if (envelope == null) {
      throw const FormatException('The update manifest response was empty.');
    }
    final manifest = UpdateManifest.fromJson(
      await decodeSignedJsonEnvelope(
        envelope,
        publicKeyBase64: updateManifestPublicKeyBase64,
      ),
    );
    await paths.updateManifestFile.writeAsString(envelope, flush: true);
    return manifest;
  }
}
