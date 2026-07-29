import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:senpwai/ui/components/app.dart';
import 'package:senpwai/ui/components/app_bootstrap.dart';
import 'package:senpwai/ui/shared/window_manager.dart';

void main() async {
  await initApp();
  runApp(const ProviderScope(child: App()));
  WidgetsBinding.instance.addPostFrameCallback((_) {
    unawaited(WindowManager.getInstance().reveal());
  });
}
