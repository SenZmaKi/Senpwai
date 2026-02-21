import 'package:dio/dio.dart';
import 'package:html/dom.dart';
import 'package:logging/logging.dart';
import 'package:senpwai/shared/net/net.dart';
import 'package:senpwai/shared/shared.dart' as shared;
import 'package:senpwai/shared/log.dart';
import 'package:senpwai/sources/shared/shared.dart';

final log = Logger('senpwai.anime.sources.nyaa');

class SearchParams {
  String term;
  int page;

  SearchParams({required this.term, required this.page});

  @override
  String toString() => 'SearchParams(term: $term, page: $page)';
}

class Constants {
  static const baseUrl = "https://nyaa.si";
  static const resultsPerPage = 75;
}

class AnimeResult {
  String filename;
  String torrentFileUrl;
  String magnetUrl;
  int sizeBytes;
  DateTime dateAdded;
  int seeders;
  int leechers;
  int torrentFileDownloadCount;

  AnimeResult({
    required this.filename,
    required this.torrentFileUrl,
    required this.magnetUrl,
    required this.sizeBytes,
    required this.dateAdded,
    required this.seeders,
    required this.leechers,
    required this.torrentFileDownloadCount,
  });

  @override
  String toString() =>
      'AnimeResult(filename: $filename, torrentFileUrl: $torrentFileUrl, magnetUrl: $magnetUrl, sizeBytes: $sizeBytes, dateAdded: $dateAdded, seeders: $seeders, leechers: $leechers, torrentFileDownloadCount: $torrentFileDownloadCount)';
}

class Source {
  final Dio _dio;

  Source() : _dio = GlobalDio.getInstance();

  Future<Pagination<List<AnimeResult>>> search({
    required SearchParams params,
  }) async {
    log.infoWithMetadata("Searching", metadata: {"params": params});
    final term = params.term;
    final page = params.page;

    final response = await _dio.get(
      Constants.baseUrl,
      queryParameters: {"q": term, "s": "seeders", "o": "desc", "p": page},
    );
    final htmlPage = parseHtml(response.data);
    final results = _parseSearchResults(htmlPage);
    final pagination = _buildPagination(
      params: params,
      results: results,
      htmlPage: htmlPage,
    );
    log.fineWithMetadata(
      "Search results",
      metadata: {"pagination": pagination},
    );
    return pagination;
  }

  Pagination<List<AnimeResult>> _buildPagination({
    required SearchParams params,
    required List<AnimeResult> results,
    required Document htmlPage,
  }) {
    if (results.isEmpty) {
      return Pagination(
        currentPage: params.page,
        items: results,
        perPage: Constants.resultsPerPage,
        fetchNextPage: null,
        totalPages: 0,
      );
    }

    // Get the second-to-last pagination link for total pages
    final paginationItems = htmlPage.querySelectorAll("ul.pagination > li");
    final totalPagesStr = paginationItems[paginationItems.length - 2].text;
    final totalPages = int.parse(totalPagesStr);
    final fetchNextPage = params.page < totalPages
        ? () => search(
            params: SearchParams(term: params.term, page: params.page + 1),
          )
        : null;
    return Pagination(
      perPage: Constants.resultsPerPage,
      currentPage: params.page,
      items: results,
      totalPages: totalPages,
      fetchNextPage: fetchNextPage,
    );
  }

  List<AnimeResult> _parseSearchResults(Document htmlPage) {
    log.infoWithMetadata("Parsing search results", metadata: {});
    return htmlPage
        .querySelectorAll("tr.default")
        .where(
          (el) =>
              el.querySelector("td > a")?.attributes["title"] ==
              "Anime - English-translated",
        )
        .map((el) {
          final tds = el.querySelectorAll("td");
          // Column 2 (index 1) - Title
          final aTags = tds[1].querySelectorAll("a");
          log.infoWithMetadata("aTags", metadata: {"aTags": aTags});
          final filename = aTags.last.text;
          // Column 3 (index 2) - Download links
          final downloadLinks = tds[2].querySelectorAll("a");
          final torrentFileResource = downloadLinks[0].attributes["href"]!;
          final torrentFileUrl = '${Constants.baseUrl}$torrentFileResource';
          final magnetUrl = downloadLinks[1].attributes["href"]!;
          // Column 4 (index 3) - Size
          final sizeBytesStr = tds[3].text;
          final sizeBytes = _parseSizeBytes(sizeBytesStr);

          // Column 5 (index 4) - Date
          final dateEpoch = tds[4].attributes["data-timestamp"]!;
          final dateAdded = DateTime.fromMillisecondsSinceEpoch(
            int.parse(dateEpoch) * 1000,
          );

          // Column 6 (index 5) - Seeders
          final seedersStr = tds[5].text;
          final seeders = int.parse(seedersStr);

          // Column 7 (index 6) - Leechers
          final leechersStr = tds[6].text;
          final leechers = int.parse(leechersStr);

          // Column 8 (index 7) - Downloads
          final torrentFileDownloadCountStr = tds[7].text;
          final torrentFileDownloadCount = int.parse(
            torrentFileDownloadCountStr,
          );

          return AnimeResult(
            filename: filename,
            torrentFileUrl: torrentFileUrl,
            magnetUrl: magnetUrl,
            sizeBytes: sizeBytes,
            dateAdded: dateAdded,
            seeders: seeders,
            leechers: leechers,
            torrentFileDownloadCount: torrentFileDownloadCount,
          );
        })
        .cast<AnimeResult>()
        .toList();
  }

  int _parseSizeBytes(String sizeStr) {
    log.infoWithMetadata("Parsing size bytes", metadata: {"sizeStr": sizeStr});
    final parts = sizeStr.split(" ");
    final unitName = parts[1];
    final unitToBytes = switch (unitName) {
      "TiB" => shared.Constants.teraByte,
      "GiB" => shared.Constants.gigaByte,
      "MiB" => shared.Constants.megaByte,
      "KiB" => shared.Constants.kiloByte,
      "iB" => 1,
      _ => throw SourceException(
        message: "Unsupported bytes format",
        metadata: {"sizeStr": sizeStr},
      ),
    };
    final unitQuantity = double.parse(parts[0]);
    final sizeBytes = (unitQuantity * unitToBytes).round();
    log.fineWithMetadata(
      "Parsed size bytes",
      metadata: {"sizeStr": sizeStr, "sizeBytes": sizeBytes},
    );
    return sizeBytes;
  }
}
