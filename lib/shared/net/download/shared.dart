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
  final File targetFile;
  final int? maxBytesPerSecond;

  DownloadParams({
    required this.url,
    required this.title,
    required this.fileExtension,
    required this.downloadDirectory,
    required this.sizeBytes,
    required this.numberOfParts,
    required this.maxBytesPerSecond,
  }) : targetFile = File(
         path.join(downloadDirectory.path, "$title.$fileExtension"),
       );

  @override
  String toString() =>
      "DownloadParams(url: $url, title: $title, fileExtension: $fileExtension, "
      "downloadDirectory: $downloadDirectory, sizeBytes: $sizeBytes, "
      "numberOfParts: $numberOfParts, targetFile: $targetFile)";
}
