import 'dart:io';
import 'package:path/path.dart' as path;

class DownloadCancelledException implements Exception {
  final String message;
  DownloadCancelledException(this.message);

  @override
  String toString() => 'DownloadCancelledException: $message';
}

class DownloadProgress {
  final int partNumber;
  final int bytesDownloaded;

  DownloadProgress({required this.partNumber, required this.bytesDownloaded});

  @override
  String toString() =>
      "DownloadProgress(partNumber: $partNumber, bytesDownloaded: $bytesDownloaded)";
}

class DownloadParams {
  final String url;
  final String title;
  final String fileExtension;
  final Directory downloadDirectory;
  final int sizeBytes;
  final int numberOfParts;
  final Map<String, dynamic> headers;
  final File targetFile;

  DownloadParams({
    required this.url,
    required this.title,
    required this.fileExtension,
    required this.downloadDirectory,
    required this.sizeBytes,
    required this.numberOfParts,
    this.headers = const {},
  }) : targetFile = File(
         path.join(downloadDirectory.path, "$title.$fileExtension"),
       );

  @override
  String toString() =>
      "DownloadParams(url: $url, title: $title, fileExtension: $fileExtension, "
      "downloadDirectory: $downloadDirectory, sizeBytes: $sizeBytes, "
      "numberOfParts: $numberOfParts, headers: $headers, targetFile: $targetFile)";
}

class ResolvedDownloadTarget {
  final String resolvedUrl;
  final int sizeBytes;

  const ResolvedDownloadTarget({
    required this.resolvedUrl,
    required this.sizeBytes,
  });

  @override
  String toString() =>
      'ResolvedDownloadTarget(resolvedUrl: $resolvedUrl, sizeBytes: $sizeBytes)';
}

class DownloadProbeException implements Exception {
  final String message;

  const DownloadProbeException(this.message);

  @override
  String toString() => 'DownloadProbeException: $message';
}
