import 'package:flutter_test/flutter_test.dart';
import 'package:senpwai/shared/log.dart';
import 'package:senpwai/shared/net/net.dart';
import 'package:senpwai/shared/net/net_config.dart';

import 'support/support.dart';

const testUrl = "https://example.com";

void main() {
  setUpAll(() {
    setupLogger();
  });
  test("cache fetches faster", () async {
    final dio = GlobalDio.getInstance();
    final uncached = await timeIt(
      label: "Fetching example.com (uncached)",
      fn: () => dio.get(testUrl),
    );
    final cached = await timeIt(
      label: "Fetching example.com (cached)",
      fn: () => dio.get(testUrl),
    );
    expect(cached.inMilliseconds, lessThan(uncached.inMilliseconds));
    NetConfig.getInstance().logCache();
  });

  test("fetch example.com", () async {
    final response = await GlobalDio.getInstance().get(testUrl);
    expect(response.statusCode, 200);
  });
}
