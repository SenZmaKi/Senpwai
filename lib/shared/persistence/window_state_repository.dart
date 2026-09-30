import 'dart:convert';
import 'dart:io';

import 'package:logging/logging.dart';
import 'package:path/path.dart' as path;
import 'package:senpwai/shared/log.dart';

final _log = Logger('senpwai.persistence.window_state_repository');

class WindowBounds {
  final double x;
  final double y;
  final double width;
  final double height;

  const WindowBounds({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });

  static WindowBounds? fromJson(Map<String, dynamic> json) {
    final x = _doubleValue(json['x']);
    final y = _doubleValue(json['y']);
    final width = _doubleValue(json['width']);
    final height = _doubleValue(json['height']);
    if (x == null ||
        y == null ||
        width == null ||
        height == null ||
        width <= 0 ||
        height <= 0) {
      return null;
    }
    return WindowBounds(x: x, y: y, width: width, height: height);
  }

  Map<String, dynamic> toJson() => {
    'x': x,
    'y': y,
    'width': width,
    'height': height,
  };
}

class WindowStateRepository {
  final File file;

  const WindowStateRepository({required this.file});

  Future<WindowBounds?> load() async {
    if (!await file.exists()) return null;

    try {
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Window state must be a JSON object.');
      }
      return WindowBounds.fromJson(decoded);
    } on Object catch (error, stackTrace) {
      _log.warningWithMetadata(
        'Failed to load window state; preserving corrupt file',
        metadata: {
          'path': file.path,
          'error': error.toString(),
          'stackTrace': stackTrace.toString(),
        },
      );
      await _preserveCorruptFile();
      return null;
    }
  }

  Future<void> save(WindowBounds bounds) async {
    await file.parent.create(recursive: true);
    final tempFile = File('${file.path}.tmp');
    const encoder = JsonEncoder.withIndent('  ');
    await tempFile.writeAsString(
      '${encoder.convert(bounds.toJson())}\n',
      flush: true,
    );
    if (await file.exists()) await file.delete();
    await tempFile.rename(file.path);
  }

  Future<void> _preserveCorruptFile() async {
    if (!await file.exists()) return;
    final corruptFile = File(
      path.join(file.parent.path, '${path.basename(file.path)}.corrupt'),
    );
    if (await corruptFile.exists()) await corruptFile.delete();
    await file.rename(corruptFile.path);
  }
}

double? _doubleValue(Object? value) {
  if (value is! num) return null;
  final parsed = value.toDouble();
  return parsed.isFinite ? parsed : null;
}
