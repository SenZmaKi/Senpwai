import 'package:flutter/material.dart';

enum CfBypassSolveStatus { solving, verifying, offline, success, failed }

class CfBypassHeaderTitle extends StatelessWidget {
  final int current;
  final int total;
  final String currentUrl;

  const CfBypassHeaderTitle({
    super.key,
    required this.current,
    required this.total,
    required this.currentUrl,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final host = shortenCfBypassUrl(currentUrl);
    final progress = total <= 1 ? null : '$current of $total';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('CloudFlare Verification'),
        const SizedBox(height: 1),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                host,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (progress != null) ...[
              Text(
                '  /  ',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              Text(
                progress,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

class CfBypassStatusBanner extends StatelessWidget {
  final CfBypassSolveStatus status;
  final String? message;

  const CfBypassStatusBanner({super.key, required this.status, this.message});

  @override
  Widget build(BuildContext context) {
    final (color, icon, text) = switch (status) {
      CfBypassSolveStatus.solving => (
        Colors.amber,
        Icons.hourglass_top,
        message ?? 'Solving challenge...',
      ),
      CfBypassSolveStatus.verifying => (
        Colors.blue,
        Icons.fact_check,
        message ?? 'Verifying captured clearance...',
      ),
      CfBypassSolveStatus.offline => (
        Colors.orange,
        Icons.wifi_off_rounded,
        message ?? 'No internet access',
      ),
      CfBypassSolveStatus.success => (
        Colors.green,
        Icons.check_circle,
        message ?? 'Solved!',
      ),
      CfBypassSolveStatus.failed => (
        Colors.red,
        Icons.error,
        message ?? 'Failed',
      ),
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: color.withValues(alpha: 0.15),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class CfBypassEventLog extends StatelessWidget {
  final List<String> events;

  const CfBypassEventLog({super.key, required this.events});

  @override
  Widget build(BuildContext context) {
    if (events.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Container(
      height: 120,
      width: double.infinity,
      color: colorScheme.surfaceContainerHighest,
      padding: const EdgeInsets.all(8),
      child: ListView.builder(
        reverse: true,
        itemCount: events.length,
        itemBuilder: (_, i) {
          final event = events[events.length - 1 - i];
          return Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Text(
              event,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurface.withValues(alpha: 0.7),
                fontFamily: 'monospace',
                fontSize: 11,
              ),
            ),
          );
        },
      ),
    );
  }
}

String shortenCfBypassUrl(String? url) {
  if (url == null) return '?';
  final uri = Uri.tryParse(url);
  if (uri == null) return url;
  return uri.host + uri.path;
}
