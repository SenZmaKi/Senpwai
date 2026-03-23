class DownloadConfig {
  double _maxBytesPerSecond;

  double get maxBytesPerSecond => _maxBytesPerSecond;

  void updateMaxBytesPerSecond(double maxBytesPerSecond) {
    _maxBytesPerSecond = maxBytesPerSecond;
  }

  DownloadConfig({required double maxBytesPerSecond})
    : _maxBytesPerSecond = maxBytesPerSecond;

  static DownloadConfig? _instance;

  bool isOverMaxBytesPerSecond(double bytesPerSecond) =>
      _maxBytesPerSecond > 0 && bytesPerSecond > _maxBytesPerSecond;

  static DownloadConfig getInstance() =>
      _instance ??= DownloadConfig(maxBytesPerSecond: 0);
}
