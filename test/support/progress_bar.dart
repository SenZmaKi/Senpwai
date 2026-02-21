import 'dart:io';

class FillingBar {
  int _total;
  int _current = 0;
  int _lastRenderedUnits = -1;
  final String fill;
  final String space;
  final int width;
  String _desc;
  final bool time;
  final bool percentage;
  final void Function(String) _write;
  final _clock = Stopwatch()..start();

  FillingBar({
    required int total,
    String desc = '',
    this.fill = '█',
    this.space = '.',
    this.width = 40,
    this.time = true,
    this.percentage = true,
    void Function(String)? writer,
  }) : _total = total,
       _desc = desc,
       _write = writer ?? stdout.write;

  set total(int total) {
    _total = total;
    _render();
  }

  set desc(String desc) {
    _desc = desc;
    _render();
  }

  void update(int value) {
    _current = value.clamp(0, _total);
    _render();
  }

  void complete() {
    _current = _total;
    _render();
    if (_clock.isRunning) {
      _clock.stop();
    }
    _write('\n');
  }

  void _render() {
    final safeTotal = _total == 0 ? 1 : _total;
    final ratio = (_current / safeTotal).clamp(0, 1);
    final progress = (ratio * width).toInt();
    final isComplete = _current >= _total;
    if (!isComplete && progress == _lastRenderedUnits) {
      return;
    }
    _lastRenderedUnits = progress;
    final filled = fill * progress;
    final empty = space * (width - progress);
    final percent = percentage ? '${(ratio * 100).toStringAsFixed(1)}%' : '';

    var timeSegment = '';
    if (time) {
      final elapsed = _clock.elapsed;
      final eta = _current == 0
          ? Duration.zero
          : Duration(
              microseconds:
                  ((_total - _current) *
                          (_clock.elapsedMicroseconds / _current))
                      .toInt(),
            );
      timeSegment = '[ ${_formatDuration(elapsed)} / ${_formatDuration(eta)} ]';
    }

    final frame =
        '\r$_desc : $filled$empty $_current/$_total $percent $timeSegment';
    _write(frame);
  }

  String _formatDuration(Duration value) {
    final text = value.toString();
    return text.length > 10 ? text.substring(0, 10) : text.padRight(10, '0');
  }
}
