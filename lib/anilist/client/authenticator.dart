import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:senpwai/anilist/constants.dart' as constants;
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import 'package:senpwai/anilist/exceptions.dart';
import 'package:senpwai/shared/log.dart';
import 'package:senpwai/shared/net/net.dart';
import 'package:url_launcher/url_launcher.dart';

final _log = Logger("senpwai.anilist.auth");

class AnilistAuthenticatorClient {
  final _dio = GlobalDio.getInstance();
  String? token;

  Future<bool> isAuthenticated() async =>
      token == null ? false : isValidToken(token: token!);

  Future<bool> isValidToken({required String token}) async {
    try {
      await fetchViewer(accessToken: token);
      return true;
    } on DioException {
      return false;
    }
  }

  Future<Map<String, dynamic>> fetchViewer({String? accessToken}) async {
    const query = r'''
      query {
        Viewer {
          id
          name
        }
      }
    ''';
    final resolvedToken = accessToken ?? token;
    final response = await _dio.post<Map<String, dynamic>>(
      constants.Constants.apiEntryPoint,
      data: {"query": query},
      options: Options(
        headers: resolvedToken == null
            ? null
            : {"Authorization": "Bearer $resolvedToken"},
      ),
    );
    final data = response.data;
    if (data == null) {
      throw const AnilistEmptyResponseException();
    }
    return data;
  }

  Future<void> setToken(String newToken) async {
    final isValid = await isValidToken(token: newToken);
    if (!isValid) {
      throw const AnilistInvalidTokenException();
    }
    token = newToken;
  }

  Uri _buildAuthorizationUrl() {
    final query = {
      "client_id": constants.Constants.clientId,
      "response_type": "token",
    };
    return Uri.parse(
      constants.Constants.oauthAuthorizeUrl,
    ).replace(queryParameters: query);
  }

  Future<void> openAuthenticationPage() async {
    final url = _buildAuthorizationUrl();
    _log.infoWithMetadata(
      "Opening AniList auth URL",
      metadata: {"url": url.toString()},
    );
    if (kIsWeb) {
      final ok = await launchUrl(url, webOnlyWindowName: "_self");
      if (!ok) {
        throw const AnilistAuthUrlOpenException();
      }
      return;
    }
    final ok = await launchUrl(url, mode: LaunchMode.externalApplication);
    if (!ok) {
      throw const AnilistAuthUrlOpenException();
    }
  }

  Future<String> authenticate() async {
    _log.infoWithMetadata("Starting AniList auth flow");

    if (kIsWeb) {
      throw UnsupportedError("Web auth flow is not supported");
    }

    final appLinks = AppLinks();
    final completer = Completer<Uri>();

    final subscription = appLinks.uriLinkStream.listen(
      (uri) {
        _log.infoWithMetadata(
          "Received URI",
          metadata: {"uri": uri.toString()},
        );
        // Ensure we match your redirect: senpwai://auth
        if (uri.scheme == "senpwai" && uri.host == "auth") {
          if (!completer.isCompleted) completer.complete(uri);
        }
      },
      onError: (err) {
        if (!completer.isCompleted) completer.completeError(err);
      },
    );

    try {
      await openAuthenticationPage();

      final uri = await completer.future;

      // Implicit grant returns: senpwai://auth#access_token=...&token_type=Bearer...
      final fragment = uri.fragment;
      final params = Uri.splitQueryString(fragment);

      final newToken = params["access_token"];

      if (newToken == null || newToken.isEmpty) {
        _log.severe("Auth failed: Access token missing from fragment");
        throw const AnilistAuthMissingCodeException();
      }

      // Update the internal state
      token = newToken;
      return newToken;
    } finally {
      await subscription.cancel();
    }
  }
}
