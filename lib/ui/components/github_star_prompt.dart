import 'dart:io';

import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as path;
import 'package:senpwai/shared/persistence/app_persistence.dart';
import 'package:senpwai/shared/persistence/json_file_store.dart';
import 'package:senpwai/ui/components/toast.dart';
import 'package:url_launcher/url_launcher.dart';

const _repositoryUrl = 'https://github.com/SenZmaKi/Senpwai';
final _log = Logger('senpwai.github_star_prompt');

/// Show only on the third production launch, once per installation.
Future<bool> shouldShowGithubStarPrompt() async {
  final store = JsonFileStore(
    File(
      path.join(
        AppPersistence.paths.stateDirectory.path,
        'github_star_prompt.json',
      ),
    ),
  );
  try {
    final state = await store.read() ?? <String, dynamic>{};
    if (state['shown'] == true) return false;
    final launches = ((state['launches'] as num?)?.toInt() ?? 0) + 1;
    final shouldShow = launches >= 3;
    await store.write({'launches': launches, 'shown': shouldShow});
    return shouldShow;
  } catch (error, stack) {
    _log.warning('Could not update GitHub star prompt state', error, stack);
    return false;
  }
}

Future<void> showGithubStarPrompt(BuildContext context) async {
  final openRepository = await showDialog<bool>(
    context: context,
    builder: (context) => const _GithubStarDialog(),
  );
  if (openRepository != true || !context.mounted) return;

  final opened = await launchUrl(
    Uri.parse(_repositoryUrl),
    mode: LaunchMode.externalApplication,
  );
  if (!opened && context.mounted) {
    AppToast.showError(
      context,
      title: 'Could not open GitHub',
      description: 'Please try again later.',
    );
  }
}

class _GithubStarDialog extends StatefulWidget {
  const _GithubStarDialog();

  @override
  State<_GithubStarDialog> createState() => _GithubStarDialogState();
}

class _GithubStarDialogState extends State<_GithubStarDialog> {
  bool _prettyPlease = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 410),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(
                _prettyPlease
                    ? 'assets/images/senpwai-github-please.png'
                    : 'assets/images/senpwai-github-star.png',
                width: 170,
                height: 170,
                semanticLabel: _prettyPlease
                    ? 'Senpwai mascot pleading playfully'
                    : 'Senpwai mascot offering a star',
              ),
              const SizedBox(height: 12),
              Text(
                _prettyPlease ? 'Pretty please?' : 'Enjoying Senpwai?',
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                _prettyPlease
                    ? 'Just one tiny star? I pwomise to be normal about it.'
                    : 'A GitHub star helps more people find it.',
                textAlign: TextAlign.center,
                style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 24),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  TextButton(
                    onPressed: _prettyPlease
                        ? () => Navigator.of(context).pop(false)
                        : () => setState(() => _prettyPlease = true),
                    child: Text(_prettyPlease ? 'Fuck off' : 'Not now'),
                  ),
                  FilledButton.icon(
                    onPressed: () => Navigator.of(context).pop(true),
                    icon: const Icon(Icons.star_rounded),
                    label: const Text('Star on GitHub'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
