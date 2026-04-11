import 'dart:io';

import 'package:logging/logging.dart';
import 'package:dotenv/dotenv.dart' as dotenv;
import 'package:senpwai/shared/log.dart';
import 'package:senpwai/shared/net/net.dart';

final _log = Logger("senpwai.test.support.env");

/// Loads `.env` and applies AnimePahe CF bypass credentials (user agent and
/// cookies) to [GlobalDio].
///
/// Cookie format: `"domain1:name1=value1;name2=value2|domain2:name3=value3"`
void applyAnimepaheEnvToGlobalDio() {
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
    "Applied .env config to GlobalDio",
    metadata: {
      "hasUserAgent": userAgent != null && userAgent.isNotEmpty,
      "hasCookies": cookiesRaw != null && cookiesRaw.isNotEmpty,
    },
  );
}
