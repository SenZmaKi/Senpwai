import 'package:flutter/material.dart';
import 'package:senpwai/anilist/client/authenticated.dart';
import 'package:senpwai/anilist/client/unauthenticated.dart';
import 'package:senpwai/shared/log.dart';
import 'package:senpwai/ui/core/theme.dart';
import 'package:senpwai/ui/pages/downloads_page.dart';
import 'package:senpwai/ui/pages/home_page.dart';
import 'package:senpwai/ui/pages/search_page.dart';
import 'package:senpwai/ui/pages/settings_page.dart';
import 'package:senpwai/ui/shell/app_shell.dart';

void main() {
  setupLogger();
  runApp(const App());
}

class App extends StatefulWidget {
  const App({super.key});

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  final _themeConfig = ThemeConfig();

  @override
  void dispose() {
    _themeConfig.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ThemeConfigProvider(
      config: _themeConfig,
      child: ListenableBuilder(
        listenable: _themeConfig,
        builder: (context, _) {
          return MaterialApp(
            title: 'Senpwai',
            theme: _themeConfig.buildLightTheme(),
            darkTheme: _themeConfig.buildDarkTheme(),
            themeMode: _themeConfig.themeMode,
            home: const _AppRoot(),
          );
        },
      ),
    );
  }
}

class _AppRoot extends StatefulWidget {
  const _AppRoot();

  @override
  State<_AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<_AppRoot> {
  final _authClient = AnilistAuthenticatedClient();
  final _unauthClient = AnilistUnauthenticatedClient();

  int _currentPage = 0;
  bool _isAuthenticated = false;
  bool _isAuthLoading = false;
  String? _avatarUrl;
  String? _userName;

  Future<void> _handleLogin() async {
    if (_isAuthenticated) return;
    setState(() => _isAuthLoading = true);
    try {
      await _authClient.auth.authenticate();
      await _fetchUserInfo();
      setState(() => _isAuthenticated = true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Login failed: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isAuthLoading = false);
    }
  }

  Future<void> _fetchUserInfo() async {
    try {
      final viewer = await _authClient.auth.fetchViewer();
      setState(() {
        _userName = viewer.name;
        _avatarUrl = viewer.avatarUrl;
      });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      currentIndex: _currentPage,
      onDestinationChanged: (i) => setState(() => _currentPage = i),
      avatarUrl: _avatarUrl,
      userName: _userName,
      isAuthLoading: _isAuthLoading,
      onAvatarTap: _handleLogin,
      body: IndexedStack(
        index: _currentPage,
        children: [
          HomePage(
            authClient: _authClient,
            unauthClient: _unauthClient,
            isAuthenticated: _isAuthenticated,
            avatarUrl: _avatarUrl,
            userName: _userName,
            isAuthLoading: _isAuthLoading,
            onLoginTap: _handleLogin,
          ),
          SearchPage(
            authClient: _authClient,
            unauthClient: _unauthClient,
            isAuthenticated: _isAuthenticated,
          ),
          const DownloadsPage(),
          const SettingsPage(),
        ],
      ),
    );
  }
}
