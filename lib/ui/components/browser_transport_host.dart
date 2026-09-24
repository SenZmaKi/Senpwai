import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:senpwai/shared/net/browser_transport/browser_transport.dart';
import 'package:senpwai/ui/components/browser_verification/browser_verification_shell.dart';

class BrowserTransportHost extends StatefulWidget {
  final Widget child;

  const BrowserTransportHost({super.key, required this.child});

  @override
  State<BrowserTransportHost> createState() => _BrowserTransportHostState();
}

class _BrowserTransportHostState extends State<BrowserTransportHost> {
  final _transport = BrowserTransportService.instance;

  @override
  void initState() {
    super.initState();
    _transport.addListener(_onTransportChanged);
  }

  @override
  void dispose() {
    _transport.removeListener(_onTransportChanged);
    super.dispose();
  }

  void _onTransportChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final visibleSession = _transport.visibleSession;
    final verificationCount = _transport.sessions
        .where((session) => session.requiresInteraction)
        .length;
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        for (final session in _transport.sessions)
          _BrowserSessionView(
            // A retired host can be requested again before Flutter renders the
            // removal frame. Key by the session instance so the replacement
            // always gets a fresh platform WebView and onWebViewCreated call.
            key: ObjectKey(session),
            session: session,
            visible: identical(session, visibleSession),
            verificationCount: verificationCount,
          ),
      ],
    );
  }
}

class _BrowserSessionView extends StatefulWidget {
  final BrowserHostSession session;
  final bool visible;
  final int verificationCount;

  const _BrowserSessionView({
    super.key,
    required this.session,
    required this.visible,
    required this.verificationCount,
  });

  @override
  State<_BrowserSessionView> createState() => _BrowserSessionViewState();
}

class _BrowserSessionViewState extends State<_BrowserSessionView> {
  InAppWebViewController? _controller;
  double _progress = 0.0;
  late final OverlayEntry _overlayEntry;

  @override
  void initState() {
    super.initState();
    _overlayEntry = OverlayEntry(builder: (context) => _buildShell(context));
  }

  @override
  void didUpdateWidget(covariant _BrowserSessionView oldWidget) {
    super.didUpdateWidget(oldWidget);
    _overlayEntry.markNeedsBuild();
  }

  Widget _buildShell(BuildContext context) {
    final webView = InAppWebView(
      initialUrlRequest: URLRequest(
        url: WebUri(widget.session.bootstrapUri.toString()),
      ),
      initialSettings: InAppWebViewSettings(
        javaScriptEnabled: true,
        javaScriptCanOpenWindowsAutomatically: true,
        thirdPartyCookiesEnabled: true,
        cacheEnabled: true,
        useShouldOverrideUrlLoading: true,
        useHybridComposition: true,
        darkMode: Theme.of(context).brightness == Brightness.dark,
      ),
      onWebViewCreated: (controller) {
        _controller = controller;
        unawaited(widget.session.attach(controller));
      },
      onProgressChanged: (_, progress) {
        if (mounted) {
          setState(() => _progress = progress / 100.0);
          _overlayEntry.markNeedsBuild();
        }
      },
      onLoadStop: (_, __) => unawaited(widget.session.pageFinished()),
      onTitleChanged: (_, __) => unawaited(widget.session.pageTitleChanged()),
      shouldOverrideUrlLoading: (_, action) async =>
          widget.session.handleNavigation(action),
      onReceivedError: (_, request, error) {
        widget.session.handleLoadError(request, error);
      },
    );

    return BrowserVerificationShell(
      host: widget.session.host,
      verificationCount: widget.verificationCount,
      progress: _progress,
      onReload: () => _controller?.reload(),
      onCancel: () => unawaited(
        BrowserTransportService.instance.cancelSessionRequests(
          widget.session.host,
        ),
      ),
      child: webView,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Visibility(
        visible: widget.visible,
        maintainState: true,
        maintainAnimation: true,
        maintainSize: true,
        child: Overlay(initialEntries: [_overlayEntry]),
      ),
    );
  }
}
