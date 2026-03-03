import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:senpwai/shared/log.dart';
import 'package:senpwai/ui/components/toast.dart';
import 'package:senpwai/ui/components/app.dart';

void main() {
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

  runApp(const ProviderScope(child: App()));
}
