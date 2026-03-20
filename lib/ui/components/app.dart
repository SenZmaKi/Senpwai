import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
