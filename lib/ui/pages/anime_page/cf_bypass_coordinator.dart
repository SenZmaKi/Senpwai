import 'dart:async';
import 'dart:collection';

import 'package:cf_bypass/cf_bypass.dart';
import 'package:flutter/material.dart';
import 'package:senpwai/shared/net/interceptors/cf_bypass.dart';
import 'package:senpwai/ui/pages/anime_page/cf_bypass_page.dart';

class CfBypassCoordinator extends ChangeNotifier {
  CfBypassCoordinator._();

  static final instance = CfBypassCoordinator._();

  final Queue<CfBypassQueueItem> _queue = Queue();
  CfBypassQueueItem? _active;
  bool _routeOpen = false;
  int _completed = 0;
  int _nextId = 0;

  CfBypassQueueItem? get active => _active;
  int get activePosition => _active == null ? 0 : _completed + 1;
  int get totalCount => _completed + (_active == null ? 0 : 1) + _queue.length;

  Future<CfBypassResult> enqueue(
    BuildContext context,
    CfBypassChallenge challenge,
  ) {
    final item = CfBypassQueueItem(
      id: _nextId++,
      challenge: challenge,
      completer: Completer<CfBypassResult>(),
    );
    _queue.add(item);
    _activateNextIfNeeded();
    _openRouteIfNeeded(context);
    notifyListeners();
    return item.completer.future;
  }

  void completeActive(CfBypassResult result) {
    final item = _active;
    if (item == null) return;
    if (!item.completer.isCompleted) item.completer.complete(result);
    _completed++;
    _active = null;
    _activateNextIfNeeded();
    notifyListeners();
  }

  void cancelAll() {
    final cancelled = <CfBypassQueueItem>[
      if (_active case final active?) active,
      ..._queue,
    ];
    _active = null;
    _queue.clear();
    _completed = 0;
    for (final item in cancelled) {
      if (item.completer.isCompleted) continue;
      item.completer.complete(
        CfBypassResult(
          success: false,
          url: item.challenge.url,
          error: 'User cancelled CF bypass',
          cookies: const [],
        ),
      );
    }
    notifyListeners();
  }

  void _activateNextIfNeeded() {
    if (_active != null || _queue.isEmpty) return;
    _active = _queue.removeFirst();
  }

  void _openRouteIfNeeded(BuildContext context) {
    if (_routeOpen) return;
    _routeOpen = true;
    unawaited(_pushRoute(context));
  }

  Future<void> _pushRoute(BuildContext context) async {
    try {
      await Navigator.of(context).push<void>(
        MaterialPageRoute(builder: (_) => CfBypassPage(coordinator: this)),
      );
    } finally {
      _routeOpen = false;
      if (_active != null || _queue.isNotEmpty) cancelAll();
      _completed = 0;
      notifyListeners();
    }
  }
}

class CfBypassQueueItem {
  final int id;
  final CfBypassChallenge challenge;
  final Completer<CfBypassResult> completer;

  const CfBypassQueueItem({
    required this.id,
    required this.challenge,
    required this.completer,
  });
}
