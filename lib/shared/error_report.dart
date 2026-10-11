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
  '',
  'Recent app logs (up to $maxDiagnosticLogRecords complete records, capped at ${maxDiagnosticLogBytes ~/ 1024} KiB):',
  recentDiagnosticLogs.isEmpty ? 'No recent logs.' : recentDiagnosticLogs,
].join('\n');
