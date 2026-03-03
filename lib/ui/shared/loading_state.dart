import 'dart:async';

import 'package:flutter/widgets.dart';

class LoadingStateController {
  static const _delayBeforeShow = Duration(milliseconds: 1000);
  static const _minimumShowDuration = Duration(milliseconds: 500);

  bool _isLoading = false;
  DateTime? _shownAt;
  Timer? _delayTimer;

  bool get isLoading => _isLoading;

  Future<T> run<T>({
    required Future<T> Function() task,
    required VoidCallback onChanged,
  }) async {
    _delayTimer?.cancel();
    final completer = Completer<T>();
    var resolved = false;

    _delayTimer = Timer(_delayBeforeShow, () {
      if (!resolved) {
        _isLoading = true;
        _shownAt = DateTime.now();
        onChanged();
      }
    });

    try {
      final result = await task();
      resolved = true;
      await _unsetLoading(onChanged);
      completer.complete(result);
    } catch (e, st) {
      resolved = true;
      await _unsetLoading(onChanged);
      completer.completeError(e, st);
    }

    return completer.future;
  }

  Future<void> _unsetLoading(VoidCallback onChanged) async {
    _delayTimer?.cancel();
    if (_isLoading && _shownAt != null) {
      final elapsed = DateTime.now().difference(_shownAt!);
      if (elapsed < _minimumShowDuration) {
        await Future<void>.delayed(_minimumShowDuration - elapsed);
      }
    }
    _isLoading = false;
    _shownAt = null;
    onChanged();
  }

  void dispose() {
    _delayTimer?.cancel();
  }
}
