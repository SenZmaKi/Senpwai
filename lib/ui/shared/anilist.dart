import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show AppLifecycleState;
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:senpwai/anilist/anilist.dart';
import 'package:senpwai/shared/app_lifecycle.dart';
import 'package:senpwai/ui/shared/window_manager.dart';
import 'package:url_launcher/url_launcher.dart';

final _log = Logger('senpwai.ui.shared.anilist');

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
  final bool isListSnapshotReady;
  final String? listSnapshotError;
  final int listSnapshotRevision;

  const AnilistStateData({
    this.isAuthenticated = false,
    this.isAuthLoading = false,
    this.viewer,
    this.isListSnapshotReady = false,
    this.listSnapshotError,
    this.listSnapshotRevision = 0,
  });

  AnilistStateData copyWith({
    bool? isAuthenticated,
    bool? isAuthLoading,
    AnilistViewer? viewer,
    bool clearViewer = false,
    bool? isListSnapshotReady,
    String? listSnapshotError,
    bool clearListSnapshotError = false,
    int? listSnapshotRevision,
  }) {
    return AnilistStateData(
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      isAuthLoading: isAuthLoading ?? this.isAuthLoading,
      viewer: clearViewer ? null : viewer ?? this.viewer,
      isListSnapshotReady: isListSnapshotReady ?? this.isListSnapshotReady,
      listSnapshotError: clearListSnapshotError
          ? null
          : listSnapshotError ?? this.listSnapshotError,
      listSnapshotRevision: listSnapshotRevision ?? this.listSnapshotRevision,
    );
  }
}

class AnilistNotifier extends Notifier<AnilistStateData> {
  static final provider = NotifierProvider<AnilistNotifier, AnilistStateData>(
    AnilistNotifier.new,
  );

  final authClient = AnilistAuthenticatedClient();
  final unauthClient = AnilistUnauthenticatedClient();
  bool _initializationStarted = false;
  Timer? _listSnapshotTimer;
  Future<void>? _listSnapshotRefresh;

  @override
  AnilistStateData build() {
    ref.listen(AppLifecycleNotifier.provider, (_, lifecycle) {
      if (!state.isAuthenticated) return;
      if (lifecycle == AppLifecycleState.resumed) {
        unawaited(_refreshListSnapshot());
      } else {
        _listSnapshotTimer?.cancel();
      }
    });
    ref.onDispose(() => _listSnapshotTimer?.cancel());
    return const AnilistStateData(isAuthLoading: true);
  }

  void updateContentSettings(AnilistContentSettings settings) {
    authClient.contentSettings = settings;
    unauthClient.contentSettings = settings;
  }

  Future<void> initialize() async {
    if (_initializationStarted) return;
    _initializationStarted = true;
    try {
      await authClient.auth.restoreToken();
      if (authClient.auth.token == null) return;
      state = state.copyWith(isAuthenticated: true);
      try {
        await refreshViewer();
        await authClient.ensureUserListSnapshot(force: true);
        state = state.copyWith(
          isListSnapshotReady: true,
          clearListSnapshotError: true,
          listSnapshotRevision: state.listSnapshotRevision + 1,
        );
        _startListSnapshotPolling();
      } on Object catch (error, stack) {
        if (_isInvalidAuthError(error)) {
          await _clearRestoredAuth();
        } else {
          _recordListSnapshotFailure(
            'AniList startup list refresh failed',
            error,
            stack,
          );
          _startListSnapshotPolling();
        }
      }
    } on Object catch (error, stack) {
      _log.warning('AniList initialization failed', error, stack);
    } finally {
      state = state.copyWith(isAuthLoading: false);
    }
  }

  Future<void> login() async {
    if (state.isAuthenticated || state.isAuthLoading) return;

    state = state.copyWith(isAuthLoading: true);
    try {
      await authClient.auth.authenticate();
      state = state.copyWith(isAuthenticated: true);
      try {
        await refreshViewer();
        await authClient.ensureUserListSnapshot(force: true);
        state = state.copyWith(
          isListSnapshotReady: true,
          clearListSnapshotError: true,
          listSnapshotRevision: state.listSnapshotRevision + 1,
        );
      } on Object catch (error, stack) {
        if (_isInvalidAuthError(error)) {
          await _clearRestoredAuth();
        } else {
          _recordListSnapshotFailure(
            'AniList post-login list refresh failed',
            error,
            stack,
          );
        }
      }
      if (state.isAuthenticated) _startListSnapshotPolling();
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
      authClient.clearUserListSnapshot();
      _listSnapshotTimer?.cancel();
      _listSnapshotRefresh = null;
      state = const AnilistStateData();
    } on Object {
      state = state.copyWith(isAuthLoading: false);
      rethrow;
    }
  }

  Future<void> _clearRestoredAuth() async {
    await authClient.auth.clearToken();
    authClient.viewerId = null;
    authClient.clearUserListSnapshot();
    _listSnapshotTimer?.cancel();
    _listSnapshotRefresh = null;
    state = state.copyWith(
      isAuthenticated: false,
      isListSnapshotReady: false,
      clearViewer: true,
      clearListSnapshotError: true,
    );
  }

  void _startListSnapshotPolling() {
    _listSnapshotTimer?.cancel();
    if (ref.read(AppLifecycleNotifier.provider) != AppLifecycleState.resumed) {
      return;
    }
    _listSnapshotTimer = Timer(const Duration(minutes: 3), () {
      unawaited(_refreshListSnapshot(force: true));
    });
  }

  Future<void> _refreshListSnapshot({bool force = false}) {
    final active = _listSnapshotRefresh;
    if (active != null) return active;

    late final Future<void> refresh;
    refresh = _performListSnapshotRefresh(force: force).whenComplete(() {
      if (identical(_listSnapshotRefresh, refresh)) {
        _listSnapshotRefresh = null;
      }
    });
    _listSnapshotRefresh = refresh;
    return refresh;
  }

  Future<void> _performListSnapshotRefresh({required bool force}) async {
    try {
      if (state.viewer == null) await refreshViewer();
      final changed = await authClient.ensureUserListSnapshot(force: force);
      if (!state.isAuthenticated) return;
      state = state.copyWith(
        isListSnapshotReady: true,
        clearListSnapshotError: true,
        listSnapshotRevision: changed
            ? state.listSnapshotRevision + 1
            : state.listSnapshotRevision,
      );
    } on Object catch (error, stack) {
      if (_isInvalidAuthError(error)) {
        await _clearRestoredAuth();
      } else {
        _recordListSnapshotFailure(
          'AniList list snapshot refresh failed',
          error,
          stack,
        );
      }
    } finally {
      if (state.isAuthenticated) _startListSnapshotPolling();
    }
  }

  void _recordListSnapshotFailure(
    String message,
    Object error,
    StackTrace stack,
  ) {
    _log.warning(message, error, stack);
    state = state.copyWith(
      isListSnapshotReady: authClient.hasUserListSnapshot,
      listSnapshotError: error.toString(),
    );
  }

  bool _isInvalidAuthError(Object error) =>
      error is AnilistInvalidTokenException ||
      (error is DioException && _isInvalidAuthDioException(error)) ||
      (error is AnilistGraphqlException &&
          _isInvalidAuthGraphqlException(error));

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
