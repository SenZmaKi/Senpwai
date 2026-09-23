import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:senpwai/shared/net/browser_transport/routing.dart';

const skipCookieManagerExtraKey = 'skipCookieManager';
const _browserOwnsCookiesExtraKey = 'browserOwnsCookies';

class AppCookieManager extends CookieManager {
  final BrowserRoutingPolicy routingPolicy;

  AppCookieManager(super.cookieJar, {required this.routingPolicy});

  bool _shouldSkip(RequestOptions options) =>
      options.extra[skipCookieManagerExtraKey] == true ||
      options.extra[_browserOwnsCookiesExtraKey] == true ||
      routingPolicy.useBrowser(options);

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (_shouldSkip(options)) {
      if (routingPolicy.useBrowser(options)) {
        options.extra[_browserOwnsCookiesExtraKey] = true;
      }
      handler.next(options);
      return;
    }
    await super.onRequest(options, handler);
  }

  @override
  Future<void> onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) async {
    if (_shouldSkip(response.requestOptions)) {
      handler.next(response);
      return;
    }
    await super.onResponse(response, handler);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    if (_shouldSkip(err.requestOptions)) {
      handler.next(err);
      return;
    }
    await super.onError(err, handler);
  }
}
