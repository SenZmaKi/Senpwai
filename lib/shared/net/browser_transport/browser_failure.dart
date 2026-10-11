import 'package:senpwai/shared/error_report.dart';
import 'package:senpwai/shared/log.dart';

/// A snapshot of the failure that triggered the source-disable prompt.
class BrowserFailure {
  final String host;
  final String error;
  final StackTrace? stackTrace;
  final List<String> diagnostics;
  final String reportContext;

  BrowserFailure({
    required this.host,
    required this.error,
    required this.stackTrace,
    required List<String> diagnostics,
  }) : diagnostics = List.unmodifiable(diagnostics),
       reportContext = buildErrorReportContext();

  String get copyDetails => sanitizeDiagnosticText(
    [
      'Senpwai embedded browser failure',
      reportContext,
      'Host: $host',
      'Error: $error',
      '',
      'Stack trace:',
      stackTrace?.toString() ??
          'Unavailable: this failure did not provide a Dart stack trace.',
      '',
      'Browser diagnostics:',
      ...diagnostics,
    ].join('\n'),
  );
}
