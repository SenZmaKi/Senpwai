import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:senpwai/settings/settings.dart';
import 'package:senpwai/shared/net/download/download_config.dart';
import 'package:senpwai/sources/shared/shared.dart';

import '../support/support.dart';

void main() {
  setUpAll(() async {
    await setupTestApp();
  });

  test('updates and persists focused settings', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(AppSettingsNotifier.provider.notifier);

    await notifier.setDefaultResolution(Resolution.res720p);
    await notifier.setHttpMaxDownloadBytesPerSecond(1024);

    final settings = container.read(AppSettingsNotifier.provider);
    expect(settings.content.defaultResolution, Resolution.res720p);
    expect(settings.downloads.maxDownloadBytesPerSecond, 1024);
    expect(DownloadConfig.getInstance().maxBytesPerSecond, 1024);
  });
}
