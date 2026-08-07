import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:senpwai/anilist/anilist.dart';
import 'package:senpwai/ui/shared/window_manager.dart';
import 'package:url_launcher/url_launcher.dart';

Future<bool> openAnilistProfile(AnilistViewer viewer) {
  final profileUrl = Uri.https('anilist.co', '/user/${viewer.id}');
  return launchUrl(
    profileUrl,
    mode: kIsWeb ? LaunchMode.platformDefault : LaunchMode.externalApplication,
  );
}

class AnilistStateData {
  final bool isAuthenticated;
  final bool isAuthLoading;
  final AnilistViewer? viewer;

  const AnilistStateData({
    this.isAuthenticated = false,
    this.isAuthLoading = false,
    this.viewer,
  });

  AnilistStateData copyWith({
    bool? isAuthenticated,
    bool? isAuthLoading,
    AnilistViewer? viewer,
    bool clearViewer = false,
  }) {
    return AnilistStateData(
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      isAuthLoading: isAuthLoading ?? this.isAuthLoading,
      viewer: clearViewer ? null : viewer ?? this.viewer,
    );
  }
}

class AnilistNotifier extends Notifier<AnilistStateData> {
  static final provider = NotifierProvider<AnilistNotifier, AnilistStateData>(
    AnilistNotifier.new,
  );

  final authClient = AnilistAuthenticatedClient();
  final unauthClient = AnilistUnauthenticatedClient();

  @override
  AnilistStateData build() => const AnilistStateData();

  void updateContentSettings(AnilistContentSettings settings) {
    authClient.contentSettings = settings;
    unauthClient.contentSettings = settings;
  }

  Future<void> initialize() async {
    await authClient.auth.restoreToken();
    if (authClient.auth.token == null) return;
    state = state.copyWith(isAuthenticated: true);
    try {
      await refreshViewer();
    } on DioException catch (error) {
      if (!_isInvalidAuthDioException(error)) rethrow;
      await _clearRestoredAuth();
    } on AnilistGraphqlException catch (error) {
      if (!_isInvalidAuthGraphqlException(error)) rethrow;
      await _clearRestoredAuth();
    } on AnilistInvalidTokenException {
      await _clearRestoredAuth();
    }
  }

  Future<void> login() async {
    if (state.isAuthenticated || state.isAuthLoading) return;

    state = state.copyWith(isAuthLoading: true);
    try {
      await authClient.auth.authenticate();
      state = state.copyWith(isAuthenticated: true);
      await refreshViewer();
    } finally {
      state = state.copyWith(isAuthLoading: false);
      WindowManager.getInstance().focus();
    }
  }

  Future<void> refreshViewer() async {
    final viewer = await authClient.auth.fetchViewer();
    authClient.viewerId = viewer.id;
    state = state.copyWith(viewer: viewer);
  }

  Future<void> logout() async {
    if (state.isAuthLoading) return;

    state = state.copyWith(isAuthLoading: true);
    try {
      await authClient.auth.clearToken();
      authClient.viewerId = null;
      state = const AnilistStateData();
    } on Object {
      state = state.copyWith(isAuthLoading: false);
      rethrow;
    }
  }

  Future<void> _clearRestoredAuth() async {
    await authClient.auth.clearToken();
    authClient.viewerId = null;
    state = state.copyWith(isAuthenticated: false, clearViewer: true);
  }

  bool _isInvalidAuthDioException(DioException error) {
    final statusCode = error.response?.statusCode;
    return statusCode == 401 || statusCode == 403;
  }

  bool _isInvalidAuthGraphqlException(AnilistGraphqlException error) {
    return error.errors.any((graphqlError) {
      final status = graphqlError.status;
      final message = graphqlError.message.toLowerCase();
      final code = graphqlError.extensions['code']?.toString().toLowerCase();
      return status == '401' ||
          status == '403' ||
          code == 'unauthenticated' ||
          message.contains('invalid token') ||
          message.contains('unauthenticated') ||
          message.contains('unauthorized');
    });
  }
}
