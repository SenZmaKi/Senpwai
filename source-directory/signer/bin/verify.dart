import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';

Future<void> main(List<String> arguments) async {
  final input = _requiredArgument(arguments, '--input');
  final output = _requiredArgument(arguments, '--output');
  final publicKeyBase64 = _requiredArgument(arguments, '--public-key');
  final envelope = jsonDecode(await File(input).readAsString());
  if (envelope is! Map<String, dynamic> ||
      envelope['payload'] is! String ||
      envelope['signature'] is! String) {
    _fail('Invalid signed JSON envelope.');
  }

  final payload = base64Url.decode(
    base64Url.normalize(envelope['payload'] as String),
  );
  final signature = base64.decode(envelope['signature'] as String);
  final publicKey = base64.decode(publicKeyBase64);
  final verified = await Ed25519().verify(
    payload,
    signature: Signature(
      signature,
      publicKey: SimplePublicKey(publicKey, type: KeyPairType.ed25519),
    ),
  );
  if (!verified) _fail('Invalid signed JSON signature.');

  jsonDecode(utf8.decode(payload));
  await File(output).writeAsBytes(payload, flush: true);
}

String _requiredArgument(List<String> arguments, String name) {
  final index = arguments.indexOf(name);
  if (index == -1 || index + 1 >= arguments.length) {
    _fail('Missing $name.');
  }
  return arguments[index + 1];
}

Never _fail(String message) {
  stderr.writeln(message);
  exitCode = 64;
  throw ArgumentError(message);
}
