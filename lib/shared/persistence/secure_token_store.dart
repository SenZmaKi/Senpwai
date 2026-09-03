import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:logging/logging.dart';
import 'package:senpwai/settings/models.dart';
import 'package:senpwai/settings/repository.dart';
import 'package:senpwai/shared/log.dart';

final _log = Logger('senpwai.persistence.secure_token_store');

class SecureTokenStore {
  static const _anilistTokenKey = 'anilist_access_token';
  static const _torrentProxyKey = 'torrent_proxy_configuration';

  final FlutterSecureStorage _storage;
  final AppSettingsRepository? _settingsRepository;
  final AppSettings Function()? _readSettings;
  final void Function(AppSettings)? _writeSettings;

  SecureTokenStore({
    this._storage = const FlutterSecureStorage(
      aOptions: AndroidOptions(
        resetOnError: true,
        preferencesKeyPrefix: 'senpwai_',
      ),
      iOptions: IOSOptions(
        accessibility: KeychainAccessibility.unlocked_this_device,
        synchronizable: false,
      ),
      mOptions: MacOsOptions(
        accountName: 'com.senzmaki.senpwai.credentials',
        accessibility: KeychainAccessibility.unlocked_this_device,
        synchronizable: false,
        label: 'Senpwai credentials',
        description: 'Credentials saved by Senpwai',
        usesDataProtectionKeychain: false,
      ),
    ),
    this._settingsRepository,
    this._readSettings,
    this._writeSettings,
  });

  bool get _usesSettings => kDebugMode;

  AppSettings get _settings {
    final readSettings = _readSettings;
    if (readSettings == null) {
      throw StateError('Development settings storage was not configured.');
    }
    return readSettings();
  }

  Future<void> _saveSettings(AppSettings settings) async {
    final repository = _settingsRepository;
    final writeSettings = _writeSettings;
    if (repository == null || writeSettings == null) {
      throw StateError('Development settings storage was not configured.');
    }
    await repository.save(settings);
    writeSettings(settings);
  }

  Future<String?> readAnilistToken() async {
    if (_usesSettings) {
      final token = _settings.anilist.accessToken;
      return token.isEmpty ? null : token;
    }
    try {
      return await _storage.read(key: _anilistTokenKey);
    } on PlatformException catch (error, stackTrace) {
      _log.warningWithMetadata(
        'Failed to read AniList token; preserving the secure entry',
        metadata: {
          'key': _anilistTokenKey,
          'error': error.toString(),
          'stackTrace': stackTrace.toString(),
        },
      );
      return null;
    }
  }

  Future<void> writeAnilistToken(String token) async {
    if (_usesSettings) {
      await _saveSettings(
        _settings.copyWith(
          anilist: _settings.anilist.copyWith(accessToken: token),
        ),
      );
      return;
    }
    return _storage.write(key: _anilistTokenKey, value: token);
  }

  Future<void> deleteAnilistToken() async {
    if (_usesSettings) {
      await _saveSettings(
        _settings.copyWith(
          anilist: _settings.anilist.copyWith(accessToken: ''),
        ),
      );
      return;
    }
    return _storage.delete(key: _anilistTokenKey);
  }

  Future<SecureTorrentProxyConfiguration?>
  readTorrentProxyConfiguration() async {
    if (_usesSettings) {
      final proxy = _settings.torrent;
      return SecureTorrentProxyConfiguration(
        mode: proxy.proxyMode.name,
        host: proxy.proxyHost,
        port: proxy.proxyPort,
        username: proxy.proxyUsername,
        password: proxy.proxyPassword,
      );
    }
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
    } on FormatException catch (error, stackTrace) {
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
    } on PlatformException catch (error, stackTrace) {
      _log.warningWithMetadata(
        'Failed to access torrent proxy configuration; preserving the secure entry',
        metadata: {
          'key': _torrentProxyKey,
          'error': error.toString(),
          'stackTrace': stackTrace.toString(),
        },
      );
      return null;
    }
  }

  Future<void> writeTorrentProxyConfiguration(
    SecureTorrentProxyConfiguration configuration,
  ) async {
    if (_usesSettings) {
      await _saveSettings(
        _settings.copyWith(
          torrent: _settings.torrent.copyWith(
            proxyMode: TorrentProxyMode.values.byName(configuration.mode),
            proxyHost: configuration.host,
            proxyPort: configuration.port,
            proxyUsername: configuration.username,
            proxyPassword: configuration.password,
          ),
        ),
      );
      return;
    }
    return _storage.write(
      key: _torrentProxyKey,
      value: jsonEncode(configuration.toJson()),
    );
  }

  Future<void> deleteTorrentProxyConfiguration() async {
    if (_usesSettings) return;
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
