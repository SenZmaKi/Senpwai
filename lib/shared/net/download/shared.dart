import 'dart:io';

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
  final File targetFile;
  final int sizeBytes;
  final int numberOfParts;
  final Map<String, dynamic> headers;

  DownloadParams({
    required this.url,
    required this.targetFile,
    required this.sizeBytes,
    required this.numberOfParts,
    this.headers = const {},
  });

  Directory get downloadDirectory => targetFile.parent;

  @override
  String toString() =>
      "DownloadParams(url: $url, targetFile: $targetFile, "
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
