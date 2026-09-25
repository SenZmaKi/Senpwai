import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:logging/logging.dart';
import 'package:senpwai/shared/log.dart';
import 'package:senpwai/shared/net/browser_transport/routing.dart';

final _log = Logger('senpwai.net.browser_transport');

class BrowserTransportRequest {
  final Uri uri;
  final Uri bootstrapUri;
  final String method;
  final Map<String, String> headers;
  final Uint8List? body;
  final BrowserExecutionMode executionMode;
  final BrowserNavigationPolicy? navigationPolicy;
  final VoidCallback? onUserCancel;
  final Uri? referrer;
  final Duration readyTimeout;
  final Duration timeout;

  const BrowserTransportRequest({
    required this.uri,
    required this.bootstrapUri,
    required this.method,
    required this.headers,
    this.executionMode = BrowserExecutionMode.fetch,
    this.navigationPolicy,
    this.onUserCancel,
    this.referrer,
    this.body,
    required this.readyTimeout,
    required this.timeout,
  });
}

class BrowserTransportResponse {
  final int statusCode;
  final Uint8List body;
  final Uri finalUri;
  final Map<String, List<String>> headers;

  const BrowserTransportResponse({
    required this.statusCode,
    required this.body,
    required this.finalUri,
    required this.headers,
  });
}

class BrowserTransportException implements Exception {
  final String message;

  const BrowserTransportException(this.message);

  @override
  String toString() => 'BrowserTransportException: $message';
}

enum _ReadinessState { loading, ready, failed, closed }

class _DocumentChanged implements Exception {
  const _DocumentChanged();
}

class _OperationWaiter {
  final bool exclusive;
  final Completer<void> completer = Completer<void>();

  _OperationWaiter({required this.exclusive});
}

class _SessionOperationLock {
  final Queue<_OperationWaiter> _waiters = Queue<_OperationWaiter>();
  int _readers = 0;
  bool _writerActive = false;

  Future<T> shared<T>(Future<T> Function() operation) async {
    await _acquire(exclusive: false);
    try {
      return await operation();
    } finally {
      _readers--;
      _drain();
    }
  }

  Future<T> exclusive<T>(Future<T> Function() operation) async {
    await _acquire(exclusive: true);
    try {
      return await operation();
    } finally {
      _writerActive = false;
      _drain();
    }
  }

  Future<void> _acquire({required bool exclusive}) {
    if (_waiters.isEmpty &&
        !_writerActive &&
        (exclusive ? _readers == 0 : true)) {
      if (exclusive) {
        _writerActive = true;
      } else {
        _readers++;
      }
      return Future<void>.value();
    }
    final waiter = _OperationWaiter(exclusive: exclusive);
    _waiters.add(waiter);
    return waiter.completer.future;
  }

  void _drain() {
    if (_writerActive || _waiters.isEmpty) return;
    final first = _waiters.first;
    if (first.exclusive) {
      if (_readers > 0) return;
      _writerActive = true;
      _waiters.removeFirst().completer.complete();
      return;
    }
    while (_waiters.isNotEmpty && !_waiters.first.exclusive) {
      _readers++;
      _waiters.removeFirst().completer.complete();
    }
  }
}

class BrowserTransportService extends ChangeNotifier {
  BrowserTransportService._();

  static final instance = BrowserTransportService._();

  final Map<String, BrowserHostSession> _sessions = {};
  final Map<String, Timer> _idleTimers = {};
  final Map<String, int> _activeRequests = {};
  final Map<String, Set<VoidCallback>> _userCancellationCallbacks = {};
  Duration _idleTimeout = const Duration(minutes: 10);
  int _nextRequestId = 0;
  Future<void>? _maintenance;

  List<BrowserHostSession> get sessions => List.unmodifiable(_sessions.values);
  BrowserHostSession? get visibleSession => _sessions.values
      .where((session) => session.requiresInteraction)
      .firstOrNull;

  void updateIdleTimeout(Duration timeout) {
    if (timeout <= Duration.zero) {
      throw ArgumentError.value(timeout, 'timeout', 'Must be positive.');
    }
    _idleTimeout = timeout;
    for (final host in _sessions.keys) {
      _scheduleIdleClose(host);
    }
  }

