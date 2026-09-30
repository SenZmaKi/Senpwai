import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:senpwai/shared/net/browser_transport/browser_transport.dart';
import 'package:senpwai/shared/net/browser_transport/routing.dart';

class BrowserHttpClientAdapter implements HttpClientAdapter {
  static const _browserOwnedHeaders = {
    'connection',
    'content-length',
    'cookie',
    'host',
    'origin',
    'referer',
    'user-agent',
  };

  final BrowserTransportService transport;
  final BrowserRoutingPolicy routingPolicy;

  const BrowserHttpClientAdapter(this.transport, {required this.routingPolicy});

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final executionMode =
        options.extra[browserExecutionModeExtraKey] as BrowserExecutionMode? ??
        BrowserExecutionMode.fetch;
    if (!options.followRedirects &&
        executionMode == BrowserExecutionMode.fetch) {
      throw UnsupportedError(
        'Browser fetch cannot expose manual redirects. Use a browser '
        'navigation mode or the native transport.',
      );
    }
    if (executionMode == BrowserExecutionMode.submitForm &&
        options.method.toUpperCase() != 'POST') {
      throw UnsupportedError(
        'Browser form submission only supports POST requests.',
      );
    }
    if (executionMode == BrowserExecutionMode.navigate &&
        options.method.toUpperCase() != 'GET') {
      throw UnsupportedError('Browser navigation only supports GET requests.');
    }
    final body = requestStream == null
        ? null
        : await _withOptionalTimeout(
            _collect(requestStream),
            options.sendTimeout,
            'Browser request body timed out.',
          );
    final response = await transport.send(
      BrowserTransportRequest(
        uri: options.uri,
        bootstrapUri:
            routingPolicy.browserOriginFor(options.uri.host) ??
            options.uri.replace(path: '/', query: null, fragment: null),
        method: options.method,
        headers: _browserHeaders(options.headers),
        executionMode: executionMode,
        navigationPolicy:
            options.extra[browserNavigationPolicyExtraKey]
                as BrowserNavigationPolicy?,
        onUserCancel: options.cancelToken == null
            ? null
            : () {
                if (!options.cancelToken!.isCancelled) {
                  options.cancelToken!.cancel(
                    'Browser verification closed by the user.',
                  );
                }
              },
        referrer: _headerUri(options.headers, 'referer'),
        body: body,
        readyTimeout: _effectiveTimeout(options.connectTimeout),
        timeout: _effectiveTimeout(options.receiveTimeout),
      ),
      cancelFuture: cancelFuture,
    );
    final wasRedirected = response.finalUri != options.uri;
    return ResponseBody(
      Stream.value(response.body),
      response.statusCode,
      headers: response.headers,
      isRedirect: wasRedirected,
      redirects: wasRedirected
          ? [RedirectRecord(302, options.method, response.finalUri)]
          : const [],
    );
  }

  Future<T> _withOptionalTimeout<T>(
    Future<T> future,
    Duration? timeout,
    String message,
  ) {
    if (timeout == null || timeout == Duration.zero) return future;
    return future.timeout(
      timeout,
      onTimeout: () => throw TimeoutException(message),
    );
  }

  Duration _effectiveTimeout(Duration? configured) =>
      configured == null || configured == Duration.zero
      ? const Duration(minutes: 2)
      : configured;

  Map<String, String> _browserHeaders(Map<String, dynamic> source) => {
    for (final entry in source.entries)
      if (!_isBrowserOwnedHeader(entry.key))
        entry.key: entry.value is Iterable
            ? (entry.value as Iterable).join(', ')
            : entry.value.toString(),
  };

  bool _isBrowserOwnedHeader(String name) {
    final lower = name.toLowerCase();
    return _browserOwnedHeaders.contains(lower) ||
        lower.startsWith('sec-') ||
        lower.startsWith('proxy-');
  }

  Uri? _headerUri(Map<String, dynamic> headers, String name) {
    for (final entry in headers.entries) {
      if (entry.key.toLowerCase() == name) {
        return Uri.tryParse(entry.value.toString());
      }
    }
    return null;
  }

  Future<Uint8List> _collect(Stream<Uint8List> stream) async {
    final builder = BytesBuilder(copy: false);
    await for (final chunk in stream) {
      builder.add(chunk);
    }
    return builder.takeBytes();
  }

  @override
  void close({bool force = false}) {}
}
