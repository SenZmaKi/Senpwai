import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';

class AppRenderDiagnostics {
  static String? currentPage;
}

String? buildRenderViewportDiagnostics() {
  if (!kDebugMode) return null;

  try {
    final buffer = StringBuffer()
      ..writeln('Render diagnostics:')
      ..writeln(
        'Current page: ${AppRenderDiagnostics.currentPage ?? 'unknown'}',
      );

    var viewportCount = 0;
    var suspiciousSliverCount = 0;

    for (final view in RendererBinding.instance.renderViews) {
      _visitRenderObjects(view, (object) {
        if (object is! RenderViewportBase) return;

        viewportCount++;
        buffer
          ..writeln()
          ..writeln('Viewport #$viewportCount')
          ..writeln('  type: ${object.runtimeType}')
          ..writeln('  attached: ${object.attached}')
          ..writeln('  needsLayout: ${object.debugNeedsLayout}')
          ..writeln('  hasSize: ${object.hasSize}')
          ..writeln('  size: ${object.hasSize ? object.size : 'no size'}')
          ..writeln('  creator: ${_describeCreator(object.debugCreator)}');

        var childIndex = 0;
        object.visitChildren((childObject) {
          if (childObject is! RenderSliver) return;

          final child = childObject;
          childIndex++;
          final geometry = child.geometry;
          final suspicious = geometry == null || child.debugNeedsLayout;
          if (suspicious) suspiciousSliverCount++;

          buffer
            ..writeln('  sliver #$childIndex')
            ..writeln('    type: ${child.runtimeType}')
            ..writeln('    geometry: ${geometry ?? 'NULL'}')
            ..writeln('    needsLayout: ${child.debugNeedsLayout}')
            ..writeln('    attached: ${child.attached}')
            ..writeln('    creator: ${_describeCreator(child.debugCreator)}');
        });
      });
    }

    buffer
      ..writeln()
      ..writeln('Viewport count: $viewportCount')
      ..writeln('Suspicious sliver count: $suspiciousSliverCount');

    return buffer.toString();
  } catch (error, stack) {
    return 'Render diagnostics failed: $error\n$stack';
  }
}

void _visitRenderObjects(RenderObject root, void Function(RenderObject) visit) {
  visit(root);
  root.visitChildren((child) => _visitRenderObjects(child, visit));
}

String _describeCreator(Object? creator) {
  if (creator == null) return 'unknown';
  return creator.toString();
}
