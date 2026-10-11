import 'dart:async';
import 'package:dio/dio.dart';
import 'package:senpwai/downloads/http_link_refresh.dart';
import 'package:senpwai/downloads/models.dart';
import 'package:senpwai/downloads/runtime_codec.dart';

/// Source resolution lives in the UI isolate. Native transfer workers request
/// access here without initializing another browser/session infrastructure.
class HttpRefreshBridge {
  final void Function(Map<String, Object?>) send;
  final _pending = <String, Completer<PreparedHttpDownloadJob>>{};
  int _sequence = 0;
  bool _closed = false;
  HttpRefreshBridge(this.send);

  Future<PreparedHttpDownloadJob> refresh(PreparedHttpDownloadJob job) async {
    if (_closed) throw StateError('Download recovery bridge is closed.');
    final id = 'refresh-${++_sequence}';
    final done = Completer<PreparedHttpDownloadJob>();
    _pending[id] = done;
    send({
      'kind': 'refreshHttp',
      'refreshId': id,
      'job': DownloadRuntimeCodec.encodePreparedJob(job),
    });
    try {
      return await done.future.timeout(const Duration(minutes: 2));
    } finally {
      _pending.remove(id);
    }
  }

  void receive(Map<Object?, Object?> message) {
    final done = _pending.remove(message['refreshId']);
    if (done == null || done.isCompleted) return;
    if (message['error'] != null) {
      if (message['retryable'] == true) {
        done.completeError(
          TimeoutException('Source access is temporarily unavailable.'),
        );
        return;
      }
      done.completeError(
        DownloadUserError(
          title: message['title'] as String? ?? 'Source access unavailable',
          description: message['error'] as String,
        ),
      );
      return;
    }
    try {
      done.complete(
        DownloadRuntimeCodec.decodePreparedJob(
              Map<Object?, Object?>.from(message['job'] as Map),
            )
            as PreparedHttpDownloadJob,
      );
    } on Object catch (e, st) {
      done.completeError(e, st);
    }
  }

  void close() {
    _closed = true;
    for (final done in _pending.values) {
      done.completeError(StateError('Download recovery bridge closed.'));
    }
    _pending.clear();
  }

  static Future<void> handle(
    Map<Object?, Object?> message,
    void Function(Map<String, Object?>) reply,
  ) async {
    final result = <String, Object?>{
      'kind': 'httpRefreshed',
      'refreshId': message['refreshId'],
    };
    try {
      final job =
          DownloadRuntimeCodec.decodePreparedJob(
                Map<Object?, Object?>.from(message['job'] as Map),
              )
              as PreparedHttpDownloadJob;
      result['job'] = DownloadRuntimeCodec.encodePreparedJob(
        await HttpLinkRefresh.refresh(job),
      );
    } on Object catch (e) {
      result['retryable'] =
          e is TimeoutException ||
          (e is DioException &&
              (e.type != DioExceptionType.badResponse ||
                  e.response?.statusCode == 429 ||
                  (e.response?.statusCode ?? 0) >= 500));
      result['title'] = e is DownloadUserError
          ? e.title
          : 'Source access unavailable';
      result['error'] = e is DownloadUserError
          ? e.description
          : 'Could not refresh the selected file. Check source access and retry. (${e.runtimeType})';
    }
    reply(result);
  }
}
