import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:logging/logging.dart';
import 'package:senpwai/shared/log.dart';
import 'package:senpwai/shared/net/http2_preferred_adapter.dart';

final _log = Logger('senpwai.net.cf_egress_identity');

class CfEgressIdentity {
  final String key;
  final String? colo;
  final String? warp;

  const CfEgressIdentity({required this.key, this.colo, this.warp});
}

class CfEgressIdentityResolver {
  static final _traceUri = Uri.https('cloudflare.com', '/cdn-cgi/trace');
  static const _timeout = Duration(seconds: 5);

  CfEgressIdentity? _cached;
  Future<CfEgressIdentity?>? _inFlight;

  Future<CfEgressIdentity?> resolve({bool forceRefresh = false}) {
    final cached = _cached;
    if (!forceRefresh && cached != null) {
      return Future.value(cached);
    }
    final inFlight = _inFlight;
    if (inFlight != null) return inFlight;

    final lookup = _resolve().whenComplete(() => _inFlight = null);
    _inFlight = lookup;
    return lookup;
  }

  Future<CfEgressIdentity?> _resolve() async {
    final dio = Dio(
      BaseOptions(
        connectTimeout: _timeout,
        receiveTimeout: _timeout,
        responseType: ResponseType.plain,
        validateStatus: (_) => true,
      ),
    );
    preferHttp2(dio);

    try {
      final response = await dio.getUri<String>(_traceUri);
      if (response.statusCode != 200) {
        _log.warningWithMetadata(
          'CF egress lookup returned an unexpected status',
          metadata: {'statusCode': response.statusCode},
        );
        return null;
      }

      final fields = <String, String>{};
      for (final line in (response.data ?? '').split('\n')) {
        final separator = line.indexOf('=');
        if (separator <= 0) continue;
        fields[line.substring(0, separator)] = line.substring(separator + 1);
      }

      final ip = fields['ip'];
      if (ip == null || ip.isEmpty) {
        _log.warning('CF egress lookup did not return an IP address');
        return null;
      }

      final key = sha256
          .convert(utf8.encode('senpwai-cf-egress-v1:$ip'))
          .toString();
      final identity = CfEgressIdentity(
        key: key,
        colo: fields['colo'],
        warp: fields['warp'],
      );
      _cached = identity;
      _log.infoWithMetadata(
        'Resolved CF-facing network identity',
        metadata: {
          'networkId': identity.key.substring(0, 12),
          'colo': identity.colo,
          'warp': identity.warp,
        },
      );
      return identity;
    } catch (error, stackTrace) {
      _log.warningWithMetadata(
        'CF egress lookup failed',
        metadata: {
          'error': error.toString(),
          'stackTrace': stackTrace.toString(),
        },
      );
      return null;
    } finally {
      dio.close(force: true);
    }
  }
}
