import 'package:logging/logging.dart';
import 'package:senpwai/shared/log.dart';

final _log = Logger("senpwai.test.support.timeit");

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
