import 'dart:async';
import 'dart:io';
import 'dart:math';

class DownloadServer {
  final List<int> payload;
  HttpServer? _server;

  DownloadServer({required this.payload});

  Future<void> start() async {
    _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _server!.listen(_handleRequest);
  }

  Future<void> close() async {
    await _server?.close(force: true);
  }

  String get downloadUrl {
    final server = _server;
    if (server == null) {
      throw StateError('Server not started');
    }
    return 'http://${server.address.host}:${server.port}/artifact.bin';
  }

  Future<void> _handleRequest(HttpRequest request) async {
    if (request.method != 'GET' || request.uri.path != '/artifact.bin') {
      request.response.statusCode = HttpStatus.notFound;
      await request.response.close();
      return;
    }

    final payloadLength = payload.length;
    var start = 0;
    var end = payloadLength - 1;
    var isRangeRequest = false;

    final rangeHeader = request.headers.value(HttpHeaders.rangeHeader);
    if (rangeHeader != null && rangeHeader.startsWith('bytes=')) {
      isRangeRequest = true;
      final rangeValue = rangeHeader.substring('bytes='.length);
      final parts = rangeValue.split('-');
      if (parts.isNotEmpty && parts[0].isNotEmpty) {
        start = int.parse(parts[0]);
      }
      if (parts.length > 1 && parts[1].isNotEmpty) {
        end = int.parse(parts[1]);
      }
      end = end.clamp(start, payloadLength - 1);
      start = start.clamp(0, payloadLength - 1);
    }

    final slice = payload.sublist(start, end + 1);
    final response = request.response;
    response.statusCode = isRangeRequest
        ? HttpStatus.partialContent
        : HttpStatus.ok;
    response.headers.set(HttpHeaders.acceptRangesHeader, 'bytes');
    response.headers.set(HttpHeaders.contentLengthHeader, slice.length);
    if (isRangeRequest) {
      response.headers.set(
        HttpHeaders.contentRangeHeader,
        'bytes $start-$end/$payloadLength',
      );
    }

    const chunkSize = 1024;
    for (var offset = 0; offset < slice.length; offset += chunkSize) {
      final chunkEnd = min(offset + chunkSize, slice.length);
      response.add(slice.sublist(offset, chunkEnd));
      await response.flush();
      await Future<void>.delayed(const Duration(milliseconds: 2));
    }
    await response.close();
  }
}
