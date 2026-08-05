import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:senpwai/anilist/anilist.dart';
import 'package:senpwai/downloads/manager.dart';
import 'package:senpwai/notifications/app_notification_service.dart';
import 'package:senpwai/notifications/download_notification_bridge.dart';
import 'package:senpwai/settings/settings.dart';
import 'package:senpwai/tracking/models.dart';
import 'package:senpwai/tracking/notifier.dart';
import 'package:senpwai/ui/shared/anilist.dart';
import 'package:senpwai/ui/shared/app_error_diagnostics.dart';
import 'package:senpwai/ui/components/toast.dart';
import 'package:senpwai/ui/pages/downloads_page.dart';
import 'package:senpwai/ui/pages/home_page.dart';
import 'package:senpwai/ui/pages/search_page/search_page.dart';
import 'package:senpwai/ui/pages/settings_page/settings_page.dart';
import 'package:senpwai/ui/components/app_shell.dart';
import 'package:toastification/toastification.dart';
import 'package:senpwai/ui/shared/window_manager.dart';
import 'package:senpwai/ui/shared/desktop_tray_controller.dart';

enum AppPage { home, search, downloads, settings }

class AppPageNotifier extends Notifier<AppPage> {
  static final provider = NotifierProvider<AppPageNotifier, AppPage>(
    AppPageNotifier.new,
  );

  @override
  AppPage build() =>
      PlatformDispatcher.instance.defaultRouteName == downloadsNotificationRoute
      ? AppPage.downloads
      : AppPage.home;

  void setPage(AppPage page) {
    state = page;
  }

  void setIndex(int index) {
    state = AppPage.values[index];
  }

  void showDownloads() {
    state = AppPage.downloads;
  }
}

class App extends ConsumerWidget {
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  const App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeConfig = ref
        .watch(AppSettingsNotifier.provider)
        .appearance
        .toThemeConfig();
    return ToastificationWrapper(
      child: DownloadNotificationBridge(
        onOpenDownloads: () =>
            ref.read(AppPageNotifier.provider.notifier).showDownloads(),
        child: MaterialApp(
          navigatorKey: navigatorKey,
          title: 'Senpwai',
          initialRoute: '/',
          theme: themeConfig.buildLightTheme(),
          darkTheme: themeConfig.buildDarkTheme(),
          themeMode: themeConfig.themeMode,
          home: const _AppRoot(),
        ),
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
  static const _seedMockDownloads = bool.fromEnvironment(
    'SENPWAI_MOCK_DOWNLOADS',
  );

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_handleHardwareKey);
    final settings = ref.read(AppSettingsNotifier.provider);
    ref
        .read(AnilistNotifier.provider.notifier)
        .updateContentSettings(
          AnilistContentSettings(
            showAdultContent: settings.content.showAdultContent,
          ),
        );
    unawaited(ref.read(AnilistNotifier.provider.notifier).initialize());
    unawaited(
      DesktopTrayController.instance.initialize(
        onCheckTrackedAnime: () =>
            ref.read(TrackingNotifier.provider.notifier).checkNow(),
        closeToTray: settings.window.closeToTray,
      ),
    );
    if (kDebugMode) {
      debugPrint('SENPWAI_MOCK_DOWNLOADS=$_seedMockDownloads');
    }
    if (kDebugMode && _seedMockDownloads) {
      Future.microtask(() {
        ref.read(DownloadManagerNotifier.provider.notifier).seedMockDownloads();
        ref.read(AppPageNotifier.provider.notifier).showDownloads();
      });
    }
    Future.microtask(() {
      unawaited(
        AppNotificationService.instance.syncSettings(
          ref.read(AppSettingsNotifier.provider.notifier),
        ),
      );
    });
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleHardwareKey);
    super.dispose();
  }

  bool _handleHardwareKey(KeyEvent event) {
    if (event is! KeyDownEvent || event.logicalKey != LogicalKeyboardKey.f11) {
      return false;
    }
    unawaited(WindowManager.getInstance().toggleFullScreen());
    return true;
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
    ref.listen(
      AppSettingsNotifier.provider.select(
        (settings) => settings.window.alwaysOnTop,
      ),
      (_, alwaysOnTop) =>
          unawaited(WindowManager.getInstance().applyAlwaysOnTop(alwaysOnTop)),
    );
    ref.listen(
      AppSettingsNotifier.provider.select(
        (settings) => settings.window.closeToTray,
      ),
      (_, closeToTray) =>
          unawaited(DesktopTrayController.instance.setCloseToTray(closeToTray)),
    );
    ref.listen(AppSettingsNotifier.provider, (_, settings) {
      ref
          .read(AnilistNotifier.provider.notifier)
          .updateContentSettings(
            AnilistContentSettings(
              showAdultContent: settings.content.showAdultContent,
            ),
          );
    });
    ref.listen(DownloadManagerNotifier.provider, (_, downloadState) {
      unawaited(
        ref
            .read(TrackingNotifier.provider.notifier)
            .handleDownloadState(downloadState),
      );
    });
    ref.listen(
      TrackingNotifier.provider.select((tracking) => tracking.latestEvent),
      (_, event) {
        if (event != null) _handleTrackingEvent(event);
      },
    );
    final anilist = ref.watch(AnilistNotifier.provider);
    final currentPage = ref.watch(AppPageNotifier.provider);
    ref.watch(TrackingScheduler.provider);
    AppErrorDiagnostics.currentPage = currentPage.name;

    return AppShell(
      currentIndex: currentPage.index,
      onDestinationChanged: (i) =>
          ref.read(AppPageNotifier.provider.notifier).setIndex(i),
      viewer: anilist.viewer,
      isAuthLoading: anilist.isAuthLoading,
      onAvatarTap: _handleLogin,
      body: IndexedStack(
        index: currentPage.index,
        children: [
          HomePage(onLoginTap: _handleLogin),
          const SearchPage(),
          const DownloadsPage(),
          const SettingsPage(),
        ],
      ),
    );
  }

  void _handleTrackingEvent(TrackingEvent event) {
    unawaited(
      AppNotificationService.instance.showUserEvent(
        id: event.id.hashCode & 0x7fffffff,
        title: event.title,
        body: event.description,
        level: switch (event.level) {
          TrackingEventLevel.info => UserEventLevel.info,
          TrackingEventLevel.warning => UserEventLevel.warning,
          TrackingEventLevel.error => UserEventLevel.error,
        },
      ),
    );
  }
}
