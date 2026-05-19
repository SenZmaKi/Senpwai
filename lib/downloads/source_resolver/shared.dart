import 'package:logging/logging.dart';
import 'package:senpwai/shared/log.dart';
import 'package:senpwai/sources/shared/matcher/shared.dart';
import 'package:senpwai/sources/shared/shared.dart';

enum SourceMatchStatus { loading, matched, failed }

class SourceMatchState<T> {
  final SourceMatchStatus status;
  final T? result;
  final String? error;

  const SourceMatchState._({required this.status, this.result, this.error});

  const SourceMatchState.loading() : this._(status: SourceMatchStatus.loading);

  const SourceMatchState.matched(T result)
    : this._(status: SourceMatchStatus.matched, result: result);

  const SourceMatchState.failed(String error)
    : this._(status: SourceMatchStatus.failed, error: error);

  bool get isLoading => status == SourceMatchStatus.loading;
  bool get isMatched => status == SourceMatchStatus.matched;
  bool get isFailed => status == SourceMatchStatus.failed;
}

Future<SourceMatchState<SourceMatch<T>>> resolveScoredSourceMatch<T>({
  required String sourceName,
  required Logger logger,
  required Future<List<SourceMatch<T>>> Function() loadMatches,
}) async {
  try {
    final matches = await loadMatches();
    if (matches.isEmpty || matches.first.score < Constants.minMatchScore) {
      return const SourceMatchState.failed('No match found');
    }
    return SourceMatchState.matched(matches.first);
  } catch (error, stackTrace) {
    logger.warningWithMetadata(
      '$sourceName matching failed',
      metadata: {'error': error.toString(), 'stack': stackTrace.toString()},
    );
    return SourceMatchState.failed(error.toString());
  }
}
