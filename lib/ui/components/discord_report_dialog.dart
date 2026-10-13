import 'package:flutter/material.dart';
import 'package:senpwai/shared/discord_error_report.dart';
import 'package:senpwai/ui/components/discord_report_content.dart';
import 'package:senpwai/ui/shared/theme/theme_extension.dart';

class DiscordReportDialog extends StatefulWidget {
  final String title;
  final String diagnostics;

  const DiscordReportDialog({
    super.key,
    required this.title,
    required this.diagnostics,
  });

  @override
  State<DiscordReportDialog> createState() => _DiscordReportDialogState();
}

class _DiscordReportDialogState extends State<DiscordReportDialog> {
  late final TextEditingController _username;
  late final TextEditingController _message;
  bool _loading = true;
  bool _sending = false;
  String? _error;
  String? _storageWarning;

  @override
  void initState() {
    super.initState();
    _username = TextEditingController();
    _message = TextEditingController();
    _loadUsername();
  }

  Future<void> _loadUsername() async {
    try {
      final username = await DiscordErrorReport.loadUsername();
      if (mounted) _username.text = username;
    } catch (_) {
      if (mounted) _storageWarning = 'Your saved username could not be loaded.';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _username.dispose();
    _message.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_sending) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      try {
        await DiscordErrorReport.saveUsername(_username.text);
      } catch (_) {
        if (mounted) {
          setState(
            () => _storageWarning =
                'Your username could not be saved for next time.',
          );
        }
      }
      await DiscordErrorReport.send(
        title: widget.title,
        username: _username.text,
        message: _message.text,
        diagnostics: widget.diagnostics,
      );
      if (mounted) Navigator.of(context).pop(true);
    } on ReportFailure catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Could not send the report. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final media = MediaQuery.of(context);
    final compact = media.size.width < 480;
    final padding = compact ? 18.0 : 24.0;
    final availableHeight =
        (media.size.height -
                media.viewInsets.bottom -
                media.padding.vertical -
                48)
            .clamp(0.0, double.infinity);
    final ext = theme.extension<SenpwaiThemeExtension>();
    final radius = ext?.cardRadius ?? 20.0;
    final borderColor =
        ext?.cardBorderColor ??
        theme.colorScheme.primary.withValues(alpha: 0.25);
    final borderWidth = ext?.cardBorderWidth ?? 1.0;

    return PopScope(
      canPop: !_sending,
      child: Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        clipBehavior: Clip.antiAlias,
        backgroundColor: theme.colorScheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
          side: BorderSide(color: borderColor, width: borderWidth),
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 520,
            maxHeight: availableHeight,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Flexible(
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(padding, padding, padding, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _ReportHeader(
                        compact: compact,
                        onClose: _sending
                            ? null
                            : () => Navigator.of(context).pop(false),
                      ),
                      const SizedBox(height: 20),
                      DiscordReportContent(
                        title: widget.title,
                        username: _username,
                        message: _message,
                        loading: _loading,
                        sending: _sending,
                        storageWarning: _storageWarning,
                        error: _error,
                        onSubmit: _loading || _sending ? null : _send,
                      ),
                    ],
                  ),
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withValues(
                    alpha: 0.2,
                  ),
                  border: Border(
                    top: BorderSide(
                      color: theme.colorScheme.outlineVariant.withValues(
                        alpha: 0.35,
                      ),
                    ),
                  ),
                ),
                padding: EdgeInsets.symmetric(
                  horizontal: padding,
                  vertical: 14,
                ),
                child: Row(
                  children: [
                    Expanded(
                      flex: 1,
                      child: OutlinedButton(
                        onPressed: _sending
                            ? null
                            : () => Navigator.of(context).pop(false),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 44),
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                        ),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: FilledButton.icon(
                        onPressed: _loading || _sending ? null : _send,
                        icon: _sending
                            ? SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: theme.colorScheme.onPrimary,
                                ),
                              )
                            : const Icon(Icons.send_rounded, size: 16),
                        label: Text(_sending ? 'Sending…' : 'Send report'),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(0, 44),
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReportHeader extends StatelessWidget {
  final bool compact;
  final VoidCallback? onClose;

  const _ReportHeader({required this.compact, this.onClose});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final avatarSize = compact ? 52.0 : 60.0;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: avatarSize,
          height: avatarSize,
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                theme.colorScheme.primary.withValues(alpha: 0.18),
                theme.colorScheme.primary.withValues(alpha: 0.05),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: theme.colorScheme.primary.withValues(alpha: 0.25),
              width: 1,
            ),
          ),
          child: Image.asset(
            'assets/images/detective-senpbot.png',
            fit: BoxFit.contain,
            excludeFromSemantics: true,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Flexible(
                      child: Text(
                        'Report to Discord',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF5865F2).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: const Color(
                            0xFF5865F2,
                          ).withValues(alpha: 0.35),
                          width: 1,
                        ),
                      ),
                      child: Image.asset(
                        'assets/images/link_icons/discord.png',
                        width: 14,
                        height: 14,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  'Help us investigate and fix what went wrong.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (onClose != null) ...[
          const SizedBox(width: 4),
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 20),
            tooltip: 'Close',
            visualDensity: VisualDensity.compact,
            color: theme.colorScheme.onSurfaceVariant,
            onPressed: onClose,
          ),
        ],
      ],
    );
  }
}