  Future<BrowserTransportResponse> send(
    BrowserTransportRequest request, {
    Future<void>? cancelFuture,
  }) async {
    final maintenance = _maintenance;
    if (maintenance != null) await maintenance;
    final host = request.uri.host.toLowerCase();
    if (request.bootstrapUri.host.toLowerCase() != host) {
      throw BrowserTransportException(
        'Bootstrap origin ${request.bootstrapUri.host} does not match $host.',
      );
    }
    final session = _sessions.putIfAbsent(
      host,
      () => BrowserHostSession(
        host: host,
        bootstrapUri: request.bootstrapUri,
        onChanged: () => _sessionChanged(host),
        nextRequestId: () => _nextRequestId++,
      ),
    );
    _idleTimers.remove(host)?.cancel();
    _activeRequests[host] = (_activeRequests[host] ?? 0) + 1;
    final userCancel = request.onUserCancel;
    if (userCancel != null) {
      (_userCancellationCallbacks[host] ??= {}).add(userCancel);
    }
    notifyListeners();
    try {
      return await session.send(request, cancelFuture: cancelFuture);
    } finally {
      if (userCancel != null) {
        final callbacks = _userCancellationCallbacks[host];
        callbacks?.remove(userCancel);
        if (callbacks?.isEmpty ?? false) {
          _userCancellationCallbacks.remove(host);
        }
      }
      final remaining = (_activeRequests[host] ?? 1) - 1;
      if (remaining <= 0) {
        _activeRequests.remove(host);
        _scheduleIdleClose(host);
      } else {
        _activeRequests[host] = remaining;
      }
    }
  }

  Future<void> cancelSessionRequests(String host) async {
    final normalizedHost = host.toLowerCase();
    final callbacks = _userCancellationCallbacks
        .remove(normalizedHost)
        ?.toList();
    for (final cancel in callbacks ?? const <VoidCallback>[]) {
      cancel();
    }

    _idleTimers.remove(normalizedHost)?.cancel();
    final session = _sessions.remove(normalizedHost);
    if (session == null) return;

    // Remove the session before stopping its WebView so the verification page
    // closes immediately. Closing also fails requests that do not have a Dio
    // CancelToken, ensuring the user action always ends the verification.
    notifyListeners();
    await session.close();
  }

  Future<void> clearSessions() async {
    final existing = _maintenance;
    if (existing != null) return existing;

    late final Future<void> operation;
    operation = _clearSessions().whenComplete(() {
      if (identical(_maintenance, operation)) _maintenance = null;
    });
    _maintenance = operation;
    return operation;
  }

  Future<void> _clearSessions() async {
    await CookieManager.instance().deleteAllCookies();
    // flutter_inappwebview_windows exposes clearAllCache in Dart but does not
    // register the manager-channel method in its native implementation.
    if (defaultTargetPlatform != TargetPlatform.windows) {
      await InAppWebViewController.clearAllCache();
    }
    await Future.wait(_sessions.values.map((session) => session.reset()));
  }

  void reconcileOrigins(Map<String, Uri> origins) {
    final normalized = {
      for (final entry in origins.entries) entry.key.toLowerCase(): entry.value,
    };
    final removed = _sessions.keys.where((host) {
      final origin = normalized[host];
      final session = _sessions[host];
      return origin == null || session?.bootstrapUri != origin;
    }).toList();
    for (final host in removed) {
      _idleTimers.remove(host)?.cancel();
      _userCancellationCallbacks.remove(host);
      final session = _sessions.remove(host);
      if (session != null) unawaited(session.close());
    }
    if (removed.isNotEmpty) notifyListeners();
  }

  Future<void> retireSession(
    BrowserHostSession session, {
    required String reason,
  }) async {
    final host = session.host;
    if (!identical(_sessions[host], session)) return;
    _idleTimers.remove(host)?.cancel();
    _sessions.remove(host);
    notifyListeners();
    await session.close(reason: reason);
  }

  void _sessionChanged(String host) {
    notifyListeners();
    _scheduleIdleClose(host);
  }

  void _scheduleIdleClose(String host) {
    _idleTimers.remove(host)?.cancel();
    final session = _sessions[host];
    if (session == null || (_activeRequests[host] ?? 0) > 0) {
      return;
    }
    _idleTimers[host] = Timer(_idleTimeout, () {
      _idleTimers.remove(host);
      final current = _sessions[host];
      if (!identical(current, session) || (_activeRequests[host] ?? 0) > 0) {
        return;
      }
      _sessions.remove(host);
      unawaited(session.close());
      notifyListeners();
    });
  }
}

class BrowserHostSession {
  static const _handlerName = 'senpwaiBrowserTransportResponse';
  static const _documentSettleDuration = Duration(milliseconds: 500);
  static const _activeDocumentChallengeMarkers = <String>[
    'window._cf_chl_opt',
    'id="challenge-error-text"',
    'cf-chl-widget-',
    'challenges.cloudflare.com',
  ];

  final String host;
  final Uri bootstrapUri;
  final VoidCallback onChanged;
  final int Function() nextRequestId;
  final Map<int, Completer<BrowserTransportResponse>> _pending = {};
  Completer<BrowserTransportResponse>? _pendingFormSubmission;

