import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:senpwai/shared/net/download/http_checkpoint.dart';
import 'package:senpwai/shared/persistence/json_file_store.dart';

void main() {
  late Directory directory;
  late File file;
  late File payload;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('http-checkpoint-');
    file = File('${directory.path}/checkpoint.json');
    payload = File('${directory.path}/payload');
  });
  tearDown(() async => directory.delete(recursive: true));

  Future<HttpCheckpoint> create() async {
    await payload.writeAsBytes([1, 2, 0, 0, 5, 6, 7, 8]);
    final parts = [HttpPartCheckpoint(0, 4), HttpPartCheckpoint(4, 8)];
    parts[0].record(0, Uint8List.fromList([1, 2]));
    parts[1].record(4, Uint8List.fromList([5, 6, 7, 8]));
    final checkpoint = HttpCheckpoint(
      store: JsonFileStore(file),
      targetPath: payload.path,
      resource: 'https://example.com/file',
      etag: '"v1"',
      size: 8,
      parts: parts,
    );
    await checkpoint.save();
    return (await HttpCheckpoint.load(file, payload.path))!;
  }

  test(
    'verifies actual sparse ranges after reopening and detects local corruption',
    () async {
      final checkpoint = await create();
      expect(checkpoint.bytes, 6);
      expect(checkpoint.parts.map((p) => p.start), [0, 4]);
      expect(await checkpoint.verify(payload), isTrue);
      await payload.writeAsBytes([1, 9, 0, 0, 5, 6, 7, 8]);
      expect(await checkpoint.verify(payload), isFalse);
    },
  );

  test(
    'verification respects cancellation and rejects truncated payload',
    () async {
      final checkpoint = await create();
      expect(
        await checkpoint.verify(payload, shouldContinue: () => false),
        isFalse,
      );
      await payload.writeAsBytes([1, 2]);
      expect(await checkpoint.verify(payload), isFalse);
    },
  );

  test('restored range can append bytes and verify another restart', () async {
    final checkpoint = await create();
    checkpoint.parts.first.record(2, Uint8List.fromList([3, 4]));
    await payload.writeAsBytes([1, 2, 3, 4, 5, 6, 7, 8]);
    checkpoint.complete = true;
    await checkpoint.save();
    final restored = (await HttpCheckpoint.load(file, payload.path))!;
    expect(restored.bytes, 8);
    expect(restored.complete, isTrue);
    expect(await restored.verify(payload), isTrue);
  });

  for (final corruption in [
    'gap',
    'unhashed',
    'false-completion',
    'invalid-hash',
  ]) {
    test('rejects $corruption checkpoint', () async {
      await create();
      final json =
          jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      switch (corruption) {
        case 'gap':
          json['parts'][1]['start'] = 5;
        case 'unhashed':
          json['parts'][0]['done'] = 3;
        case 'false-completion':
          json['complete'] = true;
        case 'invalid-hash':
          json['parts'][0]['blocks'][0]['hash'] = 'bad';
      }
      await file.writeAsString(jsonEncode(json));
      expect(await HttpCheckpoint.load(file, payload.path), isNull);
    });
  }

  test('weak and absent validators cannot authorize resumption', () {
    for (final value in [null, 'W/"v1"', 'unquoted']) {
      expect(HttpCheckpoint.strongEtag(value), isNull);
    }
    expect(HttpCheckpoint.strongEtag('"v1"'), '"v1"');
  });

  test('range writer rejects overlap and overflow', () {
    final part = HttpPartCheckpoint(4, 8);
    expect(() => part.record(3, Uint8List(1)), throwsStateError);
    expect(() => part.record(4, Uint8List(5)), throwsStateError);
  });
}
