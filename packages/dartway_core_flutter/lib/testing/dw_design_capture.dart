import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

/// Captures the visible render tree for `dartway design-check`.
///
/// A bound widget test pumps its static state, calls [pumpAndSettle], then
/// calls this function with the case id supplied by the command in
/// `DW_DESIGN_CHECK_CASES`. The helper writes no golden assertion: the command
/// compares every case and owns the single report and exit status.
Future<File> captureDwDesign(
  WidgetTester tester, {
  required String caseId,
}) async {
  const output = String.fromEnvironment('DW_DESIGN_CHECK_OUTPUT');
  if (output.isEmpty) {
    throw StateError('captureDwDesign must run through dartway design-check.');
  }
  const requested = String.fromEnvironment('DW_DESIGN_CHECK_CASES');
  final cases = requested.split(',').where((value) => value.isNotEmpty).toSet();
  if (cases.isNotEmpty && !cases.contains(caseId)) {
    throw StateError('Unknown design-check case id: $caseId.');
  }
  await tester.pumpAndSettle();
  final nodes = <Map<String, Object?>>[];
  final widgets = <RenderObject, Widget>{};
  void index(Element element) {
    final render = element.renderObject;
    if (render != null) widgets[render] = element.widget;
    element.visitChildren(index);
  }

  tester.binding.rootElement!.visitChildren(index);
  void visit(RenderObject render) {
    if (render is RenderBox && render.attached && render.hasSize) {
      final origin = render.localToGlobal(Offset.zero);
      final rect = origin & render.size;
      final screen =
          Offset.zero & tester.view.physicalSize / tester.view.devicePixelRatio;
      final widget = widgets[render];
      final visual =
          render is RenderParagraph ||
          render is RenderDecoratedBox ||
          widget is ColoredBox ||
          render is RenderPhysicalModel ||
          render is RenderImage;
      if (visual &&
          rect.overlaps(screen) &&
          rect.width > 0 &&
          rect.height > 0) {
        String? text;
        Map<String, Object?> textStyle = const {};
        var truncated = false;
        if (render is RenderParagraph) {
          final style = render.text.style;
          text = render.text.toPlainText();
          textStyle = {
            'fontFamily': style?.fontFamily,
            'fontSize': style?.fontSize,
            'fontWeight': style?.fontWeight?.value.toString(),
            'lineHeight': style?.height == null || style?.fontSize == null
                ? null
                : style!.height! * style.fontSize!,
            'color': _colour(style?.color),
          };
          final painter = TextPainter(
            text: render.text,
            textAlign: render.textAlign,
            textDirection: render.textDirection,
            textScaler: render.textScaler,
            maxLines: render.maxLines,
            ellipsis: render.overflow == TextOverflow.ellipsis ? '…' : null,
            locale: render.locale,
            strutStyle: render.strutStyle,
            textWidthBasis: render.textWidthBasis,
            textHeightBehavior: render.textHeightBehavior,
          )..layout(maxWidth: render.size.width);
          truncated = painter.didExceedMaxLines;
          painter.dispose();
        }
        Color? fill;
        Color? stroke;
        double? radius;
        String? shadow;
        double? strokeWidth;
        if (render is RenderDecoratedBox) {
          final decoration = render.decoration;
          if (decoration is BoxDecoration) {
            fill = decoration.color;
            stroke = decoration.border?.top.color;
            strokeWidth = decoration.border?.top.width;
            radius = decoration.borderRadius
                ?.resolve(TextDirection.ltr)
                .topLeft
                .x;
            shadow = decoration.boxShadow
                ?.map((value) => value.toString())
                .join(',');
          }
        } else if (widget is ColoredBox) {
          fill = widget.color;
        } else if (render is RenderPhysicalModel) {
          fill = render.color;
          radius = render.borderRadius?.topLeft.x;
          if (render.elevation > 0) {
            shadow = BoxShadow(
              color: render.shadowColor,
              blurRadius: render.elevation * 2,
              offset: Offset(0, render.elevation),
            ).toString();
          }
        }
        nodes.add({
          'path': '${render.runtimeType}#${nodes.length}',
          'rect': [rect.left, rect.top, rect.width, rect.height],
          'text': text,
          'fill': _colour(fill),
          'stroke': _colour(stroke),
          'strokeWidth': strokeWidth,
          'radius': radius,
          'shadow': shadow,
          'textStyle': textStyle,
          'overflow': rect.left < 0 || rect.right > screen.right,
          'truncated': truncated,
        });
      }
    }
    render.visitChildren(visit);
  }

  final root = tester.binding.renderViews.single.child;
  if (root != null) visit(root);
  final size = tester.view.physicalSize / tester.view.devicePixelRatio;
  final target = File('$output/app/$caseId.json')
    ..parent.createSync(recursive: true);
  target.writeAsStringSync(
    '${jsonEncode({
      'viewport': [size.width, size.height],
      'nodes': nodes,
    })}\n',
  );
  return target;
}

String? _colour(Color? colour) => colour == null
    ? null
    : 'rgba(${(colour.r * 255).round()}, ${(colour.g * 255).round()}, ${(colour.b * 255).round()}, ${colour.a.toStringAsFixed(3)})';
