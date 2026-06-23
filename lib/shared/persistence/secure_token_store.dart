import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:logging/logging.dart';
import 'package:senpwai/shared/log.dart';

final _log = Logger('senpwai.persistence.secure_token_store');

class SecureTokenStore {
  static const _anilistTokenKey = 'anilist_access_token';

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
}