  InAppWebViewController? _controller;
  Completer<void> _ready = Completer<void>();
  _ReadinessState _readinessState = _ReadinessState.loading;
  Future<void>? _recovery;
  final _operationLock = _SessionOperationLock();
  String? _expectedNavigationAbortUrl;
  int _navigationStopCount = 0;
  int _documentGeneration = 0;
  bool _loadFinished = false;
  bool requiresInteraction = false;

  BrowserHostSession({
    required this.host,
    required this.bootstrapUri,
    required this.onChanged,
    required this.nextRequestId,
  });

  Uri get origin => Uri.https(host, '/');

  Future<void> attach(InAppWebViewController controller) async {
    _controller = controller;
    _log.infoWithMetadata('Browser session attached', metadata: {'host': host});
    controller.addJavaScriptHandler(
      handlerName: _handlerName,
      callback: (arguments) {
        final args = arguments as List<dynamic>;
        if (args.isEmpty || args.first is! Map) return;
        _completeJavaScriptResponse(
          Map<String, dynamic>.from(args.first as Map),
        );
      },
    );
  }

  void pageStarted() {
    if (_readinessState == _ReadinessState.closed) return;
    _documentGeneration++;
    _loadFinished = false;
    if (_readinessState != _ReadinessState.loading) {
      _startReadinessEpoch(requiresUserInteraction: requiresInteraction);
    }
    _failPendingFetches('Browser document navigated during request.');
  }

  void pageFinished() {
    if (_readinessState == _ReadinessState.closed) return;
    _loadFinished = true;
    _documentGeneration++;
    _scheduleSettledInspection();
  }

  Future<void> pageTitleChanged() {
    if (_readinessState == _ReadinessState.closed) return Future<void>.value();
    _documentGeneration++;
    if (_loadFinished) _scheduleSettledInspection();
    return _inspectDocument(
      completeReady: false,
      expectedGeneration: _documentGeneration,
    );
  }

  void _scheduleSettledInspection() {
    final generation = _documentGeneration;
    unawaited(
      Future<void>.delayed(_documentSettleDuration).then((_) async {
        if (!_loadFinished || generation != _documentGeneration) return;
        await _inspectDocument(
          completeReady: true,
          expectedGeneration: generation,
        );
      }),
    );
  }

  Future<void> _inspectDocument({
    required bool completeReady,
    required int expectedGeneration,
  }) async {
    if (_navigationStopCount > 0 ||
        _readinessState == _ReadinessState.closed ||
        expectedGeneration != _documentGeneration) {
      return;
    }
    final controller = _controller;
    if (controller == null) return;
    try {
      final html = (await controller.evaluateJavascript(
        source: 'document.documentElement?.outerHTML ?? ""',
      ))?.toString();
      if (expectedGeneration != _documentGeneration) return;
      final challenged = _documentLooksChallenged(html ?? '');
      final currentUrl = await controller.getUrl();
      if (expectedGeneration != _documentGeneration) return;
      requiresInteraction = challenged;
      _log.infoWithMetadata(
        challenged ? 'Browser challenge page loaded' : 'Browser session ready',
        metadata: {
          'host': host,
          'url': currentUrl?.toString(),
          'loadCompleted': completeReady,
          'formSubmissionPending': _pendingFormSubmission != null,
        },
      );
      if (completeReady && !challenged) {
        await _failFinishedFormWithoutRedirect(controller);
      }
      if (completeReady && !challenged && !_ready.isCompleted) {
        _readinessState = _ReadinessState.ready;
        _ready.complete();
      }
      onChanged();
    } catch (error) {
      if (expectedGeneration != _documentGeneration ||
          _readinessState == _ReadinessState.closed) {
        return;
      }
      if (completeReady) {
        pageFailed(error);
      } else {
        _log.fineWithMetadata(
          'Could not inspect browser title transition',
          metadata: {'host': host, 'error': error.toString()},
        );
      }
    }
  }

  Future<void> _failFinishedFormWithoutRedirect(
    InAppWebViewController controller,
  ) async {
    final completer = _pendingFormSubmission;
    if (completer == null || completer.isCompleted) return;

    final currentUri = Uri.tryParse(
      (await controller.getUrl())?.toString() ?? '',
    );
    if (currentUri == null || currentUri.host.toLowerCase() != host) return;

    final error = BrowserTransportException(
      'Browser form submission finished without a download redirect: '
      '$currentUri',
    );
    _log.warningWithMetadata(
      'Browser form submission did not redirect',
      metadata: {'host': host, 'url': currentUri.toString()},
    );
    completer.completeError(error);
  }

