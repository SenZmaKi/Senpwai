String formatBytes(int bytes) {
  const units = ['B', 'KB', 'MB', 'GB'];
  var value = bytes.toDouble();
  var unit = 0;
  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024;
    unit++;
  }
  if (unit == 0) return '$bytes ${units[unit]}';
  return '${value.toStringAsFixed(value >= 10 ? 0 : 1)} ${units[unit]}';
}

String formatSpeedLimit(int bytesPerSecond) =>
    bytesPerSecond <= 0 ? 'Unlimited' : '${formatBytes(bytesPerSecond)}/s';

int megabytes(int value) => value * 1024 * 1024;
