import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:senpwai/notifications/app_notification_service.dart';
import 'package:senpwai/shared/log.dart';
import 'package:senpwai/shared/net/net.dart';
import 'package:senpwai/shared/persistence/app_persistence.dart';
import 'package:senpwai/ui/components/app.dart';
import 'package:senpwai/ui/components/toast.dart';
import 'package:senpwai/ui/shared/app_error_diagnostics.dart';
import 'package:senpwai/ui/shared/launch_at_startup_manager.dart';
import 'package:senpwai/ui/shared/window_manager.dart';

Future<void> initApp() async {
  WidgetsFlutterBinding.ensureInitialized();
  setupLogger();
  _configureErrorHandling();
  await AppPersistence.initialize();
  await configureFileLogging(AppPersistence.paths.logsDirectory);
  await AppNotificationService.instance.initialize();
  await AppNotificationService.instance.configurePresentation(
    navigatorKey: App.navigatorKey,
  );
  _initNetworkErrorHandling();
  await LaunchAtStartupManager.getInstance().init(
    AppPersistence.settings.window.launchAtStartup,
  );
  await WindowManager.getInstance().init(
    AppPersistence.settings.window,
    AppPersistence.windowStateRepository,
  );
}

void _configureErrorHandling() {
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    final context = App.navigatorKey.currentContext;
    final diagnostics = buildAppErrorDiagnostics(context);
    if (context != null) {
      AppToast.showErrorDeferred(
        context,
        title: 'Unexpected error',
        description: details.exceptionAsString(),
        copyPayload: formatErrorForCopy(
          details.exception,
          details.stack,
          diagnostics,
        ),
      );
    }
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    final context = App.navigatorKey.currentContext;
    final diagnostics = buildAppErrorDiagnostics(context);
    if (context != null) {
      AppToast.showErrorDeferred(
        context,
        title: 'Unhandled error',
        description: error.toString(),
        copyPayload: formatErrorForCopy(error, stack, diagnostics),
      );
    }
    return true;
  };
}

void _initNetworkErrorHandling() {
  GlobalDio.getInstance();
  GlobalDio.connectivityInterceptor?.setOfflineNetworkErrorCallback((error) {
    final context = App.navigatorKey.currentContext;
    if (context == null) return;
    AppToast.showError(
      context,
      title: 'No internet access',
      description: 'Network requests will retry when you reconnect.',
    );
  });
}
