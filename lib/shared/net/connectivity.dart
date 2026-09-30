import 'dart:async';
import 'dart:io';

const _connectivityProbeTimeout = Duration(seconds: 3);
const _dnsProbeHost = 'cloudflare.com';
const _httpProbeUris = [
  'https://www.gstatic.com/generate_204',
  'https://www.google.com/generate_204',
];

/// Returns true when the device appears to have usable internet access.
///
/// DNS alone can pass on captive or broken networks, so this follows it with
/// short HTTP probes and accepts any response as evidence of connectivity.
Future<bool> hasValidInternetConnection({
  Duration timeout = _connectivityProbeTimeout,
}) async {
  try {
    final addresses = await InternetAddress.lookup(
      _dnsProbeHost,
    ).timeout(timeout);
    if (addresses.isEmpty) return false;
  } on Object catch (_) {
    return false;
  }

  for (final uriText in _httpProbeUris) {
    if (await _canReach(Uri.parse(uriText), timeout)) {
      return true;
    }
  }

  return false;
}

Future<bool> _canReach(Uri uri, Duration timeout) async {
  final client = HttpClient()..connectionTimeout = timeout;
  try {
    final request = await client.headUrl(uri).timeout(timeout);
    final response = await request.close().timeout(timeout);
    unawaited(response.drain<void>());
    return true;
  } on Object catch (_) {
    return false;
  } finally {
    client.close(force: true);
  }
}
