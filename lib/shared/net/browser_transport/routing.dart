import 'package:dio/dio.dart';

const transportPreferenceExtraKey = 'transportPreference';
const browserExecutionModeExtraKey = 'browserExecutionMode';
const browserNavigationPolicyExtraKey = 'browserNavigationPolicy';

enum TransportPreference { automatic, native, browser }

enum BrowserExecutionMode { fetch, submitForm }

class BrowserNavigationPolicy {
  final bool Function(Uri uri) accepts;

  const BrowserNavigationPolicy({required this.accepts});
}

class BrowserRoutingPolicy {
  final Map<String, Uri> _browserOrigins = {};

  Set<String> get browserHosts => Set.unmodifiable(_browserOrigins.keys);

  void replaceBrowserOrigins(Map<String, Uri> origins) {
    _browserOrigins
      ..clear()
      ..addEntries(
        origins.entries.map(
          (entry) => MapEntry(entry.key.toLowerCase(), entry.value),
        ),
      );
  }

  Uri? browserOriginFor(String host) => _browserOrigins[host.toLowerCase()];

  bool useBrowser(RequestOptions options) {
    final preference =
        options.extra[transportPreferenceExtraKey] as TransportPreference?;
    return switch (preference) {
      TransportPreference.browser => true,
      TransportPreference.native => false,
      TransportPreference.automatic ||
      null => _browserOrigins.containsKey(options.uri.host.toLowerCase()),
    };
  }
}
