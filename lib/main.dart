import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:senpwai/ui/components/app.dart';
import 'package:senpwai/ui/components/app_bootstrap.dart';
import 'package:senpwai/ui/components/toast.dart';
import 'package:senpwai/ui/shared/window_manager.dart';
import 'package:senpwai/shared/source_directory/source_directory.dart';

void main() async {
  await initApp();
  runApp(const ProviderScope(child: App()));
  _showSourceDirectoryUpdate();
  WidgetsBinding.instance.addPostFrameCallback((_) {
    unawaited(WindowManager.getInstance().reveal());
  });
}

void _showSourceDirectoryUpdate() {
  void show(SourceDirectory directory) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final context = App.navigatorKey.currentContext;
      if (context == null) return;
      AppToast.showInfo(
        context,
        title: 'Source connections updated',
        description: 'Version ${directory.version} is ready to use.',
      );
    });
  }

  final pendingUpdate = SourceDirectory.takePendingUpdate();
  if (pendingUpdate != null) show(pendingUpdate);
  SourceDirectory.updates.listen(show);
}
