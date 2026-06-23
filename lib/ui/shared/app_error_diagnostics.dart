import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

class AppErrorDiagnostics {
  static String? currentPage;
}

String buildAppErrorDiagnostics(BuildContext? context) {
  final mediaQuery = context == null ? null : MediaQuery.maybeOf(context);
  final route = context == null ? null : ModalRoute.of(context);
  final dispatcher = WidgetsBinding.instance.platformDispatcher;
  final view = context == null
      ? (dispatcher.views.isEmpty ? null : dispatcher.views.first)
      : View.maybeOf(context);
  final logicalViewSize = view == null
      ? null
      : view.physicalSize / view.devicePixelRatio;

  final buildMode = kReleaseMode
      ? 'release'
      : kProfileMode
      ? 'profile'
      : 'debug';

  final buffer = StringBuffer()
    ..writeln('App diagnostics:')
    ..writeln('Current page: ${AppErrorDiagnostics.currentPage ?? 'unknown'}')
    ..writeln('Route: ${route?.settings.name ?? route.runtimeType}')
    ..writeln('Platform target: $defaultTargetPlatform')
    ..writeln('Build mode: $buildMode')
    ..writeln('Locale: ${dispatcher.locale}')
    ..writeln('Platform brightness: ${dispatcher.platformBrightness}');

  if (mediaQuery != null) {
    buffer
      ..writeln('MediaQuery size: ${mediaQuery.size}')
      ..writeln('Device pixel ratio: ${mediaQuery.devicePixelRatio}')
      ..writeln('Orientation: ${mediaQuery.orientation}')
      ..writeln('Text scaler: ${mediaQuery.textScaler}')
      ..writeln('Padding: ${mediaQuery.padding}')
      ..writeln('View padding: ${mediaQuery.viewPadding}')
      ..writeln('View insets: ${mediaQuery.viewInsets}');
  } else if (logicalViewSize != null && view != null) {
    buffer
      ..writeln('View logical size: $logicalViewSize')
      ..writeln('Device pixel ratio: ${view.devicePixelRatio}');
  }

  return buffer.toString();
}
