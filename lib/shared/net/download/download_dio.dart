import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:pretty_dio_logger/pretty_dio_logger.dart';
import 'package:senpwai/shared/net/http_transport.dart';
import 'package:senpwai/shared/net/http2_preferred_adapter.dart';
import 'package:senpwai/shared/net/interceptors/connectivity.dart';

Dio createDownloadDio({required String userAgent}) {
  final dio = Dio();
  HttpTransportConfig(userAgent: userAgent).attachToDio(dio);
  preferHttp2(dio);
  dio.interceptors.add(ConnectivityInterceptor(dio));
  dio.interceptors.add(
    PrettyDioLogger(
      enabled: kDebugMode,
      requestHeader: false,
      responseBody: false,
    ),
  );
  return dio;
}