  void pageFailed(Object error) {
    if (_readinessState == _ReadinessState.closed) return;
    requiresInteraction = true;
    _log.warningWithMetadata(
      'Browser session failed to load',
      metadata: {'host': host, 'error': error.toString()},
    );
    if (!_ready.isCompleted) {
      _readinessState = _ReadinessState.failed;
      _ready.completeError(BrowserTransportException(error.toString()));
    }
    _failPendingFetches('Browser session failed to load: $error');
    onChanged();
  }

  void handleLoadError(WebResourceRequest request, WebResourceError error) {
    if (_navigationStopCount > 0) return;
    if (request.isForMainFrame != false &&
        _expectedNavigationAbortUrl == request.url.toString() &&
        error.type == WebResourceErrorType.CONNECTION_ABORTED) {
      _expectedNavigationAbortUrl = null;
      _log.fineWithMetadata(
        'Ignored intentionally cancelled media navigation',
        metadata: {'host': host, 'url': request.url.toString()},
      );
      return;
    }
    if (request.isForMainFrame != false) pageFailed(error);
  }

  Future<BrowserTransportResponse> send(
    BrowserTransportRequest request, {
    Future<void>? cancelFuture,
  }) async {
    var cancelled = false;
    if (cancelFuture != null) {
      unawaited(cancelFuture.then((_) => cancelled = true));
    }
    if (request.uri.host.toLowerCase() != host) {
      throw BrowserTransportException(
        'Session for $host cannot request ${request.uri.host}.',
      );
    }
    await _waitUntilReady(request.readyTimeout, cancelFuture: cancelFuture);
    if (cancelled) {
      throw const BrowserTransportException('Request cancelled.');
    }
    if (request.executionMode == BrowserExecutionMode.submitForm) {
      return _runExclusiveNavigation(() {
        if (cancelled) {
          throw const BrowserTransportException('Request cancelled.');
        }
        return _submitForm(request, cancelFuture: cancelFuture);
      });
    }
    if (request.executionMode == BrowserExecutionMode.navigate) {
      return _runExclusiveNavigation(() {
        if (cancelled) {
          throw const BrowserTransportException('Request cancelled.');
        }
        return _navigate(request, cancelFuture: cancelFuture);
      });
    }
    BrowserTransportResponse response;
    try {
      response = await _fetchRequest(request, cancelFuture: cancelFuture);
    } catch (_) {
      if (cancelled) rethrow;
      final recovery = _recovery;
      if (recovery == null) rethrow;
      await recovery;
      return _fetchAfterRecovery(request, cancelFuture: cancelFuture);
    }
    if (!_isChallengeResponse(response)) return response;

    await (_recovery ??= _runExclusiveNavigation(
      () => _recover(request.uri, request.readyTimeout),
    ).whenComplete(() => _recovery = null));
    return _fetchAfterRecovery(request, cancelFuture: cancelFuture);
  }

  Future<BrowserTransportResponse> _fetchAfterRecovery(
    BrowserTransportRequest request, {
    Future<void>? cancelFuture,
  }) async {
    final response = await _fetchRequest(request, cancelFuture: cancelFuture);
    if (_isChallengeResponse(response)) {
      throw BrowserTransportException(
        'Browser challenge remained after verification: ${request.uri}',
      );
    }
    return response;
  }

