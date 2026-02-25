import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:pretty_dio_logger/pretty_dio_logger.dart';
import 'package:senpwai/shared/net/interceptors/rate_limit.dart';
import 'package:senpwai/shared/net/net_config.dart';

class GlobalDio {
  GlobalDio._();

  static Dio? _instance;

  static Dio getInstance() {
    if (_instance != null) {
      return _instance!;
    }

    _instance = Dio();
    _instance!.interceptors.add(RateLimitInterceptor(_instance!));
    _instance!.interceptors.add(
      PrettyDioLogger(
        enabled: kDebugMode,
        requestHeader: true,
        responseBody: false,
      ),
    );
    NetConfig.getInstance().attachToDio(_instance!);
    return _instance!;
  }
}
