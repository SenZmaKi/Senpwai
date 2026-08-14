import 'dart:async';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';
import 'package:senpwai/shared/net/interceptors/cf_bypass.dart';
import 'package:senpwai/shared/net/interceptors/cookie_manager.dart';
import 'package:senpwai/shared/net/net.dart';
import 'package:senpwai/shared/net/net_config.dart';
import 'package:senpwai/updates/models.dart';

class UpdateDownloadCancelled implements Exception {
  const UpdateDownloadCancelled();
}

class UpdateDownloader {
  CancelToken? _cancelToken;

  bool get isDownloading => _cancelToken != null;

  Future<void> download({
    required UpdateArtifact artifact,
    required File destination,
    required void Function(int received, int total) onProgress,
  }) async {
    if (_cancelToken != null) {
      throw StateError('An update download is already running.');
    }
    final cancelToken = CancelToken();
    _cancelToken = cancelToken;
    var lastProgressAt = DateTime.fromMillisecondsSinceEpoch(0);
    try {
      await destination.parent.create(recursive: true);
      if (await destination.exists()) await destination.delete();
      await GlobalDio.getInstance().download(
        artifact.url.toString(),
        destination.path,
        cancelToken: cancelToken,
        deleteOnError: true,
        options: Options(
          headers: {'Cache-Control': 'no-cache'},
          extra: {
            ...NetConfig.getInstance()
                .buildCacheOptions(policy: CachePolicy.noCache)
                .toExtra(),
            skipCookieManagerExtraKey: true,
            skipCfBypassExtraKey: true,
          },
        ),
        onReceiveProgress: (received, total) {
          final now = DateTime.now();
          if (received != total &&
              now.difference(lastProgressAt) <
                  const Duration(milliseconds: 100)) {
            return;
          }
          lastProgressAt = now;
          onProgress(received, total > 0 ? total : artifact.sizeBytes);
        },
      );
    } on DioException catch (error) {
      if (CancelToken.isCancel(error)) throw const UpdateDownloadCancelled();
      rethrow;
    } finally {
      if (identical(_cancelToken, cancelToken)) _cancelToken = null;
    }
  }

  void cancel() {
    _cancelToken?.cancel('Update download cancelled by the user.');
  }

  Future<void> verify(File file, UpdateArtifact artifact) async {
    final size = await file.length();
    if (size != artifact.sizeBytes) {
      throw FormatException(
        'Update size mismatch: expected ${artifact.sizeBytes} bytes, received $size.',
      );
    }
    final digest = await sha256.bind(file.openRead()).first;
    if (digest.toString() != artifact.sha256) {
      throw const FormatException('Update checksum verification failed.');
    }
  }
}
