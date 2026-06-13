import 'dart:async';

import 'package:cf_bypass/cf_bypass.dart' hide LoggerExtensions;
import 'package:flutter/material.dart';
import 'package:senpwai/shared/net/connectivity.dart';
import 'package:senpwai/shared/log.dart';
import 'package:senpwai/ui/components/toast.dart';

final _log = Logger("senpwai.ui.pages.anime_page.cf_bypass");

/// Full-screen page that renders a [CfWebView] to solve a CloudFlare challenge.
///
/// Returns a [CfBypassResult] via `Navigator.pop` on success or failure.
class CfBypassPage extends StatefulWidget {
  final String url;

  const CfBypassPage({super.key, required this.url});

  @override
  State<CfBypassPage> createState() => _CfBypassPageState();
}

class _CfBypassPageState extends State<CfBypassPage> {
  static const _connectivityRetryInterval = Duration(seconds: 3);

  final _controller = CfBypassController();
  _SolveStatus _status = _SolveStatus.solving;
  String? _statusMessage;
  final _events = <String>[];
  Timer? _connectivityRetryTimer;
  bool _internetCheckInProgress = false;
  bool _offlineToastShown = false;

  @override
  void dispose() {
    _connectivityRetryTimer?.cancel();
    _controller.cancel();
    super.dispose();
  }

  void _addEvent(String event) {
    if (!mounted) return;
    setState(() => _events.add(event));
  }

  Future<bool> _onWebViewError(Object error) async {
    _addEvent('✗ Error: $error');

    if (_internetCheckInProgress) return false;
    _internetCheckInProgress = true;
    final hasInternet = await hasValidInternetConnection().whenComplete(
      () => _internetCheckInProgress = false,
    );
    if (!mounted) return false;

    if (hasInternet) {
      _log.warningWithMetadata(
        "CF WebView error; retrying",
        metadata: {"url": widget.url, "error": error.toString()},
      );
      return true;
    }

    _log.warningWithMetadata(
      "CF WebView is offline; waiting to retry",
      metadata: {"url": widget.url, "error": error.toString()},
    );
    _showOfflineState();
    _startConnectivityRetry();
    return false;
  }

  void _showOfflineState() {
    setState(() {
      _status = _SolveStatus.offline;
      _statusMessage = 'No internet access. Waiting to reconnect...';
    });
    _addEvent('! No internet access; waiting to reconnect...');

    if (_offlineToastShown) return;
    _offlineToastShown = true;
    AppToast.showWarning(
      context,
      title: 'No internet access',
      description: 'CloudFlare verification will retry when you reconnect.',
    );
  }

  void _startConnectivityRetry() {
    _connectivityRetryTimer ??= Timer.periodic(
      _connectivityRetryInterval,
      (_) => unawaited(_retryWhenInternetReturns()),
    );
  }

  Future<void> _retryWhenInternetReturns() async {
    if (_internetCheckInProgress) return;
    _internetCheckInProgress = true;
    final hasInternet = await hasValidInternetConnection().whenComplete(
      () => _internetCheckInProgress = false,
    );
    if (!mounted || !hasInternet) return;

    _connectivityRetryTimer?.cancel();
    _connectivityRetryTimer = null;
    _offlineToastShown = false;
    setState(() {
      _status = _SolveStatus.solving;
      _statusMessage = 'Internet restored. Retrying verification...';
    });
    _addEvent('✓ Internet restored; retrying...');
    await _controller.retry();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('CloudFlare Verification'),
        leading: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        actions: [
          if (_status == _SolveStatus.solving)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: TextButton.icon(
                  onPressed: () => _controller.retry(),
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Retry'),
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          _StatusBanner(status: _status, message: _statusMessage),
          Expanded(
            child: CfWebView(
              url: widget.url,
              controller: _controller,
              timeout: const Duration(minutes: 2),
              stallThreshold: 3,
              clearCfCookiesOnInit: true,
              onSuccess: (result) {
                _log.infoWithMetadata(
                  "CF bypass succeeded",
                  metadata: {
                    "url": widget.url,
                    "cookieCount": result.cookies.length,
                  },
                );
                _addEvent('✓ Bypass succeeded');
                setState(() {
                  _status = _SolveStatus.success;
                  _statusMessage =
                      'Solved in ${result.duration?.inSeconds ?? "?"}s';
                });
                // Small delay so user sees success state.
                final navigator = Navigator.of(context);
                Future.delayed(const Duration(milliseconds: 600), () {
                  if (mounted) navigator.pop(result);
                });
              },
              onFailure: (result) {
                if (_status == _SolveStatus.offline) {
                  _log.warningWithMetadata(
                    "CF bypass timed out while offline; still waiting",
                    metadata: {"url": widget.url, "error": result.error},
                  );
                  return;
                }
                _log.warningWithMetadata(
                  "CF bypass failed",
                  metadata: {"url": widget.url, "error": result.error},
                );
                _addEvent('✗ ${result.error ?? "Bypass failed"}');
                setState(() {
                  _status = _SolveStatus.failed;
                  _statusMessage = result.error ?? 'Bypass failed';
                });
              },
              onCancelled: () {
                _addEvent('— Cancelled');
                if (mounted) Navigator.pop(context);
              },
              onPageStartedLoading: (url) =>
                  _addEvent('→ Loading ${_shortenUrl(url)}'),
              onPageFinishedLoading: (url) =>
                  _addEvent('✓ Loaded ${_shortenUrl(url)}'),
              onLoopDetected: () {
                _addEvent('⟳ Loop detected, retrying…');
                _controller.retry();
              },
              onError: _onWebViewError,
            ),
          ),
          if (_events.isNotEmpty)
            Container(
              height: 120,
              width: double.infinity,
              color: colorScheme.surfaceContainerHighest,
              padding: const EdgeInsets.all(8),
              child: ListView.builder(
                reverse: true,
                itemCount: _events.length,
                itemBuilder: (_, i) {
                  final event = _events[_events.length - 1 - i];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Text(
                      event,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurface.withValues(alpha: 0.7),
                        fontFamily: 'monospace',
                        fontSize: 11,
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

String _shortenUrl(String? url) {
  if (url == null) return '?';
  final uri = Uri.tryParse(url);
  if (uri == null) return url;
  return uri.host + uri.path;
}

enum _SolveStatus { solving, offline, success, failed }

class _StatusBanner extends StatelessWidget {
  final _SolveStatus status;
  final String? message;

  const _StatusBanner({required this.status, this.message});

  @override
  Widget build(BuildContext context) {
    final (color, icon, text) = switch (status) {
      _SolveStatus.solving => (
        Colors.amber,
        Icons.hourglass_top,
        message ?? 'Solving challenge…',
      ),
      _SolveStatus.offline => (
        Colors.orange,
        Icons.wifi_off_rounded,
        message ?? 'No internet access',
      ),
      _SolveStatus.success => (
        Colors.green,
        Icons.check_circle,
        message ?? 'Solved!',
      ),
      _SolveStatus.failed => (Colors.red, Icons.error, message ?? 'Failed'),
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: color.withValues(alpha: 0.15),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
