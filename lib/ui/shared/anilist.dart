import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:senpwai/anilist/anilist.dart';

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
  }) {
    return AnilistStateData(
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      isAuthLoading: isAuthLoading ?? this.isAuthLoading,
      viewer: viewer ?? this.viewer,
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

  Future<void> initialize() async {
    if (authClient.auth.token == null) return;
    state = state.copyWith(isAuthenticated: true);
    await refreshViewer();
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
      _focusWindow();
    }
  }

  void _focusWindow() {
    // TODO: Implement
  }

  Future<void> refreshViewer() async {
    final viewer = await authClient.auth.fetchViewer();
    authClient.viewerId = viewer.id;
    state = state.copyWith(viewer: viewer);
  }
}
