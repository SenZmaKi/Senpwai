import 'dart:async';

import 'package:cf_bypass/cf_bypass.dart' hide LoggerExtensions;
import 'package:flutter/material.dart';
import 'package:senpwai/shared/net/connectivity.dart';
import 'package:senpwai/shared/log.dart';
import 'package:senpwai/ui/components/toast.dart';
import 'package:senpwai/ui/pages/anime_page/cf_bypass_coordinator.dart';
import 'package:senpwai/ui/pages/anime_page/cf_bypass_flow_widgets.dart';

final _log = Logger("senpwai.ui.pages.anime_page.cf_bypass");

/// Full-screen flow that renders one [CfWebView] at a time while queued
/// CloudFlare challenges are solved.
class CfBypassPage extends StatefulWidget {
  final CfBypassCoordinator coordinator;

  const CfBypassPage({super.key, required this.coordinator});

  @override
  State<CfBypassPage> createState() => _CfBypassPageState();
}

class _CfBypassPageState extends State<CfBypassPage> {
  static const _connectivityRetryInterval = Duration(seconds: 3);
  static const _maxRejectedCandidateAttempts = 3;

  late CfBypassController _controller;
  CfBypassSolveStatus _status = CfBypassSolveStatus.solving;
  String? _statusMessage;
  final _events = <String>[];
  final _rejectedCandidateCounts = <String, int>{};
  Timer? _connectivityRetryTimer;
  bool _internetCheckInProgress = false;
  bool _offlineToastShown = false;
  int? _activeItemId;

  @override
  void initState() {
    super.initState();
    _controller = CfBypassController();
    _syncActiveItem();
    widget.coordinator.addListener(_onCoordinatorChanged);
  }

  @override
  void dispose() {
    widget.coordinator.removeListener(_onCoordinatorChanged);
    _connectivityRetryTimer?.cancel();
    _controller.cancel();
    super.dispose();
  }

  void _onCoordinatorChanged() {
    if (!mounted) return;
    if (widget.coordinator.active == null) {
      widget.coordinator.closeRoute();
      return;
    }
    final activeChanged = _syncActiveItem();
    if (!activeChanged) setState(() {});
  }

  bool _syncActiveItem() {
    final active = widget.coordinator.active;
    if (active == null || active.id == _activeItemId) return false;
    _connectivityRetryTimer?.cancel();
    _connectivityRetryTimer = null;
    _controller = CfBypassController();
    _activeItemId = active.id;
    _internetCheckInProgress = false;
    _offlineToastShown = false;
    _rejectedCandidateCounts.clear();
    setState(() {
      _status = CfBypassSolveStatus.solving;
      _statusMessage = 'Opening ${shortenCfBypassUrl(active.challenge.url)}...';
      _events
        ..clear()
        ..add('-> Queued ${shortenCfBypassUrl(active.challenge.url)}');
    });
    return true;
  }

  void _addEvent(String event) {
    if (!mounted) return;
    setState(() => _events.add(event));
  }

  Future<bool> _onWebViewError(Object error) async {
    _addEvent('Error: $error');

    if (_internetCheckInProgress) return false;
    _internetCheckInProgress = true;
    final hasInternet = await hasValidInternetConnection().whenComplete(
      () => _internetCheckInProgress = false,
    );
    if (!mounted) return false;

    if (hasInternet) {
      _log.warningWithMetadata(
        "CF WebView error; retrying",
        metadata: {"url": _activeUrl, "error": error.toString()},
      );
      return true;
    }

    _log.warningWithMetadata(
      "CF WebView is offline; waiting to retry",
      metadata: {"url": _activeUrl, "error": error.toString()},
    );
    _showOfflineState();
    _startConnectivityRetry();
    return false;
  }

  String get _activeUrl => widget.coordinator.active?.challenge.url ?? '';

  void _showOfflineState() {
    setState(() {
      _status = CfBypassSolveStatus.offline;
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
      _status = CfBypassSolveStatus.solving;
      _statusMessage = 'Internet restored. Retrying verification...';
    });
    _addEvent('Internet restored; retrying...');
    await _controller.retry();
  }

  int _recordRejectedCandidate(CfBypassResult result) {
    final fingerprint =
        CfCookieHelper.getBypassFingerprint(result.cookies) ?? 'unknown';
    final count = (_rejectedCandidateCounts[fingerprint] ?? 0) + 1;
    _rejectedCandidateCounts[fingerprint] = count;
    return count;
  }

  void _resetRejectedCandidates() {
    _rejectedCandidateCounts.clear();
  }

