import 'package:flutter_test/flutter_test.dart';
import 'package:logging/logging.dart';
import 'package:senpwai/downloads/source_resolver/shared.dart';
import 'package:senpwai/sources/shared/matcher/shared.dart';

void main() {
  test('an empty search is distinct from a failed search', () async {
    Future<SourceMatchState<SourceMatch<String>>> resolve(
      Future<List<SourceMatch<String>>> Function() load,
    ) => resolveScoredSourceMatch<String>(
      sourceName: 'Example',
      logger: Logger('test'),
      loadMatches: load,
    );
    final missing = await resolve(() async => []);
    expect(missing.noMatch, isTrue);
    final failed = await resolve(() async => throw StateError('Offline'));
    expect(failed.isFailed, isTrue);
    expect(failed.noMatch, isFalse);
  });
}
