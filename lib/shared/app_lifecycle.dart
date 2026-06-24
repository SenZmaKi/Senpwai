import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AppLifecycleNotifier extends Notifier<AppLifecycleState> {
  static final provider =
      NotifierProvider<AppLifecycleNotifier, AppLifecycleState>(
        AppLifecycleNotifier.new,
      );

  late final _AppLifecycleObserver _observer;

  @override
  AppLifecycleState build() {
    _observer = _AppLifecycleObserver(_setState);
    WidgetsBinding.instance.addObserver(_observer);
    ref.onDispose(() {
      WidgetsBinding.instance.removeObserver(_observer);
    });
    return WidgetsBinding.instance.lifecycleState ?? AppLifecycleState.resumed;
  }

  bool get isForeground => state == AppLifecycleState.resumed;

  void _setState(AppLifecycleState next) {
    if (state == next) return;
    state = next;
  }
}

class _AppLifecycleObserver extends WidgetsBindingObserver {
  final ValueChanged<AppLifecycleState> onChanged;

  _AppLifecycleObserver(this.onChanged);

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    scheduleMicrotask(() => onChanged(state));
  }
}