  @override
  Widget build(BuildContext context) {
    final active = widget.coordinator.active;
    if (active == null) return const SizedBox.shrink();

    final activeUrl = active.challenge.url;

    return Scaffold(
      appBar: AppBar(
        title: CfBypassHeaderTitle(
          current: widget.coordinator.activePosition,
          total: widget.coordinator.totalCount,
          currentUrl: activeUrl,
        ),
        leading: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: IconButton(
            icon: const Icon(Icons.close),
            onPressed: widget.coordinator.cancelAll,
          ),
        ),
        actions: [
          if (_status == CfBypassSolveStatus.solving ||
              _status == CfBypassSolveStatus.failed)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: TextButton.icon(
                  onPressed: () {
                    _resetRejectedCandidates();
                    setState(() {
                      _status = CfBypassSolveStatus.solving;
                      _statusMessage = 'Retrying verification...';
                    });
                    _controller.retry();
                  },
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Retry'),
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          CfBypassStatusBanner(status: _status, message: _statusMessage),
          Expanded(
            child: CfWebView(
              key: ValueKey(active.id),
              url: activeUrl,
              controller: _controller,
              timeout: const Duration(minutes: 2),
              stallThreshold: 3,
              clearAllDataOnInit: true,
              clearCfCookiesOnInit: true,
              onSuccess: (result) async {
                _log.infoWithMetadata(
                  "CF bypass candidate captured",
                  metadata: {
                    "url": activeUrl,
                    "cookieCount": result.cookies.length,
                  },
                );
                setState(() {
                  _status = CfBypassSolveStatus.verifying;
                  _statusMessage = 'Verifying captured clearance...';
                });
                _addEvent('... Verifying captured clearance');

                final verified = await active.challenge.validate(result);
                if (!mounted) return verified;
                if (!verified) {
                  final rejectionCount = _recordRejectedCandidate(result);
                  _log.warningWithMetadata(
                    "CF bypass candidate rejected",
                    metadata: {
                      "url": activeUrl,
                      "rejectionCount": rejectionCount,
                      "maxRejections": _maxRejectedCandidateAttempts,
                      "cookieCount": result.cookies.length,
                    },
                  );
                  if (rejectionCount >= _maxRejectedCandidateAttempts) {
                    throw StateError(
                      'CloudFlare clearance was rejected '
                      '$rejectionCount times by validation replay.',
                    );
                  }
                  setState(() {
                    _status = CfBypassSolveStatus.solving;
                    _statusMessage =
                        'Clearance did not pass. Retrying verification...';
                  });
                  _addEvent('Retrying rejected clearance...');
                  return false;
                }

                _log.infoWithMetadata(
                  "CF bypass verified",
                  metadata: {
                    "url": activeUrl,
                    "cookieCount": result.cookies.length,
                  },
                );
                _addEvent('Bypass verified');
                setState(() {
                  _status = CfBypassSolveStatus.success;
                  _statusMessage =
                      'Verified in ${result.duration?.inSeconds ?? "?"}s';
                });
                // Small delay so user sees success state.
                Future.delayed(const Duration(milliseconds: 600), () {
                  if (!mounted || widget.coordinator.active?.id != active.id) {
                    return;
                  }
                  widget.coordinator.completeActive(result);
                });
                return true;
              },
              onFailure: (result) {
                if (_status == CfBypassSolveStatus.offline) {
                  _log.warningWithMetadata(
                    "CF bypass timed out while offline; still waiting",
                    metadata: {"url": activeUrl, "error": result.error},
                  );
                  return;
                }
                _log.warningWithMetadata(
                  "CF bypass failed",
                  metadata: {"url": activeUrl, "error": result.error},
                );
                _addEvent(result.error ?? 'Bypass failed');
                setState(() {
                  _status = CfBypassSolveStatus.failed;
                  _statusMessage = result.error ?? 'Bypass failed';
                });
              },
              onCancelled: () {
                _addEvent('Cancelled');
                widget.coordinator.cancelAll();
              },
              onPageStartedLoading: (url) {
                final shortUrl = shortenCfBypassUrl(url);
                if (_status == CfBypassSolveStatus.solving) {
                  setState(() => _statusMessage = 'Loading $shortUrl...');
                }
                _addEvent('-> Loading $shortUrl');
              },
              onPageFinishedLoading: (url) {
                final shortUrl = shortenCfBypassUrl(url);
                if (_status == CfBypassSolveStatus.solving) {
                  setState(
                    () => _statusMessage =
                        'Loaded $shortUrl. Waiting for clearance...',
                  );
                }
                _addEvent('Loaded $shortUrl');
              },
              onLoopDetected: () {
                _addEvent('Loop detected, retrying...');
                _resetRejectedCandidates();
                _controller.retry();
              },
              onError: _onWebViewError,
            ),
          ),
          CfBypassEventLog(events: _events),
        ],
      ),
    );
  }
}
