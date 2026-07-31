import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:logging/logging.dart';
import 'package:senpwai/shared/log.dart';

final _log = Logger('senpwai.persistence.secure_token_store');

class SecureTokenStore {
  static const _anilistTokenKey = 'anilist_access_token';
  static const _torrentProxyKey = 'torrent_proxy_configuration';

  final FlutterSecureStorage _storage;

  const SecureTokenStore({
    FlutterSecureStorage storage = const FlutterSecureStorage(
      aOptions: AndroidOptions(
        resetOnError: true,
        preferencesKeyPrefix: 'senpwai_',
      ),
      iOptions: IOSOptions(
        accessibility: KeychainAccessibility.unlocked_this_device,
        synchronizable: false,
      ),
      mOptions: MacOsOptions(
        accessibility: KeychainAccessibility.unlocked_this_device,
        synchronizable: false,
        usesDataProtectionKeychain: false,
      ),
    ),
  }) : _storage = storage;

  Future<String?> readAnilistToken() async {
    try {
      return await _storage.read(key: _anilistTokenKey);
    } on PlatformException catch (error, stackTrace) {
      _log.warningWithMetadata(
        'Failed to read AniList token; deleting the corrupted secure entry',
        metadata: {
          'key': _anilistTokenKey,
          'error': error.toString(),
          'stackTrace': stackTrace.toString(),
        },
      );
      await deleteAnilistToken();
      return null;
    }
  }

  Future<void> writeAnilistToken(String token) {
    return _storage.write(key: _anilistTokenKey, value: token);
  }

  Future<void> deleteAnilistToken() {
    return _storage.delete(key: _anilistTokenKey);
  }

  Future<SecureTorrentProxyConfiguration?>
  readTorrentProxyConfiguration() async {
    try {
      final encoded = await _storage.read(key: _torrentProxyKey);
      if (encoded == null || encoded.isEmpty) return null;
      final decoded = jsonDecode(encoded);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException(
          'Proxy configuration must be a JSON object.',
        );
      }
      return SecureTorrentProxyConfiguration.fromJson(decoded);
    } on Object catch (error, stackTrace) {
      _log.warningWithMetadata(
        'Failed to read torrent proxy configuration; deleting the corrupted secure entry',
        metadata: {
          'key': _torrentProxyKey,
          'error': error.toString(),
          'stackTrace': stackTrace.toString(),
        },
      );
      await deleteTorrentProxyConfiguration();
      return null;
    }
  }

  Future<void> writeTorrentProxyConfiguration(
    SecureTorrentProxyConfiguration configuration,
  ) {
    return _storage.write(
      key: _torrentProxyKey,
      value: jsonEncode(configuration.toJson()),
    );
  }

  Future<void> deleteTorrentProxyConfiguration() {
    return _storage.delete(key: _torrentProxyKey);
  }
}

class SecureTorrentProxyConfiguration {
  final String mode;
  final String host;
  final int port;
  final String username;
  final String password;

  const SecureTorrentProxyConfiguration({
    required this.mode,
    required this.host,
    required this.port,
    required this.username,
    required this.password,
  });

  factory SecureTorrentProxyConfiguration.fromJson(Map<String, dynamic> json) {
    final mode = json['mode'];
    final host = json['host'];
    final port = json['port'];
    final username = json['username'];
    final password = json['password'];
    if (mode is! String ||
        host is! String ||
        port is! int ||
        username is! String ||
        password is! String) {
      throw const FormatException('Invalid torrent proxy configuration.');
    }
    return SecureTorrentProxyConfiguration(
      mode: mode,
      host: host,
      port: port,
      username: username,
      password: password,
    );
  }

  Map<String, dynamic> toJson() => {
    'mode': mode,
    'host': host,
    'port': port,
    'username': username,
    'password': password,
  };
}
