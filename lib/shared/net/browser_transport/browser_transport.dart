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
  int _nextRequestId = 0;

  List<BrowserHostSession> get sessions => List.unmodifiable(_sessions.values);
  BrowserHostSession? get visibleSession => _sessions.values
      .where((session) => session.requiresInteraction)
      .firstOrNull;

  Future<BrowserTransportResponse> send(
    BrowserTransportRequest request, {
    Future<void>? cancelFuture,
  }) {
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
        onChanged: notifyListeners,
        nextRequestId: () => _nextRequestId++,
      ),
    );
    notifyListeners();
    return session.send(request, cancelFuture: cancelFuture);
  }

  Future<void> clearSessions() async {
    await CookieManager.instance().deleteAllCookies();
    await InAppWebViewController.clearAllCache();
    await Future.wait(_sessions.values.map((session) => session.reset()));
  }

  void retainHosts(Iterable<String> hosts) {
    final retained = hosts.map((host) => host.toLowerCase()).toSet();
    final removed = _sessions.keys
        .where((host) => !retained.contains(host))
        .toList();
    for (final host in removed) {
      final session = _sessions.remove(host);
      if (session != null) unawaited(session.close());
    }
    if (removed.isNotEmpty) notifyListeners();
  }
}

class BrowserHostSession {
  static const _handlerName = 'senpwaiBrowserTransportResponse';
  static const _responseChallengeMarkers = <String>[
    '<title>just a moment...</title>',
    'window._cf_chl_opt',
    'id="challenge-error-text"',
    'cf-chl-widget-',
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
    final controller = _controller;
    if (controller == null) return;
    try {
      final html = (await controller.evaluateJavascript(
        source: 'document.documentElement?.outerHTML ?? ""',
      ))?.toString();
      final title = (await controller.evaluateJavascript(
        source: 'document.title ?? ""',
      ))?.toString();
      final challenged = _documentLooksChallenged(html ?? '', title ?? '');
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
        cancelFuture.then((_) {
          if (!completer.isCompleted) {
            completer.completeError(
              const BrowserTransportException('Request cancelled.'),
            );
            unawaited(_controller?.stopLoading());
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
      await controller.evaluateJavascript(
        source: _formSubmissionScript(payload),
      );
      return await completer.future.timeout(
        request.timeout,
        onTimeout: () {
          unawaited(_controller?.stopLoading());
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
    _controller = null;
    requiresInteraction = false;
    await controller?.stopLoading();
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
    return mitigated == 'challenge' ||
        ((response.statusCode == 403 || response.statusCode == 503) &&
            _hasResponseChallengeMarker(
              utf8.decode(response.body, allowMalformed: true),
            ));
  }

  bool _documentLooksChallenged(String html, String title) {
    final normalizedTitle = title
        .replaceAll(RegExp(r'^"|"$'), '')
        .toLowerCase();
    if (!normalizedTitle.contains('just a moment')) return false;
    return _hasResponseChallengeMarker(html);
  }

  bool _hasResponseChallengeMarker(String value) {
    final lower = value.toLowerCase();
    return _responseChallengeMarkers.any(lower.contains);
  }

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
