import 'dart:convert';

import 'package:cryptography/cryptography.dart';

/// Public trust root shared by Senpwai's declarative remote manifests.
const senpwaiManifestPublicKeyBase64 =
    'tK5qjqlCFmgyiPDwWt3d6zccUuO7fYHsGqxkDUM6lcU=';

Future<Map<String, dynamic>> decodeSignedJsonEnvelope(
  String envelopeText, {
  String publicKeyBase64 = senpwaiManifestPublicKeyBase64,
}) async {
  final envelope = jsonDecode(envelopeText);
  if (envelope is! Map<String, dynamic> ||
      envelope['payload'] is! String ||
      envelope['signature'] is! String) {
    throw const FormatException('Invalid signed JSON envelope.');
  }

  final payload = base64Url.decode(
    base64Url.normalize(envelope['payload'] as String),
  );
  final signatureBytes = base64.decode(envelope['signature'] as String);
  final publicKeyBytes = base64.decode(publicKeyBase64);
  final verified = await Ed25519().verify(
    payload,
    signature: Signature(
      signatureBytes,
      publicKey: SimplePublicKey(publicKeyBytes, type: KeyPairType.ed25519),
    ),
  );
  if (!verified) {
    throw const FormatException('Invalid signed JSON signature.');
  }

  final decoded = jsonDecode(utf8.decode(payload));
  if (decoded is! Map<String, dynamic>) {
    throw const FormatException('Signed JSON payload must be an object.');
  }
  return decoded;
}