  Future<BrowserTransportResponse> _submitForm(
    BrowserTransportRequest request, {
    Future<void>? cancelFuture,
  }) async {
    final controller = _controller;
    if (controller == null) {
      throw const BrowserTransportException('Browser session is not mounted.');
    }
    final navigationPolicy = request.navigationPolicy;
    if (navigationPolicy == null) {
      throw const BrowserTransportException(
        'Form submission requires a navigation success policy.',
      );
    }
    final contentType = request.headers.entries
        .where((entry) => entry.key.toLowerCase() == 'content-type')
        .map((entry) => entry.value.toLowerCase())
        .firstOrNull;
    if (contentType != null &&
        !contentType.contains('application/x-www-form-urlencoded') &&
        !contentType.contains('application/json')) {
      throw BrowserTransportException(
        'Unsupported browser form content type: $contentType',
      );
    }

    var cancelled = false;
    Completer<BrowserTransportResponse>? submissionCompleter;
    if (cancelFuture != null) {
      unawaited(
        cancelFuture.then((_) async {
          cancelled = true;
          await _stopNavigation(controller);

          // Stopping a referrer load does not produce a reliable load event on
          // every platform. Do not leave the session gated by that abandoned
          // navigation, or the next request will wait for readiness forever.
          if (!_ready.isCompleted) _ready.complete();

          final completer = submissionCompleter;
          if (completer != null && !completer.isCompleted) {
            completer.completeError(
              const BrowserTransportException('Request cancelled.'),
            );
          }
        }),
      );
    }
    _activeNavigationPolicy = navigationPolicy;

    _log.infoWithMetadata(
      'Preparing browser form submission',
      metadata: {
        'host': host,
        'url': request.uri.toString(),
        'referrer': request.referrer?.toString(),
        'bodyBytes': request.body?.length ?? 0,
        'timeoutMs': request.timeout.inMilliseconds,
      },
    );
    await _ensureDocument(request.referrer, request.readyTimeout);
    if (cancelled) {
      throw const BrowserTransportException('Request cancelled.');
    }
    _log.infoWithMetadata(
      'Browser form document ready',
      metadata: {'host': host, 'url': (await controller.getUrl())?.toString()},
    );
    if (cancelled) {
      throw const BrowserTransportException('Request cancelled.');
    }

    final completer = Completer<BrowserTransportResponse>();
    submissionCompleter = completer;
    _pendingFormSubmission = completer;

    final payload = jsonEncode({
      'url': request.uri.toString(),
      'contentType': request.headers.entries
          .where((entry) => entry.key.toLowerCase() == 'content-type')
          .map((entry) => entry.value)
          .firstOrNull,
      'body': base64Encode(request.body ?? Uint8List(0)),
    });
    try {
      _log.infoWithMetadata(
        'Dispatching browser form submission',
        metadata: {
          'host': host,
          'url': request.uri.toString(),
          'method': request.method,
        },
      );
      unawaited(
        controller
            .evaluateJavascript(source: _formSubmissionScript(payload))
            .catchError((Object error, StackTrace stackTrace) {
              if (!completer.isCompleted) {
                completer.completeError(
                  BrowserTransportException(
                    'Could not submit browser form: $error',
                  ),
                  stackTrace,
                );
              }
              return null;
            }),
      );
      _log.infoWithMetadata(
        'Browser form submission dispatched',
        metadata: {'host': host, 'url': request.uri.toString()},
      );
      return await completer.future.timeout(
        request.timeout,
        onTimeout: () async {
          _log.warningWithMetadata(
            'Browser form submission timed out',
            metadata: {
              'host': host,
              'requestUrl': request.uri.toString(),
              'currentUrl': (await controller.getUrl())?.toString(),
              'timeoutMs': request.timeout.inMilliseconds,
            },
          );
          await _stopNavigation(controller);
          throw BrowserTransportException(
            'Browser form submission timed out: ${request.uri}',
          );
        },
      );
    } catch (error, stackTrace) {
      _log.severeWithMetadata(
        'Browser form submission failed',
        metadata: {
          'host': host,
          'requestUrl': request.uri.toString(),
          'errorType': error.runtimeType.toString(),
        },
        error: error,
        stackTrace: stackTrace,
      );
      rethrow;
    } finally {
      if (identical(_pendingFormSubmission, completer)) {
        _pendingFormSubmission = null;
      }
    }
  }

  String _formSubmissionScript(String payload) =>
      '''
    (() => {
      const request = $payload;
      const binary = atob(request.body);
      const bytes = Uint8Array.from(binary, c => c.charCodeAt(0));
      const text = new TextDecoder().decode(bytes);
      let fields;
      if ((request.contentType || '').toLowerCase().includes('json')) {
        fields = Object.entries(text ? JSON.parse(text) : {});
      } else {
        fields = Array.from(new URLSearchParams(text).entries());
      }
      const form = document.createElement('form');
      form.method = 'POST';
      form.action = request.url;
      form.enctype = 'application/x-www-form-urlencoded';
      for (const [name, value] of fields) {
        const input = document.createElement('input');
        input.type = 'hidden';
        input.name = name;
        input.value = String(value);
        form.appendChild(input);
      }
      document.body.appendChild(form);
      form.submit();
    })();
  ''';

  Future<void> _ensureDocument(Uri? target, Duration timeout) async {
    if (target == null || target.host.toLowerCase() != host) return;
    final controller = _controller;
    if (controller == null) return;
    final current = await controller.getUrl();
    if (current?.toString() == target.toString()) return;

    _log.infoWithMetadata(
      'Loading browser form referrer',
      metadata: {
        'host': host,
        'currentUrl': current?.toString(),
        'targetUrl': target.toString(),
      },
    );
    _startReadinessEpoch();
    await controller.loadUrl(
      urlRequest: URLRequest(url: WebUri(target.toString())),
    );
    await _ready.future.timeout(timeout);
  }

