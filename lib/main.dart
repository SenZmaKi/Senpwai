import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:senpwai/ui/components/app.dart';

void main() async {
  await initApp();
  runApp(const ProviderScope(child: App()));
}
