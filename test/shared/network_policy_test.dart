import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:senpwai/shared/net/browser_transport/routing.dart';
import 'package:senpwai/shared/net/interceptors/rate_limit.dart';
import 'package:senpwai/shared/net/request_cancellation_scope.dart';

void main() {
  group('BrowserRoutingPolicy', () {
    test('normalizes configured hosts and exposes an immutable view', () {
      final policy = BrowserRoutingPolicy()
        ..replaceBrowserOrigins({
          'Source.EXAMPLE': Uri.parse('https://source.example'),
        });

      expect(policy.browserOriginFor('SOURCE.example')?.host, 'source.example');
      expect(policy.browserHosts, {'source.example'});
      expect(
        () => policy.browserHosts.add('other.example'),
        throwsUnsupportedError,
      );
    });

    test('uses configured origins only for automatic requests', () {
      final policy = BrowserRoutingPolicy()
        ..replaceBrowserOrigins({
          'source.example': Uri.parse('https://source.example'),
        });

      expect(
        policy.useBrowser(_request('https://source.example/show')),
        isTrue,
      );
      expect(
        policy.useBrowser(_request('https://other.example/show')),
        isFalse,
      );
      expect(
        policy.useBrowser(
          _request(
            'https://source.example/show',
            preference: TransportPreference.native,
          ),
        ),
        isFalse,
      );
      expect(
        policy.useBrowser(
          _request(
            'https://other.example/show',
            preference: TransportPreference.browser,
          ),
        ),
        isTrue,
      );
    });

    test('replacing origins removes stale routing decisions', () {
      final policy = BrowserRoutingPolicy()
        ..replaceBrowserOrigins({
          'old.example': Uri.parse('https://old.example'),
        })
        ..replaceBrowserOrigins({
          'new.example': Uri.parse('https://new.example'),
        });

      expect(policy.useBrowser(_request('https://old.example')), isFalse);
      expect(policy.useBrowser(_request('https://new.example')), isTrue);
    });
  });

  group('Cloudflare 1015 detection', () {
    test('detects the response header', () {
      expect(
        isCloudflare1015Response(
          _response(
            headers: {
              'cf-error-type': ['1015'],
            },
          ),
        ),
        isTrue,
      );
    });

    test('detects structured and HTML response bodies', () {
      expect(
        isCloudflare1015Response(_response(data: {'error_code': 1015})),
        isTrue,
      );
      expect(
        isCloudflare1015Response(
          _response(data: '<span class="cf-error-code">Error 1015</span>'),
        ),
        isTrue,
      );
      expect(
        isCloudflare1015Response(
          _response(data: '<div cf-error-code="1015"></div>'),
        ),
        isTrue,
      );
    });

    test('does not misclassify unrelated errors', () {
      expect(
        isCloudflare1015Response(_response(data: 'Error 1020: denied')),
        isFalse,
      );
      expect(isCloudflare1015Response(_response(data: null)), isFalse);
    });
  });

  group('request cancellation scope', () {
    test('throws only inside a cancelled request scope', () async {
      throwIfRequestScopeCancelled();
      final token = CancelToken()..cancel('leaving page');

      await expectLater(
        runWithRequestCancelToken(token, () async {
          throwIfRequestScopeCancelled();
          return 1;
        }),
        throwsA(isA<RequestScopeCancelled>()),
      );
    });

    test(
      'inherits the scoped token without replacing an explicit token',
      () async {
        final scoped = CancelToken();
        final explicit = CancelToken();
        const interceptor = ScopedCancelTokenInterceptor();

        await runWithRequestCancelToken(scoped, () async {
          final inherited = RequestOptions(path: 'https://source.example');
          final inheritedHandler = RequestInterceptorHandler();
          interceptor.onRequest(inherited, inheritedHandler);
          expect(inherited.cancelToken, same(scoped));

          final provided = RequestOptions(
            path: 'https://source.example',
            cancelToken: explicit,
          );
          final providedHandler = RequestInterceptorHandler();
          interceptor.onRequest(provided, providedHandler);
          expect(provided.cancelToken, same(explicit));
        });
      },
    );
  });
}

RequestOptions _request(String url, {TransportPreference? preference}) =>
    RequestOptions(
      path: url,
      extra: {if (preference != null) transportPreferenceExtraKey: preference},
    );

Response<dynamic> _response({
  Object? data,
  Map<String, List<String>> headers = const {},
}) => Response<dynamic>(
  requestOptions: RequestOptions(path: 'https://source.example'),
  data: data,
  headers: Headers.fromMap(headers),
);
