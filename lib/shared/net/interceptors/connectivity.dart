import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:logging/logging.dart';
import 'package:senpwai/shared/log.dart';
import 'package:senpwai/shared/net/connectivity.dart';

final _log = Logger("senpwai.net.interceptors.connectivity");

const skipConnectivityErrorTypesExtraKey = 'skipConnectivityErrorTypes';
const _connectivityReplayExtraKey = 'connectivityReplay';

typedef OfflineNetworkErrorCallback = void Function(DioException error);

class ConnectivityInterceptor extends Interceptor {
  static const _notificationDebounce = Duration(seconds: 15);
  static const _onlineRetryInterval = Duration(seconds: 3);

  final Dio dio;
  OfflineNetworkErrorCallback? _onOfflineNetworkError;
  Future<void>? _onlineWait;
  DateTime? _lastNotificationAt;
  bool _offlineNotificationInProgress = false;

  ConnectivityInterceptor(this.dio);

  void setOfflineNetworkErrorCallback(OfflineNetworkErrorCallback? callback) {
    _onOfflineNetworkError = callback;
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    if (!_shouldHandle(err)) {
      handler.next(err);
      return;
    }

    final isOnline = await hasValidInternetConnection();
    if (isOnline) {
      handler.next(err);
      return;
    }

    _notifyOffline(err);
    try {
      await _waitUntilOnline();
      final response = await dio.fetch<dynamic>(_retryOptions(err));
      handler.resolve(response);
    } on DioException catch (retryErr) {
      handler.next(retryErr);
    } on Object catch (error, stack) {
      handler.next(
        DioException(
          requestOptions: err.requestOptions,
          type: DioExceptionType.unknown,
          error: error,
          stackTrace: stack,
        ),
      );
    }
  }

  bool _shouldHandle(DioException err) {
    if (_skippedErrorTypes(err.requestOptions).contains(err.type)) {
      return false;
    }
    if (err.requestOptions.extra[_connectivityReplayExtraKey] == true) {
      return false;
    }
    if (err.type == DioExceptionType.cancel || err.response != null) {
      return false;
    }
    return err.type == DioExceptionType.connectionError ||
        err.type == DioExceptionType.connectionTimeout ||
        err.type == DioExceptionType.sendTimeout ||
        err.type == DioExceptionType.receiveTimeout ||
        _isHostLookupError(err.error) ||
        _isHostLookupError(err.message);
  }

  Set<DioExceptionType> _skippedErrorTypes(RequestOptions options) {
    final raw = options.extra[skipConnectivityErrorTypesExtraKey];
    if (raw is Iterable<DioExceptionType>) {
      return raw.toSet();
    }
    return const {};
  }

  void _notifyOffline(DioException err) {
    if (_onOfflineNetworkError == null ||
        _offlineNotificationInProgress ||
        !_canNotify()) {
      return;
    }

    _offlineNotificationInProgress = true;
    _lastNotificationAt = DateTime.now();
    try {
      _log.warningWithMetadata(
        "Dio request queued while offline",
        metadata: {
          "url": err.requestOptions.uri.toString(),
          "type": err.type.name,
          "error": err.error?.toString(),
        },
      );
      _onOfflineNetworkError?.call(err);
    } finally {
      _offlineNotificationInProgress = false;
    }
  }

  Future<void> _waitUntilOnline() {
    return _onlineWait ??= _pollUntilOnline().whenComplete(() {
      _onlineWait = null;
    });
  }

  Future<void> _pollUntilOnline() async {
    while (!await hasValidInternetConnection()) {
      await Future<void>.delayed(_onlineRetryInterval);
    }
  }

  RequestOptions _retryOptions(DioException err) {
    final requestOptions = err.requestOptions;
    return requestOptions.copyWith(
      extra: {...requestOptions.extra, _connectivityReplayExtraKey: true},
    );
  }

  bool _canNotify() {
    final lastNotificationAt = _lastNotificationAt;
    if (lastNotificationAt == null) return true;
    return DateTime.now().difference(lastNotificationAt) >=
        _notificationDebounce;
  }

  bool _isHostLookupError(Object? error) {
    if (error is SocketException) return true;
    final text = error?.toString().toLowerCase();
    if (text == null) return false;
    return text.contains('failed host lookup') ||
        text.contains('nodename nor servname provided') ||
        text.contains('name or service not known');
  }
}
