import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';

const _privateKeyEnvironment = 'SOURCE_DIRECTORY_PRIVATE_KEY';

Future<void> main(List<String> arguments) async {
  final input = _argument(arguments, '--input');
  final output = _argument(arguments, '--output');
  final privateKeyOutput = _argument(arguments, '--private-key-output');
  final generateKey = arguments.contains('--generate-key');

  if (generateKey) {
    if (privateKeyOutput == null) {
      usage('Missing --private-key-output for --generate-key.');
    }
    final keyPair = await Ed25519().newKeyPair();
    final privateKey = await keyPair.extractPrivateKeyBytes();
    final publicKey = await keyPair.extractPublicKey();
    await File(privateKeyOutput).writeAsString(base64.encode(privateKey));
    stdout.writeln(base64.encode(publicKey.bytes));
    return;
  }

  if (input == null || output == null) {
    usage('Both --input and --output are required.');
  }
  final privateKeyBase64 = Platform.environment[_privateKeyEnvironment];
  if (privateKeyBase64 == null || privateKeyBase64.isEmpty) {
    usage('Set $_privateKeyEnvironment to the base64-encoded private key.');
  }

  final privateKey = base64.decode(privateKeyBase64);
  if (privateKey.length != 32) {
    usage('$_privateKeyEnvironment must decode to a 32-byte Ed25519 seed.');
  }
  final payload = await File(input).readAsBytes();
  final keyPair = await Ed25519().newKeyPairFromSeed(privateKey);
  final signature = await Ed25519().sign(payload, keyPair: keyPair);
  final envelope = <String, dynamic>{
    'payload': base64UrlEncode(payload).replaceAll('=', ''),
    'signature': base64.encode(signature.bytes),
  };
  await File(output).writeAsString(
    const JsonEncoder.withIndent('  ').convert(envelope),
  );
}

String? _argument(List<String> arguments, String name) {
  final index = arguments.indexOf(name);
  return index == -1 || index + 1 == arguments.length
      ? null
      : arguments[index + 1];
}

Never usage(String message) {
  stderr.writeln(message);
  stderr.writeln(
    'Usage: dart run bin/sign.dart --input <payload.json> '
    '--output <source-directory.json>',
  );
  exitCode = 64;
  throw ArgumentError(message);
}
