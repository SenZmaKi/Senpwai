import 'package:senpwai/downloads/models.dart';
import 'package:senpwai/downloads/planners/planners.dart';
import 'package:senpwai/downloads/target_path_planner.dart';
import 'package:senpwai/sources/animepahe.dart' as animepahe;
import 'package:senpwai/sources/tokyoinsider.dart' as tokyoinsider;

class AnimeDownloadCoordinator {
  final AnimePaheDownloadPlanner _animepahePlanner;
  final TokyoInsiderDownloadPlanner _tokyoinsiderPlanner;
  final NyaaDownloadPlanner _nyaaPlanner;

  AnimeDownloadCoordinator({
    AnimePaheDownloadPlanner? animepahePlanner,
    TokyoInsiderDownloadPlanner? tokyoinsiderPlanner,
    NyaaDownloadPlanner? nyaaPlanner,
    DownloadTargetPlanner? targetPlanner,
  }) : _animepahePlanner =
           animepahePlanner ??
           AnimePaheDownloadPlanner(targetPlanner: targetPlanner),
       _tokyoinsiderPlanner =
           tokyoinsiderPlanner ??
           TokyoInsiderDownloadPlanner(targetPlanner: targetPlanner),
       _nyaaPlanner = nyaaPlanner ?? NyaaDownloadPlanner(),
       assert(
         animepahePlanner == null || targetPlanner == null,
         'Provide targetPlanner through animepahePlanner when overriding it.',
       ),
       assert(
         tokyoinsiderPlanner == null || targetPlanner == null,
         'Provide targetPlanner through tokyoinsiderPlanner when overriding it.',
       );

  Future<PreparedDownloadBatch> plan({
    required DownloadRequest request,
    animepahe.AnimeResult? animepaheMatch,
    tokyoinsider.AnimeResult? tokyoinsiderMatch,
  }) async {
    return switch (request.source) {
      AnimeSource.animepahe => _animepahePlanner.plan(
        request: request,
        animeMatch: animepaheMatch,
      ),
      AnimeSource.tokyoinsider => _tokyoinsiderPlanner.plan(
        request: request,
        animeMatch: tokyoinsiderMatch,
      ),
      AnimeSource.nyaa => _nyaaPlanner.plan(request),
    };
  }
}
