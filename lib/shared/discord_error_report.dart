import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:senpwai/shared/log.dart';
import 'package:senpwai/shared/persistence/app_persistence.dart';

/// The dedicated webhook is deliberately shipped in the app. It is extractable;
/// never substitute a Discord bot token here.
class DiscordErrorReport {
  static const webhookUrl = String.fromEnvironment(
    'DISCORD_REPORT_WEBHOOK_URL',
  );
  static const maxDiagnosticBytes = 256 * 1024;
  static DateTime? _retryAfter;

  static File get _usernameFile => File(
    '${AppPersistence.paths.settingsDirectory.path}/discord_report_username.txt',
  );

  static Future<String> loadUsername() async => await _usernameFile.exists()
      ? (await _usernameFile.readAsString()).trim()
      : '';

  static Future<void> saveUsername(String username) async {
    final file = _usernameFile;
    await file.parent.create(recursive: true);
    final temporary = File('${file.path}.tmp');
    await temporary.writeAsString(username.trim(), flush: true);
    await temporary.rename(file.path);
  }

  static Future<void> send({
    required String title,
    required String username,
    required String message,
    required String diagnostics,
  }) async {
    final uri = Uri.tryParse(webhookUrl);
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host != 'discord.com' ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        !RegExp(
          r'^/api(?:/v10)?/webhooks/\d{17,20}/[A-Za-z0-9_-]+$',
        ).hasMatch(uri.path)) {
      throw const ReportFailure(
        'Reporting is not configured in this build. '
        'You can still copy the error details.',
      );
    }
    if (_retryAfter case final retryAfter?
        when DateTime.now().isBefore(retryAfter)) {
      throw ReportFailure(_rateLimitMessage(retryAfter));
    }
    if (username.trim().length > 80 || message.trim().length > 2000) {
      throw const ReportFailure(
        'Please shorten the username or message before sending.',
      );
    }
    final sanitized = sanitizeDiagnosticText(diagnostics);
    if (utf8.encode(sanitized).length > maxDiagnosticBytes) {
      throw const ReportFailure(
        'The diagnostics are too large to send. Please copy the error details instead.',
      );
    }
    final random = Random.secure();
    final id = List.generate(
      12,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
    final timestamp = DateTime.now().toUtc().toIso8601String();
    final reporter = username.trim().isEmpty
        ? 'anonymous'
        : sanitizeDiagnosticText(username.trim());
    final context = sanitizeDiagnosticText(message.trim());
    final safeTitle = sanitizeDiagnosticText(title.trim());
    final embed = {
      'title': safeTitle.isEmpty ? 'App error' : _truncate(safeTitle, 256),
      'color': 0xe5534b,
      'timestamp': timestamp,
      'fields': [
        {'name': 'Reporter (self-reported)', 'value': reporter},
        {'name': 'Report ID', 'value': id},
      ],
      if (context.isNotEmpty) 'description': context,
      'footer': {'text': 'Full diagnostics attached'},
    };
    final filename = 'senpwai-report-$id.txt';
    final attachment =
        'Report ID: $id\nSent at: $timestamp\n'
        'Reporter (self-reported): $reporter\nError: $safeTitle\n\n'
        'What happened:\n${context.isEmpty ? 'No additional context provided.' : context}\n\n'
        '$sanitized';
    final form = FormData.fromMap({
      'payload_json': jsonEncode({
        'embeds': [embed],
        'allowed_mentions': {'parse': <String>[]},
        'attachments': [
          {
            'id': 0,
            'filename': filename,
            'description': 'Error diagnostics and user context',
          },
        ],
      }),
      'files[0]': MultipartFile.fromBytes(
        utf8.encode(attachment),
        filename: filename,
      ),
    });
    // An independent client avoids the app's request logger and proxy credentials.
    final client = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 10),
        sendTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 25),
        followRedirects: false,
        validateStatus: (status) => status == 200,
      ),
    );
    try {
      // wait=true asks Discord to confirm storage and return the created message.
      final response = await client.post<Map<String, dynamic>>(
        uri.replace(queryParameters: {'wait': 'true'}).toString(),
        data: form,
      );
      if (response.data?['id'] is! String) {
        throw const ReportFailure(
          'Delivery could not be confirmed. The report may already have arrived.',
        );
      }
    } on DioException catch (error) {
      if (error.response?.statusCode == 429) {
        final body = error.response?.data;
        final seconds = body is Map && body['retry_after'] is num
            ? (body['retry_after'] as num).toDouble()
            : 60.0;
        final delay = seconds.isFinite && seconds > 0 ? seconds : 60.0;
        _retryAfter = DateTime.now().add(
          Duration(milliseconds: (delay * 1000).ceil()),
        );
        throw ReportFailure(_rateLimitMessage(_retryAfter!));
      }
      throw ReportFailure(switch (error.response?.statusCode) {
        400 =>
          'Discord rejected the report. Please copy the error details instead.',
        401 || 403 || 404 =>
          'The reporting webhook is unavailable. Please copy the error details instead.',
        413 =>
          'The diagnostics are too large to send. Please copy them instead.',
        _ =>
          'Delivery could not be confirmed. Check your connection before '
              'retrying; the report may already have arrived.',
      });
    } finally {
      client.close(force: true);
    }
  }

  static String _rateLimitMessage(DateTime retryAfter) {
    final seconds = max(
      1,
      (retryAfter.difference(DateTime.now()).inMilliseconds / 1000).ceil(),
    );
    return 'Too many reports. Please wait $seconds seconds before trying again.';
  }

  // Count UTF-16 units conservatively without splitting a surrogate pair.
  static String _truncate(String value, int limit) {
    if (value.length <= limit) return value;
    final last = value.codeUnitAt(limit - 1);
    return value.substring(
      0,
      last >= 0xd800 && last <= 0xdbff ? limit - 1 : limit,
    );
  }
}

class ReportFailure implements Exception {
  final String message;
  const ReportFailure(this.message);
}