  Future<BrowserTransportResponse> _navigate(
    BrowserTransportRequest request, {
    Future<void>? cancelFuture,
  }) async {
    final controller = _controller;
    if (controller == null) {
      throw const BrowserTransportException('Browser session is not mounted.');
    }

    _startReadinessEpoch();
    final navigationReady = _ready;
    final cancellation = cancelFuture?.then<void>((_) async {
      await _stopNavigation(controller);
      throw const BrowserTransportException('Request cancelled.');
    });
    unawaited(
      controller
          .loadUrl(
            urlRequest: URLRequest(
              url: WebUri(request.uri.toString()),
              headers: request.referrer == null
                  ? null
                  : {'Referer': request.referrer.toString()},
            ),
          )
          .catchError((Object error, StackTrace stackTrace) {
            if (!navigationReady.isCompleted) {
              navigationReady.completeError(error, stackTrace);
            }
          }),
    );
    await Future.any([
      navigationReady.future,
      if (cancellation != null) cancellation,
    ]).timeout(
      request.timeout,
      onTimeout: () async {
        await _stopNavigation(controller);
        throw BrowserTransportException(
          'Browser navigation timed out: ${request.uri}',
        );
      },
    );

    final html = (await controller.evaluateJavascript(
      source: 'document.documentElement?.outerHTML ?? ""',
    ))?.toString();
    final finalUrl = await controller.getUrl();
    return BrowserTransportResponse(
      statusCode: 200,
      body: Uint8List.fromList(utf8.encode(html ?? '')),
      finalUri: Uri.tryParse(finalUrl?.toString() ?? '') ?? request.uri,
      headers: const {
        'content-type': ['text/html; charset=utf-8'],
      },
    );
  }

  NavigationActionPolicy handleNavigation(NavigationAction action) {
    final completer = _pendingFormSubmission;
    final uri = action.request.url;
    if (action.isForMainFrame && uri != null) {
      final accepted =
          completer != null && (_activeNavigationPolicy?.accepts(uri) ?? false);
      _log.infoWithMetadata(
        'Browser main-frame navigation observed',
        metadata: {
          'host': host,
          'method': action.request.method,
          'url': uri.toString(),
          'formSubmissionPending': completer != null,
          'leavesSessionHost': uri.host.toLowerCase() != host,
          'acceptedAsResult': accepted,
        },
      );
    }
    if (completer == null ||
        uri == null ||
        !action.isForMainFrame ||
        uri.host.toLowerCase() == host) {
      return NavigationActionPolicy.ALLOW;
    }

    _expectedNavigationAbortUrl = uri.toString();
    _markReadyAfterCancelledNavigation();
    if (!completer.isCompleted) {
      final policy = _activeNavigationPolicy;
      if (policy == null || !policy.accepts(uri)) {
        completer.completeError(
          BrowserTransportException(
            'Browser form navigated to an unexpected destination: $uri',
          ),
        );
        return NavigationActionPolicy.CANCEL;
      }
      completer.complete(
        BrowserTransportResponse(
          statusCode: 302,
          body: Uint8List(0),
          finalUri: uri,
          headers: {
            'location': [uri.toString()],
          },
        ),
      );
    }
    return NavigationActionPolicy.CANCEL;
  }

  void _markReadyAfterCancelledNavigation() {
    if (_readinessState == _ReadinessState.closed) return;
    _documentGeneration++;
    _loadFinished = true;
    _readinessState = _ReadinessState.ready;
    requiresInteraction = false;
    if (!_ready.isCompleted) _ready.complete();
    onChanged();
  }

  Future<BrowserTransportResponse> _fetchRequest(
    BrowserTransportRequest request, {
    Future<void>? cancelFuture,
  }) async {
    var cancelled = false;
    if (cancelFuture != null) {
      unawaited(cancelFuture.then((_) => cancelled = true));
    }
    while (true) {
      await _waitUntilReady(request.readyTimeout, cancelFuture: cancelFuture);
      await _ensureSessionOrigin(request.readyTimeout);
      if (cancelled) {
        throw const BrowserTransportException('Request cancelled.');
      }
      try {
        return await _operationLock.shared(() {
          if (cancelled) {
            throw const BrowserTransportException('Request cancelled.');
          }
          if (_readinessState != _ReadinessState.ready) {
            throw const _DocumentChanged();
          }
          return _fetch(request, cancelFuture: cancelFuture);
        });
      } on _DocumentChanged {
        continue;
      }
    }
  }

  Future<void> _waitUntilReady(Duration timeout, {Future<void>? cancelFuture}) {
    final ready = _ready.future.timeout(
      timeout,
      onTimeout: () => throw const BrowserTransportException(
        'Browser session did not become ready.',
      ),
    );
    if (cancelFuture == null) return ready;
    return Future.any<void>([
      ready,
      cancelFuture.then<void>(
        (_) => throw const BrowserTransportException('Request cancelled.'),
      ),
    ]);
  }

