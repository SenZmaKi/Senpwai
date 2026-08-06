import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';

const skipCookieManagerExtraKey = 'skipCookieManager';

class AppCookieManager extends CookieManager {
  AppCookieManager(super.cookieJar);

  bool _shouldSkip(RequestOptions options) =>
      options.extra[skipCookieManagerExtraKey] == true;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (_shouldSkip(options)) {
      handler.next(options);
      return;
    }
    await super.onRequest(options, handler);
  }
}
