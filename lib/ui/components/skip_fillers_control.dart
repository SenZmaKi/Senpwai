import 'package:flutter/material.dart';
import 'package:senpwai/ui/components/toast.dart';

class SkipFillersControl extends StatelessWidget {
  final bool value;
  final Future<void> Function(bool)? onChanged;

  const SkipFillersControl({super.key, required this.value, this.onChanged});

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Flexible(
        child: Text(
          'Skip fillers',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ),
      const SizedBox(width: 4),
      Switch(
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        value: value,
        mouseCursor: SystemMouseCursors.click,
        onChanged: onChanged == null
            ? null
            : (value) async {
                try {
                  await onChanged!(value);
                } catch (_) {
                  if (!context.mounted) return;
                  AppToast.showError(
                    context,
                    title: 'Couldn’t save filler preference',
                    description:
                        'Your previous setting is still active. Try again.',
                  );
                }
              },
      ),
    ],
  );
}