  Future<BrowserTransportResponse> _fetch(
    BrowserTransportRequest request, {
    Future<void>? cancelFuture,
  }) async {
    final controller = _controller;
    if (controller == null) {
      throw const BrowserTransportException('Browser session is not mounted.');
    }
    final id = nextRequestId();
    final completer = Completer<BrowserTransportResponse>();
    _pending[id] = completer;
    if (cancelFuture != null) {
      unawaited(cancelFuture.then((_) => _cancel(id)));
    }

    final payload = jsonEncode({
      'id': id,
      'url': request.uri.toString(),
      'method': request.method,
      'headers': request.headers,
      'body': request.body == null ? null : base64Encode(request.body!),
      'referrer': request.referrer?.toString(),
    });
    try {
      await controller.evaluateJavascript(source: _fetchScript(payload));
    } catch (error) {
      _pending.remove(id);
      throw BrowserTransportException(
        'Could not start browser request: $error',
      );
    }
    return completer.future.timeout(
      request.timeout,
      onTimeout: () async {
        await _cancel(id);
        throw BrowserTransportException(
          'Browser request timed out: ${request.uri}',
        );
      },
    );
  }

  Future<void> _ensureSessionOrigin(Duration timeout) async {
    final controller = _controller;
    if (controller == null) return;
    final current = await controller.getUrl();
    if (current?.host.toLowerCase() == host) return;

    await _runExclusiveNavigation(() async {
      final latest = await controller.getUrl();
      if (latest?.host.toLowerCase() == host) return;
      _startReadinessEpoch();
      _log.infoWithMetadata(
        'Restoring browser session origin',
        metadata: {'host': host, 'currentHost': latest?.host},
      );
      await controller.loadUrl(
        urlRequest: URLRequest(url: WebUri(bootstrapUri.toString())),
      );
      await _ready.future.timeout(timeout);
    });
  }

  String _fetchScript(String payload) =>
      '''
    (() => {
      const request = $payload;
      const headers = request.headers || {};
      let body;
      if (request.body !== null) {
        const binary = atob(request.body);
        body = Uint8Array.from(binary, c => c.charCodeAt(0));
      }
      const controller = new AbortController();
      window.__senpwaiAbortControllers ??= new Map();
      window.__senpwaiAbortControllers.set(request.id, controller);
      fetch(request.url, {
        method: request.method,
        headers,
        body,
        credentials: 'include',
        cache: 'no-store',
        redirect: 'follow',
        referrer: request.referrer || undefined,
        signal: controller.signal,
      }).then(async response => {
        const bytes = new Uint8Array(await response.arrayBuffer());
        let binary = '';
        const chunkSize = 0x8000;
        for (let offset = 0; offset < bytes.length; offset += chunkSize) {
          binary += String.fromCharCode(
            ...bytes.subarray(offset, offset + chunkSize),
          );
        }
        await window.flutter_inappwebview.callHandler(
          '$_handlerName',
          {
            id: request.id,
            status: response.status,
            url: response.url,
            headers: Object.fromEntries(response.headers.entries()),
            body: btoa(binary),
          },
        );
      }).catch(async error => {
        await window.flutter_inappwebview.callHandler(
          '$_handlerName',
          {id: request.id, error: String(error)},
        );
      }).finally(() => {
        window.__senpwaiAbortControllers.delete(request.id);
      });
    })();
  ''';

  void _completeJavaScriptResponse(Map<String, dynamic> data) {
    final id = data['id'] as int?;
    if (id == null) return;
    final completer = _pending[id];
    if (completer == null || completer.isCompleted) return;
    final error = data['error'] as String?;
    if (error != null) {
      _pending.remove(id);
      completer.completeError(BrowserTransportException(error));
      return;
    }
    try {
      final rawHeaders = data['headers'] as Map? ?? const {};
      final response = BrowserTransportResponse(
        statusCode: data['status'] as int? ?? 0,
        body: base64Decode(data['body'] as String? ?? ''),
        finalUri: Uri.tryParse(data['url'] as String? ?? '') ?? origin,
        headers: {
          for (final entry in rawHeaders.entries)
            entry.key.toString().toLowerCase(): [entry.value.toString()],
        },
      );
      _pending.remove(id);
      completer.complete(response);
    } catch (error, stackTrace) {
      _pending.remove(id);
      completer.completeError(
        BrowserTransportException('Could not decode browser response: $error'),
        stackTrace,
      );
    }
  }

  Future<void> _cancel(int id) async {
    final completer = _pending.remove(id);
    if (completer != null && !completer.isCompleted) {
      completer.completeError(
        const BrowserTransportException('Request cancelled.'),
      );
    }
    try {
      await _controller?.evaluateJavascript(
        source: 'window.__senpwaiAbortControllers?.get($id)?.abort();',
      );
    } catch (error) {
      _log.fineWithMetadata(
        'Could not abort browser request',
        metadata: {'host': host, 'requestId': id, 'error': error.toString()},
      );
    }
  }

