import 'dart:io';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:senpwai/shared/persistence/json_file_store.dart';

class _HttpBlock {
  final int start;
  final int length;
  final String hash;
  const _HttpBlock(this.start, this.length, this.hash);
  Map<String, Object> toJson() => {
    'start': start,
    'length': length,
    'hash': hash,
  };
}

/// Half-open byte ranges. Only written, flushed, hash-checked bytes are reusable.
class HttpPartCheckpoint {
  static const blockSize = 1024 * 1024;
  final int start;
  final int end;
  int done;
  final _blocks = <_HttpBlock>[];
  final _buffer = BytesBuilder(copy: true);
  int _bufferStart;

  HttpPartCheckpoint(this.start, this.end, [this.done = 0])
    : _bufferStart = start + done;

  void record(int offset, Uint8List bytes) {
    if (offset != start + done || offset + bytes.length > end) {
      throw StateError('A download wrote outside its assigned byte range.');
    }
    var consumed = 0;
    while (consumed < bytes.length) {
      final count = (blockSize - _buffer.length).clamp(
        0,
        bytes.length - consumed,
      );
      _buffer.add(Uint8List.sublistView(bytes, consumed, consumed + count));
      consumed += count;
      if (_buffer.length == blockSize) {
        final block = _buffer.takeBytes();
        _blocks.add(
          _HttpBlock(
            _bufferStart,
            block.length,
            sha256.convert(block).toString(),
          ),
        );
        _bufferStart += block.length;
      }
    }
    done += bytes.length;
  }

  Map<String, Object> toJson() => {
    'start': start,
    'end': end,
    'done': done,
    'blocks': [
      ..._blocks.map((b) => b.toJson()),
      if (_buffer.isNotEmpty)
        _HttpBlock(
          _bufferStart,
          _buffer.length,
          sha256.convert(_buffer.toBytes()).toString(),
        ).toJson(),
    ],
  };
}

class HttpCheckpoint {
  final JsonFileStore store;
  final String targetPath;
  final String resource;
  final String? etag;
  final int size;
  final List<HttpPartCheckpoint> parts;
  bool complete;

  HttpCheckpoint({
    required this.store,
    required this.targetPath,
    required this.resource,
    required this.etag,
    required this.size,
    required this.parts,
    this.complete = false,
  });

  int get bytes => parts.fold(0, (sum, p) => sum + p.done);
  bool get canResume => etag != null;

  Future<void> save() => store.write({
    'version': 1,
    'target': targetPath,
    'resource': resource,
    'etag': etag,
    'size': size,
    'complete': complete,
    'parts': parts.map((p) => p.toJson()).toList(),
  });

  /// Read in bounded blocks in the transfer worker, never on the UI isolate.
  Future<bool> verify(File payload, {bool Function()? shouldContinue}) async {
    if (!await payload.exists() || await payload.length() != size) return false;
    final input = await payload.open();
    try {
      for (final part in parts) {
        for (final block in part._blocks) {
          if (shouldContinue != null && !shouldContinue()) return false;
          await input.setPosition(block.start);
          final data = await input.read(block.length);
          if (data.length != block.length ||
              sha256.convert(data).toString() != block.hash) {
            return false;
          }
        }
      }
      return true;
    } finally {
      await input.close();
    }
  }

  static Future<HttpCheckpoint?> load(File file, String targetPath) async {
    final store = JsonFileStore(file);
    final json = await store.read();
    if (json == null) return null;
    try {
      if (json['version'] != 1 || json['target'] != targetPath) return null;
      final size = json['size'] as int;
      if (size <= 0) return null;
      final parts = <HttpPartCheckpoint>[];
      var offset = 0;
      for (final raw in json['parts'] as List) {
        final part = HttpPartCheckpoint(
          raw['start'] as int,
          raw['end'] as int,
          raw['done'] as int,
        );
        if (part.start != offset ||
            part.end <= part.start ||
            part.end > size ||
            part.done < 0 ||
            part.done > part.end - part.start) {
          return null;
        }
        var blockOffset = part.start;
        for (final rawBlock in raw['blocks'] as List) {
          final block = _HttpBlock(
            rawBlock['start'] as int,
            rawBlock['length'] as int,
            rawBlock['hash'] as String,
          );
          if (block.start != blockOffset ||
              block.length <= 0 ||
              block.length > HttpPartCheckpoint.blockSize ||
              block.start + block.length > part.start + part.done ||
              !RegExp(r'^[0-9a-f]{64}$').hasMatch(block.hash)) {
            return null;
          }
          part._blocks.add(block);
          blockOffset += block.length;
        }
        if (blockOffset != part.start + part.done) return null;
        parts.add(part);
        offset = part.end;
      }
      if (offset != size || parts.isEmpty || parts.length > 64) return null;
      final complete = json['complete'] == true;
      if (complete && parts.any((p) => p.done != p.end - p.start)) return null;
      return HttpCheckpoint(
        store: store,
        targetPath: targetPath,
        resource: json['resource'] as String,
        etag: strongEtag(json['etag'] as String?),
        size: size,
        parts: parts,
        complete: complete,
      );
    } on TypeError {
      return null;
    }
  }

  static String? strongEtag(String? value) =>
      value != null &&
          value.startsWith('"') &&
          value.endsWith('"') &&
          value.length >= 2
      ? value
      : null;
}
