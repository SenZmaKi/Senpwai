import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:senpwai/shared/log.dart';

PackageInfo? _packageInfo;

Future<void> initializeErrorReports() async {
  try {
    _packageInfo = await PackageInfo.fromPlatform();
  } catch (error, stack) {
    // Diagnostic metadata must never prevent app startup.
    recordErrorReport('Could not read app version: $error\n$stack');
  }
}

String buildErrorReportContext() => [
  'Captured at: ${DateTime.now().toUtc().toIso8601String()}',
  'App version: ${_packageInfo?.version ?? 'unavailable'}',
  'Build number: ${_packageInfo?.buildNumber ?? 'unavailable'}',
  'OS: ${Platform.operatingSystem} ${Platform.operatingSystemVersion}',
  'Platform target: ${defaultTargetPlatform.name}',
  'Build mode: ${kReleaseMode
      ? 'release'
      : kProfileMode
      ? 'profile'
      : 'debug'}',
  'Disk logging: $diskLoggingStatus',
  '',
  'Recent app logs (up to $maxDiagnosticLogRecords complete records, capped at ${maxDiagnosticLogBytes ~/ 1024} KiB):',
  recentDiagnosticLogs.isEmpty ? 'No recent logs.' : recentDiagnosticLogs,
].join('\n');

/// Record the failure before taking the context snapshot. Keep the stored
/// record independent of the report so reports never recursively embed reports.
String formatDiagnosticError(
  Object error, [
  StackTrace? stackTrace,
  String? diagnostics,
]) {
  final details = StringBuffer()
    ..writeln('Error: $error')
    ..writeln('Type: ${error.runtimeType}');
  if (stackTrace != null) {
    details
      ..writeln()
      ..writeln('Stack trace:')
      ..write(stackTrace);
  }
  if (diagnostics != null && diagnostics.isNotEmpty) {
    details
      ..writeln()
      ..writeln()
      ..write(diagnostics);
  }
  recordErrorReport('${DateTime.now().toIso8601String()} ERROR: $details');
  return sanitizeDiagnosticText('${buildErrorReportContext()}\n\n$details');
}