  Future<void> _recover(Uri challengedUri, Duration timeout) async {
    final controller = _controller;
    if (controller == null) {
      throw const BrowserTransportException('Browser session is not mounted.');
    }
    _startReadinessEpoch(requiresUserInteraction: true);
    _log.infoWithMetadata(
      'Opening browser challenge',
      metadata: {'host': host, 'url': challengedUri.toString()},
    );
    await controller.loadUrl(
      urlRequest: URLRequest(url: WebUri(challengedUri.toString())),
    );
    await _ready.future.timeout(timeout);
  }

  Future<void> reset() async {
    _failPending('Browser session was reset.');
    if (!_ready.isCompleted) {
      _ready.completeError(
        const BrowserTransportException('Browser session was reset.'),
      );
    }
    await _runExclusiveNavigation(() async {
      final controller = _controller;
      if (controller == null) return;
      _startReadinessEpoch();
      await controller.stopLoading();
      await controller.loadUrl(
        urlRequest: URLRequest(url: WebUri(bootstrapUri.toString())),
      );
    });
  }

  Future<void> close({String reason = 'Browser session was closed.'}) async {
    _readinessState = _ReadinessState.closed;
    _documentGeneration++;
    _failPending(reason);
    if (!_ready.isCompleted) {
      _ready.completeError(BrowserTransportException(reason));
    }
    final controller = _controller;
    requiresInteraction = false;
    if (controller != null) await _stopNavigation(controller);
    if (identical(_controller, controller)) _controller = null;
  }

  void _startReadinessEpoch({bool requiresUserInteraction = false}) {
    if (_readinessState == _ReadinessState.closed) return;
    if (!_ready.isCompleted) {
      _ready.completeError(
        const BrowserTransportException('Browser document was replaced.'),
      );
    }
    _ready = Completer<void>();
    _readinessState = _ReadinessState.loading;
    _loadFinished = false;
    requiresInteraction = requiresUserInteraction;
    onChanged();
  }

  Future<void> _stopNavigation(InAppWebViewController controller) async {
    _navigationStopCount++;
    _expectedNavigationAbortUrl = null;
    try {
      await controller.stopLoading();
    } catch (error) {
      _log.fineWithMetadata(
        'Browser navigation was already stopped',
        metadata: {'host': host, 'error': error.toString()},
      );
    } finally {
      _navigationStopCount--;
    }
  }

  void _failPending(String message) {
    final error = BrowserTransportException(message);
    _failPendingFetches(message);
    final formSubmission = _pendingFormSubmission;
    if (formSubmission != null && !formSubmission.isCompleted) {
      formSubmission.completeError(error);
    }
    _pendingFormSubmission = null;
  }

  void _failPendingFetches(String message) {
    if (_pending.isEmpty) return;
    final error = BrowserTransportException(message);
    for (final completer in _pending.values) {
      if (!completer.isCompleted) completer.completeError(error);
    }
    _pending.clear();
  }

  bool _isChallengeResponse(BrowserTransportResponse response) {
    final mitigated = response.headers['cf-mitigated']?.join(',').toLowerCase();
    if (mitigated == 'challenge') return true;
    final html = utf8.decode(response.body, allowMalformed: true);
    if (_hasInteractiveCloudflareChallenge(html)) return true;

    // Cloudflare's non-interactive block pages do not consistently include
    // challenge DOM markers. Restrict their title-based signature to an HTTP
    // error response so a site's own interstitial cannot be mistaken for a
    // challenge merely because it displays the blocked destination's title.
    if (response.statusCode < 400) return false;
    final lower = html.toLowerCase();
    final title = _documentTitle(html);
    return (title?.contains('attention required') ?? false) &&
        (lower.contains('cloudflare') || lower.contains('captcha'));
  }

  bool _documentLooksChallenged(String html) {
    return _hasInteractiveCloudflareChallenge(html);
  }

  bool _hasInteractiveCloudflareChallenge(String html) {
    final lower = html.toLowerCase();
    return _activeDocumentChallengeMarkers.any(lower.contains);
  }

  String? _documentTitle(String html) => RegExp(
    r'<title[^>]*>(.*?)</title>',
    caseSensitive: false,
    dotAll: true,
  ).firstMatch(html)?.group(1)?.toLowerCase();

  BrowserNavigationPolicy? _activeNavigationPolicy;

  Future<T> _runExclusiveNavigation<T>(Future<T> Function() operation) async {
    return _operationLock.exclusive(() async {
      try {
        return await operation();
      } finally {
        _activeNavigationPolicy = null;
      }
    });
  }
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
