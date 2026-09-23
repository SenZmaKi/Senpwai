import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:senpwai/shared/net/browser_transport/browser_transport.dart';

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
          ),
      ],
    );
  }
}

class _BrowserSessionView extends StatelessWidget {
  final BrowserHostSession session;
  final bool visible;

  const _BrowserSessionView({
    super.key,
    required this.session,
    required this.visible,
  });

  @override
  Widget build(BuildContext context) {
    final webView = InAppWebView(
      initialUrlRequest: URLRequest(
        url: WebUri(session.bootstrapUri.toString()),
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
      onWebViewCreated: (controller) => unawaited(session.attach(controller)),
      onLoadStop: (_, __) => unawaited(session.pageFinished()),
      onTitleChanged: (_, __) => unawaited(session.pageTitleChanged()),
      shouldOverrideUrlLoading: (_, action) async =>
          session.handleNavigation(action),
      onReceivedError: (_, request, error) {
        session.handleLoadError(request, error);
      },
    );

    return Positioned.fill(
      child: Visibility(
        visible: visible,
        maintainState: true,
        maintainAnimation: true,
        maintainSize: true,
        child: Material(
          color: Theme.of(context).colorScheme.surface,
          child: SafeArea(
            child: Column(
              children: [
                AppBar(
                  automaticallyImplyLeading: false,
                  title: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Browser verification'),
                      Text(
                        session.host,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                  actions: [
                    Semantics(
                      label: 'Cancel browser verification',
                      button: true,
                      child: IconButton(
                        onPressed: () => BrowserTransportService.instance
                            .cancelSessionRequests(session.host),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ),
                  ],
                ),
                const LinearProgressIndicator(),
                Expanded(child: webView),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
