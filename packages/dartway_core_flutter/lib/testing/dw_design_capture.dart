import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
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
  await tester.pumpAndSettle();
  const output = String.fromEnvironment('DW_DESIGN_CHECK_OUTPUT');
  if (output.isEmpty) {
    throw StateError('captureDwDesign must run through dartway design-check.');
  }
  final nodes = <Map<String, Object?>>[];
  void visit(Element element) {
    final render = element.renderObject;
    if (render is RenderBox && render.attached && render.hasSize) {
      final origin = render.localToGlobal(Offset.zero);
      final rect = origin & render.size;
      final screen =
          Offset.zero & tester.view.physicalSize / tester.view.devicePixelRatio;
      final visual =
          element.widget is Text ||
          element.widget is DecoratedBox ||
          element.widget is Image;
      if (visual &&
          rect.overlaps(screen) &&
          rect.width > 0 &&
          rect.height > 0) {
        String? text;
        Map<String, Object?> textStyle = const {};
        if (element.widget case Text(:final data, :final style)) {
          text = data;
          textStyle = {
            'fontFamily': style?.fontFamily,
            'fontSize': style?.fontSize,
            'fontWeight': style?.fontWeight?.value.toString(),
            'lineHeight': style?.height == null || style?.fontSize == null
                ? null
                : style!.height! * style.fontSize!,
            'color': _colour(style?.color),
          };
        }
        Color? fill;
        Color? stroke;
        double? radius;
        String? shadow;
        if (element.widget case DecoratedBox(:final decoration)) {
          if (decoration is BoxDecoration) {
            fill = decoration.color;
            stroke = decoration.border?.top.color;
            radius = decoration.borderRadius
                ?.resolve(TextDirection.ltr)
                .topLeft
                .x;
            shadow = decoration.boxShadow
                ?.map((value) => value.toString())
                .join(',');
          }
        }
        nodes.add({
          'path': '${element.widget.runtimeType}#${nodes.length}',
          'rect': [rect.left, rect.top, rect.width, rect.height],
          'text': text,
          'fill': _colour(fill),
          'stroke': _colour(stroke),
          'radius': radius,
          'shadow': shadow,
          'textStyle': textStyle,
          'overflow': rect.left < 0 || rect.right > screen.right,
        });
      }
    }
    element.visitChildren(visit);
  }

  tester.binding.rootElement!.visitChildren(visit);
  final size = tester.view.physicalSize / tester.view.devicePixelRatio;
  final target = File('$output/app/$caseId.json')
    ..parent.createSync(recursive: true);
  await target.writeAsString(
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
