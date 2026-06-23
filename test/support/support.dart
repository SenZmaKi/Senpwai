import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logging/logging.dart';
import 'package:senpwai/shared/log.dart';
import 'package:senpwai/shared/persistence/app_persistence.dart';

final _log = Logger("senpwai.test.support.timeit");
Directory? _testPersistenceDirectory;

Future<void> setupTestApp() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  FlutterSecureStorage.setMockInitialValues({});
  setupLogger();
  _testPersistenceDirectory ??= await Directory.systemTemp.createTemp(
    'senpwai-test-persistence-',
  );
  await AppPersistence.initialize(rootDirectory: _testPersistenceDirectory);
}

Future<Duration> timeIt({
  required String label,
  required Future<void> Function() fn,
}) async {
  final stopwatch = Stopwatch()..start();
  try {
    await fn();
  } finally {
    stopwatch.stop();
    _log.infoWithMetadata(label, metadata: {"elapsed": stopwatch.elapsed});
  }
  return stopwatch.elapsed;
}

Duration timeItSync({required String label, required Function() fn}) {
  final stopwatch = Stopwatch()..start();
  try {
    fn();
  } finally {
    stopwatch.stop();
    _log.infoWithMetadata(label, metadata: {"elapsed": stopwatch.elapsed});
  }
  return stopwatch.elapsed;
}
