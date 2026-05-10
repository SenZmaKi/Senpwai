import 'dart:async';

import 'package:cf_bypass/cf_bypass.dart' hide LoggerExtensions;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:senpwai/shared/dev_config.dart';
import 'package:senpwai/shared/net/net.dart';
import 'package:senpwai/ui/pages/anime_page/cf_bypass_page.dart';
import 'package:senpwai/ui/shared/anilist.dart';
import 'package:senpwai/ui/shared/theme/theme.dart';
import 'package:senpwai/ui/components/toast.dart';
import 'package:senpwai/ui/pages/downloads_page.dart';
import 'package:senpwai/ui/pages/home_page.dart';
import 'package:senpwai/ui/pages/search_page/search_page.dart';
import 'package:senpwai/ui/pages/settings_page/settings_page.dart';
import 'package:senpwai/ui/components/app_shell.dart';
import 'package:toastification/toastification.dart';
import 'package:flutter/foundation.dart';
import 'package:senpwai/shared/log.dart';
import 'package:senpwai/ui/shared/window_manager.dart';

Future<void> initApp() async {
  WidgetsFlutterBinding.ensureInitialized();
  setupLogger();
  applyDevConfig();
  _initCfBypassSolver();

  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    final ctx = App.navigatorKey.currentContext;
    if (ctx != null) {
      AppToast.showError(
        ctx,
        title: 'Unexpected error',
        description: details.exceptionAsString(),
        copyPayload: formatErrorForCopy(details.exception, details.stack),
      );
    }
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    final ctx = App.navigatorKey.currentContext;
    if (ctx != null) {
      AppToast.showError(
        ctx,
        title: 'Unhandled error',
        description: error.toString(),
        copyPayload: formatErrorForCopy(error, stack),
      );
    }

    return true;
  };
  WindowManager.getInstance().init();
}

/// Wires a CF bypass solver that pushes [CfBypassPage] when a challenge is detected.
void _initCfBypassSolver() {
  // Ensure Dio (and its interceptor) is initialized.
  GlobalDio.getInstance();
  GlobalDio.cfBypassInterceptor?.setSolver((url) async {
    final ctx = App.navigatorKey.currentContext;
    if (ctx == null) {
      return CfBypassResult(
        success: false,
        url: url,
        error: 'No navigation context available',
        cookies: [],
      );
    }
    final result = await Navigator.of(ctx).push<CfBypassResult>(
      MaterialPageRoute(builder: (_) => CfBypassPage(url: url)),
    );
    return result ??
        CfBypassResult(
          success: false,
          url: url,
          error: 'User cancelled CF bypass',
          cookies: [],
        );
  });
}

class App extends ConsumerWidget {
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  const App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeConfig = ref.watch(ThemeConfigNotifier.provider);
    return ToastificationWrapper(
      child: MaterialApp(
        navigatorKey: navigatorKey,
        title: 'Senpwai',
        theme: themeConfig.buildLightTheme(),
        darkTheme: themeConfig.buildDarkTheme(),
        themeMode: themeConfig.themeMode,
        home: const _AppRoot(),
      ),
    );
  }
}

class _AppRoot extends ConsumerStatefulWidget {
  const _AppRoot();

  @override
  ConsumerState<_AppRoot> createState() => _AppRootState();
}

class _AppRootState extends ConsumerState<_AppRoot> {
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    unawaited(ref.read(AnilistNotifier.provider.notifier).initialize());
  }

  Future<void> _handleLogin() async {
    try {
      await ref.read(AnilistNotifier.provider.notifier).login();
    } catch (e, stack) {
      if (mounted) {
        AppToast.showError(
          context,
          title: 'Login failed',
          description: e.toString(),
          copyPayload: formatErrorForCopy(e, stack),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final anilist = ref.watch(AnilistNotifier.provider);

    return AppShell(
      currentIndex: _currentPage,
      onDestinationChanged: (i) => setState(() => _currentPage = i),
      viewer: anilist.viewer,
      isAuthLoading: anilist.isAuthLoading,
      onAvatarTap: _handleLogin,
      body: IndexedStack(
        index: _currentPage,
        children: [
          HomePage(onLoginTap: _handleLogin),
          const SearchPage(),
          const DownloadsPage(),
          const SettingsPage(),
        ],
      ),
    );
  }
}
