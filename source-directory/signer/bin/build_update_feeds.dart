import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';

const _privateKeyEnvironment = 'SOURCE_DIRECTORY_PRIVATE_KEY';

Future<void> main(List<String> arguments) async {
  final descriptorPath = _requiredArgument(arguments, '--release');
  final manifestPath = _requiredArgument(arguments, '--manifest');
  final appcastPath = _requiredArgument(arguments, '--appcast');
  final appcastLink =
      _optionalArgument(arguments, '--appcast-link') ??
      'https://senzmaki.github.io/Senpwai/appcast.xml';
  final parsedAppcastLink = Uri.tryParse(appcastLink);
  if (parsedAppcastLink == null || parsedAppcastLink.scheme != 'https') {
    _fail('The appcast link must be an HTTPS URL.');
  }
  final descriptor = jsonDecode(await File(descriptorPath).readAsString());
  if (descriptor is! Map<String, dynamic> || descriptor['artifacts'] is! List) {
    _fail('The release descriptor must contain an artifacts list.');
  }

  final privateKey = _privateKey();
  final keyPair = await Ed25519().newKeyPairFromSeed(privateKey);
  final artifacts = <Map<String, dynamic>>[];
  Map<String, dynamic>? macArtifact;
  for (final raw in descriptor['artifacts'] as List) {
    if (raw is! Map<String, dynamic>) _fail('Invalid artifact entry.');
    final localPath = raw['localPath'] as String?;
    final url = Uri.tryParse(raw['url'] as String? ?? '');
    if (localPath == null || url == null || url.scheme != 'https') {
      _fail('Every artifact needs a localPath and HTTPS url.');
    }
    final file = File(localPath);
    if (!await file.exists()) _fail('Missing artifact: $localPath');
    final bytes = await file.readAsBytes();
    final digest = await Sha256().hash(bytes);
    final artifact = <String, dynamic>{
      'platform': raw['platform'],
      'architecture': raw['architecture'],
      'url': url.toString(),
      'fileName': raw['fileName'] ?? file.uri.pathSegments.last,
      'sizeBytes': bytes.length,
      'sha256': digest.bytes
          .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
          .join(),
    };
    artifacts.add(artifact);
    if (raw['platform'] == 'macos') {
      final signature = await Ed25519().sign(bytes, keyPair: keyPair);
      macArtifact = {
        ...artifact,
        'sparkleSignature': base64.encode(signature.bytes),
      };
    }
  }

  final version = descriptor['version'];
  final build = descriptor['build'];
  if (version is! String || build is! int) {
    _fail('Release version must be a string and build must be an integer.');
  }
  final release = <String, dynamic>{
    'version': version,
    'build': build,
    'channel': descriptor['channel'] ?? 'stable',
    'mandatory': descriptor['mandatory'] ?? false,
    'notes': descriptor['notes'] ?? '',
    'artifacts': artifacts
        .where((entry) => entry['platform'] != 'macos')
        .toList(),
  };
  final existing = jsonDecode(await File(manifestPath).readAsString());
  if (existing is! Map<String, dynamic>) _fail('Invalid existing manifest.');
  final releases =
      List<Map<String, dynamic>>.from(
        (existing['releases'] as List? ?? const [])
            .whereType<Map<String, dynamic>>(),
      )..removeWhere(
        (entry) => entry['version'] == version && entry['build'] == build,
      );
  releases.add(release);
  releases.sort((a, b) => (a['build'] as int).compareTo(b['build'] as int));
  final now = DateTime.now().toUtc();
  await File(manifestPath).writeAsString(
    '${const JsonEncoder.withIndent('  ').convert({'schemaVersion': 1, 'generatedAt': now.toIso8601String(), 'expiresAt': DateTime.utc(now.year + 1, now.month, now.day).toIso8601String(), 'releases': releases})}\n',
  );

  if (macArtifact != null) {
    await File(appcastPath).writeAsString(
      _appcast(
        version: version,
        build: build,
        notes: descriptor['notes'] as String? ?? '',
        artifact: macArtifact,
        publishedAt: now,
        appcastLink: appcastLink,
      ),
    );
  }
}

String _appcast({
  required String version,
  required int build,
  required String notes,
  required Map<String, dynamic> artifact,
  required DateTime publishedAt,
  required String appcastLink,
}) =>
    '''<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
  <channel>
    <title>Senpwai updates</title>
    <link>${_xml(appcastLink)}</link>
    <description>Senpwai macOS releases</description>
    <language>en</language>
    <item>
      <title>Senpwai ${_xml(version)}</title>
      <pubDate>${HttpDate.format(publishedAt)}</pubDate>
      <description>${_xml(notes)}</description>
      <enclosure url="${_xml(artifact['url'].toString())}"
        sparkle:version="$build"
        sparkle:shortVersionString="${_xml(version)}"
        length="${artifact['sizeBytes']}"
        type="application/octet-stream"
        sparkle:edSignature="${artifact['sparkleSignature']}" />
    </item>
  </channel>
</rss>
''';

List<int> _privateKey() {
  final encoded = Platform.environment[_privateKeyEnvironment];
  if (encoded == null || encoded.isEmpty) _fail('Set $_privateKeyEnvironment.');
  final bytes = base64.decode(encoded);
  if (bytes.length != 32) {
    _fail('The private key must be a 32-byte Ed25519 seed.');
  }
  return bytes;
}

String _requiredArgument(List<String> arguments, String name) {
  final index = arguments.indexOf(name);
  if (index == -1 || index + 1 >= arguments.length) _fail('Missing $name.');
  return arguments[index + 1];
}

String? _optionalArgument(List<String> arguments, String name) {
  final index = arguments.indexOf(name);
  if (index == -1) return null;
  if (index + 1 >= arguments.length) _fail('Missing value for $name.');
  return arguments[index + 1];
}

String _xml(String value) => value
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&apos;');

Never _fail(String message) {
  stderr.writeln(message);
  exitCode = 64;
  throw ArgumentError(message);
}
