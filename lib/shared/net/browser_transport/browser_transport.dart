import 'dart:async';
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

class BrowserTransportService extends ChangeNotifier {
  BrowserTransportService._();

  static final instance = BrowserTransportService._();

  final Map<String, BrowserHostSession> _sessions = {};
  final Map<String, Timer> _idleTimers = {};
  final Map<String, int> _activeRequests = {};
  final Map<String, Set<VoidCallback>> _userCancellationCallbacks = {};
  Duration _idleTimeout = const Duration(minutes: 10);
  int _nextRequestId = 0;

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

  void cancelSessionRequests(String host) {
    final callbacks = _userCancellationCallbacks[host.toLowerCase()]?.toList();
    if (callbacks == null || callbacks.isEmpty) return;
    for (final cancel in callbacks) {
      cancel();
    }
  }

  Future<void> clearSessions() async {
    await CookieManager.instance().deleteAllCookies();
    // flutter_inappwebview_windows exposes clearAllCache in Dart but does not
    // register the manager-channel method in its native implementation.
    if (defaultTargetPlatform != TargetPlatform.windows) {
      await InAppWebViewController.clearAllCache();
    }
    await Future.wait(_sessions.values.map((session) => session.reset()));
  }

  void retainHosts(Iterable<String> hosts) {
    final retained = hosts.map((host) => host.toLowerCase()).toSet();
    final removed = _sessions.keys
        .where((host) => !retained.contains(host))
        .toList();
    for (final host in removed) {
      _idleTimers.remove(host)?.cancel();
      _activeRequests.remove(host);
      _userCancellationCallbacks.remove(host);
      final session = _sessions.remove(host);
      if (session != null) unawaited(session.close());
    }
    if (removed.isNotEmpty) notifyListeners();
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
  Future<void>? _recovery;
  Future<void> _navigationTail = Future.value();
  String? _expectedNavigationAbortUrl;
  int _navigationStopCount = 0;
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

  Future<void> pageFinished() => _inspectDocument(completeReady: true);

  Future<void> pageTitleChanged() => _inspectDocument(completeReady: false);

  Future<void> _inspectDocument({required bool completeReady}) async {
    if (_navigationStopCount > 0) return;
    final controller = _controller;
    if (controller == null) return;
    try {
      final html = (await controller.evaluateJavascript(
        source: 'document.documentElement?.outerHTML ?? ""',
      ))?.toString();
      final challenged = _documentLooksChallenged(html ?? '');
      requiresInteraction = challenged;
      _log.infoWithMetadata(
        challenged ? 'Browser challenge page loaded' : 'Browser session ready',
        metadata: {'host': host},
      );
      if (completeReady && !challenged && !_ready.isCompleted) {
        _ready.complete();
      }
      onChanged();
    } catch (error) {
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

  void pageFailed(Object error) {
    _log.warningWithMetadata(
      'Browser session failed to load',
      metadata: {'host': host, 'error': error.toString()},
    );
    if (!_ready.isCompleted) {
      _ready.completeError(BrowserTransportException(error.toString()));
    }
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
    await _ready.future.timeout(
      request.readyTimeout,
      onTimeout: () => throw const BrowserTransportException(
        'Browser session did not become ready.',
      ),
    );
    if (request.executionMode == BrowserExecutionMode.submitForm) {
      return _runExclusiveNavigation(
        () => _submitForm(request, cancelFuture: cancelFuture),
      );
    }
    if (request.executionMode == BrowserExecutionMode.navigate) {
      return _runExclusiveNavigation(
        () => _navigate(request, cancelFuture: cancelFuture),
      );
    }
    BrowserTransportResponse response;
    try {
      response = await _fetch(request, cancelFuture: cancelFuture);
    } catch (_) {
      if (cancelled) rethrow;
      final recovery = _recovery;
      if (recovery == null) rethrow;
      await recovery;
      return _fetchAfterRecovery(request, cancelFuture: cancelFuture);
    }
    if (!_isChallengeResponse(response)) return response;

    await (_recovery ??= _recover(
      request.uri,
      request.readyTimeout,
    ).whenComplete(() => _recovery = null));
    return _fetchAfterRecovery(request, cancelFuture: cancelFuture);
  }

  Future<BrowserTransportResponse> _fetchAfterRecovery(
    BrowserTransportRequest request, {
    Future<void>? cancelFuture,
  }) async {
    final response = await _fetch(request, cancelFuture: cancelFuture);
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
    _activeNavigationPolicy = navigationPolicy;

    await _ensureDocument(request.referrer, request.readyTimeout);

    final completer = Completer<BrowserTransportResponse>();
    _pendingFormSubmission = completer;
    if (cancelFuture != null) {
      unawaited(
        cancelFuture.then((_) async {
          if (completer.isCompleted) return;
          await _stopNavigation(controller);
          if (!completer.isCompleted) {
            completer.completeError(
              const BrowserTransportException('Request cancelled.'),
            );
          }
        }),
      );
    }

    final payload = jsonEncode({
      'url': request.uri.toString(),
      'contentType': request.headers.entries
          .where((entry) => entry.key.toLowerCase() == 'content-type')
          .map((entry) => entry.value)
          .firstOrNull,
      'body': base64Encode(request.body ?? Uint8List(0)),
    });
    try {
      // Start the script without awaiting it so the response completer has an
      // error listener before cancellation can complete it. Awaiting script
      // evaluation first left a small window where a cancellation error was
      // reported as an unhandled asynchronous exception.
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
      return await completer.future.timeout(
        request.timeout,
        onTimeout: () async {
          await _stopNavigation(controller);
          throw BrowserTransportException(
            'Browser form submission timed out: ${request.uri}',
          );
        },
      );
    } finally {
      if (identical(_pendingFormSubmission, completer)) {
        _pendingFormSubmission = null;
      }
    }
  }

  Future<void> _ensureDocument(Uri? target, Duration timeout) async {
    if (target == null || target.host.toLowerCase() != host) return;
    final controller = _controller;
    if (controller == null) return;
    final current = await controller.getUrl();
    if (current?.toString() == target.toString()) return;

    _ready = Completer<void>();
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

    final navigationReady = Completer<void>();
    _ready = navigationReady;
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

  NavigationActionPolicy handleNavigation(NavigationAction action) {
    final completer = _pendingFormSubmission;
    final uri = action.request.url;
    if (completer == null ||
        uri == null ||
        !action.isForMainFrame ||
        uri.host.toLowerCase() == host) {
      return NavigationActionPolicy.ALLOW;
    }

    _expectedNavigationAbortUrl = uri.toString();
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

  Future<BrowserTransportResponse> _fetch(
    BrowserTransportRequest request, {
    Future<void>? cancelFuture,
  }) async {
    final controller = _controller;
    if (controller == null) {
      throw const BrowserTransportException('Browser session is not mounted.');
    }
    await _ensureSessionOrigin(request.readyTimeout);
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

    _ready = Completer<void>();
    requiresInteraction = false;
    onChanged();
    _log.infoWithMetadata(
      'Restoring browser session origin',
      metadata: {'host': host, 'currentHost': current?.host},
    );
    await controller.loadUrl(
      urlRequest: URLRequest(url: WebUri(bootstrapUri.toString())),
    );
    await _ready.future.timeout(timeout);
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
    final completer = _pending.remove(id);
    if (completer == null || completer.isCompleted) return;
    final error = data['error'] as String?;
    if (error != null) {
      completer.completeError(BrowserTransportException(error));
      return;
    }
    final rawHeaders = data['headers'] as Map? ?? const {};
    completer.complete(
      BrowserTransportResponse(
        statusCode: data['status'] as int? ?? 0,
        body: base64Decode(data['body'] as String? ?? ''),
        finalUri: Uri.tryParse(data['url'] as String? ?? '') ?? origin,
        headers: {
          for (final entry in rawHeaders.entries)
            entry.key.toString().toLowerCase(): [entry.value.toString()],
        },
      ),
    );
  }

  Future<void> _cancel(int id) async {
    final completer = _pending.remove(id);
    if (completer != null && !completer.isCompleted) {
      completer.completeError(
        const BrowserTransportException('Request cancelled.'),
      );
    }
    await _controller?.evaluateJavascript(
      source: 'window.__senpwaiAbortControllers?.get($id)?.abort();',
    );
  }

  Future<void> _recover(Uri challengedUri, Duration timeout) async {
    final controller = _controller;
    if (controller == null) {
      throw const BrowserTransportException('Browser session is not mounted.');
    }
    _ready = Completer<void>();
    requiresInteraction = true;
    onChanged();
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
    final controller = _controller;
    if (controller == null) return;
    _failPending('Browser session was reset.');
    if (!_ready.isCompleted) {
      _ready.completeError(
        const BrowserTransportException('Browser session was reset.'),
      );
    }
    _ready = Completer<void>();
    requiresInteraction = false;
    onChanged();
    await controller.stopLoading();
    await controller.loadUrl(
      urlRequest: URLRequest(url: WebUri(bootstrapUri.toString())),
    );
  }

  Future<void> close() async {
    _failPending('Browser session was closed.');
    if (!_ready.isCompleted) {
      _ready.completeError(
        const BrowserTransportException('Browser session was closed.'),
      );
    }
    final controller = _controller;
    requiresInteraction = false;
    if (controller != null) await _stopNavigation(controller);
    if (identical(_controller, controller)) _controller = null;
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
    for (final completer in _pending.values) {
      if (!completer.isCompleted) completer.completeError(error);
    }
    _pending.clear();
    final formSubmission = _pendingFormSubmission;
    if (formSubmission != null && !formSubmission.isCompleted) {
      formSubmission.completeError(error);
    }
    _pendingFormSubmission = null;
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
    final previous = _navigationTail;
    final released = Completer<void>();
    _navigationTail = released.future;
    await previous.catchError((_) {});
    try {
      return await operation();
    } finally {
      _activeNavigationPolicy = null;
      if (!released.isCompleted) released.complete();
    }
  }
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
