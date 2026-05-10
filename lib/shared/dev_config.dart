import 'package:flutter/foundation.dart';
import 'package:senpwai/shared/net/net.dart';
import 'package:dotenv/dotenv.dart' as dotenv;
import 'package:logging/logging.dart';
import 'package:senpwai/shared/log.dart';
import 'dart:io';

final _log = Logger("senpwai.shared.dev_config");

/// In debug mode, loads `.env` and applies AnimePahe CF bypass credentials
/// (user-agent and cookies) to [GlobalDio]. No-op in release builds.
void applyDevConfig() {
  if (!kDebugMode) return;

  final env = dotenv.DotEnv(includePlatformEnvironment: true, quiet: true)
    ..load();
  final userAgent = env["ANIMEPAHE_USER_AGENT"];
  final cookiesRaw = env["ANIMEPAHE_COOKIES"];
  final dio = GlobalDio.getInstance();
  final cookieJar = GlobalDio.cookieJar;

  if (userAgent != null && userAgent.isNotEmpty) {
    dio.options.headers["User-Agent"] = userAgent;
  }

  if (cookiesRaw != null && cookiesRaw.isNotEmpty) {
    for (final domainEntry in cookiesRaw.split("|")) {
      final colonIdx = domainEntry.indexOf(":");
      if (colonIdx == -1) continue;
      final domain = domainEntry.substring(0, colonIdx);
      final pairs = domainEntry.substring(colonIdx + 1);
      final domainCookies = <Cookie>[];
      for (final pair in pairs.split(";")) {
        final eqIdx = pair.indexOf("=");
        if (eqIdx == -1) continue;
        final name = pair.substring(0, eqIdx).trim();
        final value = pair.substring(eqIdx + 1).trim();
        domainCookies.add(Cookie(name, value));
      }
      final uri = Uri.parse(
        domain.startsWith("http") ? domain : "https://$domain",
      );
      cookieJar.saveFromResponse(uri, domainCookies);
    }
  }

  _log.infoWithMetadata(
    "Applied dev .env config to GlobalDio",
    metadata: {
      "hasUserAgent": userAgent != null && userAgent.isNotEmpty,
      "hasCookies": cookiesRaw != null && cookiesRaw.isNotEmpty,
    },
  );
}
