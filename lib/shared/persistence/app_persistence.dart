import 'dart:io';

import 'package:senpwai/shared/net/net.dart';
import 'package:senpwai/shared/net/net_config.dart';
import 'package:senpwai/shared/persistence/app_image_cache.dart';
import 'package:senpwai/shared/persistence/app_paths.dart';
import 'package:senpwai/shared/persistence/cf_bypass_session_store.dart';
import 'package:senpwai/shared/persistence/secure_token_store.dart';

class AppPersistence {
  static AppPaths? _paths;
  static CfBypassSessionStore? _cfBypassSessionStore;
  static SecureTokenStore? _secureTokenStore;

  AppPersistence._();

  static AppPaths get paths {
    final resolved = _paths;
    if (resolved == null) {
      throw StateError('AppPersistence.initialize must be called first.');
    }
    return resolved;
  }

  static SecureTokenStore get secureTokenStore {
    final resolved = _secureTokenStore;
    if (resolved == null) {
      throw StateError('AppPersistence.initialize must be called first.');
    }
    return resolved;
  }

  static CfBypassSessionStore get cfBypassSessionStore {
    final resolved = _cfBypassSessionStore;
    if (resolved == null) {
      throw StateError('AppPersistence.initialize must be called first.');
    }
    return resolved;
  }

  static Future<void> initialize({Directory? rootDirectory}) async {
    if (_paths != null) return;

    final initializedPaths = rootDirectory == null
        ? await AppPaths.initialize()
        : await AppPaths.fromRootDirectory(rootDirectory);
    final cfStore = CfBypassSessionStore(file: initializedPaths.cfSessionsFile);
    const tokenStore = SecureTokenStore();

    _paths = initializedPaths;
    _cfBypassSessionStore = cfStore;
    _secureTokenStore = tokenStore;

    NetConfig.initialize(paths: initializedPaths);
    AppImageCache.initialize(initializedPaths);
    await GlobalDio.initialize(
      paths: initializedPaths,
      cfBypassSessionStore: cfStore,
    );
  }

  static Future<void> clearNetworkSession() async {
    GlobalDio.cfBypassInterceptor?.clearRememberedSessions();
    await Future.wait([
      cfBypassSessionStore.clear(),
      GlobalDio.cookieJar.deleteAll(),
    ]);
  }

  static Future<void> clearHttpCache() async {
    await NetConfig.getInstance().cacheStore?.clean();
  }

  static Future<void> clearImageCache() async {
    await AppImageCache.manager.emptyCache();
  }
}
