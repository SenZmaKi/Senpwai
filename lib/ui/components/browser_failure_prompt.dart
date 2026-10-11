import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:senpwai/downloads/models.dart';
import 'package:senpwai/settings/settings.dart';
import 'package:senpwai/shared/net/browser_transport/browser_transport.dart';
import 'package:senpwai/shared/net/browser_transport/browser_failure.dart';
import 'package:senpwai/ui/components/confirm_dialog.dart';
import 'package:senpwai/ui/components/toast.dart';

/// Offers to disable the WebView-backed sources when the embedded browser
/// cannot be opened, so a broken platform WebView doesn't keep failing
/// searches and downloads.
class BrowserFailurePrompt extends ConsumerStatefulWidget {
  final Widget child;

  const BrowserFailurePrompt({super.key, required this.child});

  @override
  ConsumerState<BrowserFailurePrompt> createState() =>
      _BrowserFailurePromptState();
}

class _BrowserFailurePromptState extends ConsumerState<BrowserFailurePrompt> {
  late final StreamSubscription<BrowserFailure> _subscription;
  bool _prompting = false;
  // Keeping the sources is respected for the rest of the app run.
  bool _declined = false;

  @override
  void initState() {
    super.initState();
    _subscription = BrowserTransportService.instance.openFailures.listen(
      (failure) => unawaited(_prompt(failure)),
    );
  }

  @override
  void dispose() {
    unawaited(_subscription.cancel());
    super.dispose();
  }

  Future<void> _prompt(BrowserFailure failure) async {
    if (_prompting || _declined || !mounted) return;
    final enabled = ref
        .read(AppSettingsNotifier.provider)
        .sources
        .enabledSources;
    final browserSources = AnimeSource.values
        .where((s) => s.usesBrowserTransport && enabled.contains(s))
        .toList();
    if (browserSources.isEmpty) return;

    _prompting = true;
    try {
      final names = browserSources.map((s) => s.label).join(' and ');
      final disable = await showConfirmDialog(
        context,
        title: 'Built-in browser failed to open',
        message:
            '$names rely on a built-in browser that could not be opened on '
            'this device. Disable ${browserSources.length == 1 ? 'it' : 'them'}'
            '? You can re-enable sources anytime in Settings.',
        additionalActions: [
          TextButton.icon(
            onPressed: () => unawaited(_copyError(failure)),
            icon: const Icon(Icons.copy_rounded),
            label: const Text('Copy error'),
          ),
        ],
        confirmLabel: 'Disable',
        cancelLabel: 'Keep enabled',
      );
      if (!mounted) return;
      if (!disable) {
        _declined = true;
        return;
      }
      final current = ref
          .read(AppSettingsNotifier.provider)
          .sources
          .enabledSources;
      final remaining = current.difference(browserSources.toSet());
      await ref
          .read(AppSettingsNotifier.provider.notifier)
          .setEnabledSources(
            remaining.isEmpty
                ? SourcePreferences.defaultEnabledSources
                : remaining,
          );
      if (!mounted) return;
      AppToast.showInfo(context, title: '$names disabled');
    } finally {
      _prompting = false;
    }
  }

  Future<void> _copyError(BrowserFailure failure) async {
    try {
      await Clipboard.setData(ClipboardData(text: failure.copyDetails));
      if (!mounted) return;
      AppToast.showInfo(context, title: 'Error copied');
    } catch (error) {
      if (!mounted) return;
      AppToast.showError(
        context,
        title: 'Could not copy error',
        description: error.toString(),
      );
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
