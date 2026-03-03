import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:toastification/toastification.dart';
import 'package:senpwai/ui/shared/responsive.dart';

class AppToast {
  AppToast._();

  static ToastificationItem showError(
    BuildContext context, {
    required String title,
    String? description,
    String? copyPayload,
  }) {
    return _show(
      context,
      type: ToastificationType.error,
      title: title,
      description: description,
      copyPayload: copyPayload,
    );
  }

  static ToastificationItem showWarning(
    BuildContext context, {
    required String title,
    String? description,
  }) {
    return _show(
      context,
      type: ToastificationType.warning,
      title: title,
      description: description,
    );
  }

  static ToastificationItem showInfo(
    BuildContext context, {
    required String title,
    String? description,
  }) {
    return _show(
      context,
      type: ToastificationType.info,
      title: title,
      description: description,
    );
  }

  static ToastificationItem _show(
    BuildContext context, {
    required ToastificationType type,
    required String title,
    String? description,
    String? copyPayload,
  }) {
    final mob = isMobile(context);
    return toastification.show(
      context: context,
      type: type,
      style: ToastificationStyle.flatColored,
      autoCloseDuration: const Duration(seconds: 8),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      description: description != null || copyPayload != null
          ? _ToastBody(description: description, copyPayload: copyPayload)
          : null,
      alignment: mob ? Alignment.bottomCenter : Alignment.topRight,
      margin: mob
          ? const EdgeInsets.only(bottom: 16, left: 16, right: 16)
          : const EdgeInsets.only(top: 16, right: 16),
      padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
      borderRadius: BorderRadius.circular(10),
      showProgressBar: true,
      dragToClose: true,
      applyBlurEffect: false,
      pauseOnHover: true,
    );
  }
}

class _ToastBody extends StatelessWidget {
  final String? description;
  final String? copyPayload;

  const _ToastBody({this.description, this.copyPayload});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (description != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              description!,
              style: const TextStyle(fontSize: 11, height: 1.4),
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        if (copyPayload != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: _CopyButton(payload: copyPayload!),
          ),
      ],
    );
  }
}

class _CopyButton extends StatelessWidget {
  final String payload;
  const _CopyButton({required this.payload});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 26,
      child: TextButton.icon(
        onPressed: () {
          Clipboard.setData(ClipboardData(text: payload));
          toastification.show(
            context: context,
            type: ToastificationType.success,
            style: ToastificationStyle.flatColored,
            title: const Text(
              'Copied to clipboard',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
            autoCloseDuration: const Duration(seconds: 2),
            alignment: Alignment.bottomCenter,
            showProgressBar: false,
            dragToClose: true,
          );
        },
        icon: const Icon(Icons.copy, size: 13),
        label: const Text('Copy details', style: TextStyle(fontSize: 11)),
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          visualDensity: VisualDensity.compact,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ),
    );
  }
}

String formatErrorForCopy(Object error, [StackTrace? stackTrace]) {
  final buf = StringBuffer()
    ..writeln('Error: $error')
    ..writeln('Type: ${error.runtimeType}');
  if (stackTrace != null) {
    buf
      ..writeln()
      ..writeln('Stack trace:')
      ..write(stackTrace);
  }
  return buf.toString();
}
