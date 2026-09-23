import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:senpwai/shared/signed_envelope.dart';

void main() {
  late Ed25519 algorithm;
  late SimpleKeyPair keyPair;
  late String publicKeyBase64;

  setUpAll(() async {
    algorithm = Ed25519();
    keyPair = await algorithm.newKeyPair();
    final publicKey = await keyPair.extractPublicKey();
    publicKeyBase64 = base64.encode(publicKey.bytes);
  });

  test('verifies and decodes a signed object payload', () async {
    final envelope = await _signEnvelope(algorithm, keyPair, {
      'version': 3,
      'sources': <String, dynamic>{},
    });

    final decoded = await decodeSignedJsonEnvelope(
      envelope,
      publicKeyBase64: publicKeyBase64,
    );

    expect(decoded['version'], 3);
    expect(decoded['sources'], isA<Map<String, dynamic>>());
  });

  test('rejects a payload changed after signing', () async {
    final envelope =
        jsonDecode(await _signEnvelope(algorithm, keyPair, {'version': 3}))
            as Map<String, dynamic>;
    envelope['payload'] = base64Url.encode(utf8.encode('{"version":4}'));

    expect(
      decodeSignedJsonEnvelope(
        jsonEncode(envelope),
        publicKeyBase64: publicKeyBase64,
      ),
      throwsFormatException,
    );
  });

  test('rejects signatures from another key', () async {
    final otherKey = await algorithm.newKeyPair();
    final envelope = await _signEnvelope(algorithm, otherKey, {'version': 3});

    expect(
      decodeSignedJsonEnvelope(envelope, publicKeyBase64: publicKeyBase64),
      throwsFormatException,
    );
  });

  test('rejects malformed envelopes before verification', () async {
    for (final value in [
      '[]',
      '{}',
      '{"payload": 1, "signature": "value"}',
      '{"payload": "value", "signature": 1}',
    ]) {
      expect(
        decodeSignedJsonEnvelope(value, publicKeyBase64: publicKeyBase64),
        throwsFormatException,
      );
    }
  });

  test('rejects signed payloads that are not JSON objects', () async {
    final envelope = await _signEnvelope(algorithm, keyPair, [1, 2, 3]);

    expect(
      decodeSignedJsonEnvelope(envelope, publicKeyBase64: publicKeyBase64),
      throwsFormatException,
    );
  });
}

Future<String> _signEnvelope(
  Ed25519 algorithm,
  SimpleKeyPair keyPair,
  Object payload,
) async {
  final payloadBytes = utf8.encode(jsonEncode(payload));
  final signature = await algorithm.sign(payloadBytes, keyPair: keyPair);
  return jsonEncode({
    'payload': base64Url.encode(payloadBytes),
    'signature': base64.encode(signature.bytes),
  });
}
