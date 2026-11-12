import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Whether this test process was started by `dartway design-check`.
const dwDesignCheckEnabled = bool.fromEnvironment('DW_DESIGN_CHECK_ENABLED');

/// Captures the visible render tree for `dartway design-check`.
///
/// A bound widget test pumps its static state, calls [pumpAndSettle], then
/// calls this function with the case id supplied by the command in
/// `DW_DESIGN_CHECK_CASES`. The helper writes no golden assertion: the command
/// compares every case and owns the single report and exit status.
Future<File?> captureDwDesign(
  WidgetTester tester, {
  required String caseId,
  String? outputDirectory,
  Set<String>? requestedCases,
}) async {
  const configuredOutput = String.fromEnvironment('DW_DESIGN_CHECK_OUTPUT');
  final output = outputDirectory ?? configuredOutput;
  if (output.isEmpty) {
    return null;
  }
  const requested = String.fromEnvironment('DW_DESIGN_CHECK_CASES');
  final cases =
      requestedCases ??
      requested.split(',').where((value) => value.isNotEmpty).toSet();
  if (cases.isNotEmpty && !cases.contains(caseId)) {
    throw StateError('Unknown design-check case id: $caseId.');
  }
  if (!_projectFontsLoaded) {
    await _loadProjectFonts();
    _projectFontsLoaded = true;
  }
  await tester.pumpAndSettle();
  final nodes = <Map<String, Object?>>[];
  final widgets = <RenderObject, Widget>{};
  final icons = <RenderObject>{};
  void index(Element element, [bool beneathIcon = false]) {
    final render = element.renderObject;
    if (render != null) widgets[render] = element.widget;
    final icon = beneathIcon || element.widget is Icon;
    if (render != null && icon) icons.add(render);
    element.visitChildren((child) => index(child, icon));
  }

  tester.binding.rootElement!.visitChildren(index);
  void visit(RenderObject render, Rect clip) {
    if (render is RenderOffstage && render.offstage ||
        render is RenderOpacity && render.opacity == 0) {
      return;
    }
    if (render is RenderBox && render.attached && render.hasSize) {
      final origin = render.localToGlobal(Offset.zero);
      final rect = origin & render.size;
      final screen =
          Offset.zero & tester.view.physicalSize / tester.view.devicePixelRatio;
      final widget = widgets[render];
      final clipped = rect.intersect(clip);
      final icon = render is RenderParagraph && icons.contains(render);
      final visual =
          render is RenderParagraph && !icon ||
          render is RenderDecoratedBox ||
          widget is ColoredBox ||
          render is RenderPhysicalModel ||
          render is RenderPhysicalShape ||
          icon ||
          render is RenderImage;
      if (visual &&
          clipped.overlaps(screen) &&
          clipped.width > 0 &&
          clipped.height > 0) {
        String? text;
        Map<String, Object?> textStyle = const {};
        var truncated = false;
        if (render is RenderParagraph && !icon) {
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
          } else if (decoration is ShapeDecoration) {
            fill = decoration.color;
            shadow = decoration.shadows
                ?.map((value) => value.toString())
                .join(',');
            final shape = decoration.shape;
            if (shape is RoundedRectangleBorder) {
              stroke = shape.side.style == BorderStyle.none
                  ? null
                  : shape.side.color;
              strokeWidth = shape.side.style == BorderStyle.none
                  ? null
                  : shape.side.width;
              radius = shape.borderRadius.resolve(TextDirection.ltr).topLeft.x;
            }
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
        } else if (render is RenderPhysicalShape) {
          fill = render.color;
          final clipper = render.clipper;
          if (clipper is ShapeBorderClipper) {
            final shape = clipper.shape;
            if (shape is RoundedRectangleBorder) {
              stroke = shape.side.style == BorderStyle.none
                  ? null
                  : shape.side.color;
              strokeWidth = shape.side.style == BorderStyle.none
                  ? null
                  : shape.side.width;
              radius = shape.borderRadius.resolve(TextDirection.ltr).topLeft.x;
            }
          }
          if (render.elevation > 0) {
            shadow = BoxShadow(
              color: render.shadowColor,
              blurRadius: render.elevation * 2,
              offset: Offset(0, render.elevation),
            ).toString();
          }
        }
        nodes.add({
          'path': icon
              ? 'image#${nodes.length}'
              : '${render.runtimeType}#${nodes.length}',
          'rect': [clipped.left, clipped.top, clipped.width, clipped.height],
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
    render.visitChildren((child) {
      var childClip = clip;
      final localClip = render.describeApproximatePaintClip(child);
      if (localClip != null && render is RenderBox) {
        final topLeft = render.localToGlobal(localClip.topLeft);
        final bottomRight = render.localToGlobal(localClip.bottomRight);
        childClip = childClip.intersect(Rect.fromPoints(topLeft, bottomRight));
      }
      visit(child, childClip);
    });
  }

  final root = tester.binding.renderViews.single.child;
  final size = tester.view.physicalSize / tester.view.devicePixelRatio;
  if (root != null) visit(root, Offset.zero & size);
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

var _projectFontsLoaded = false;

Future<void> _loadProjectFonts() async {
  String manifestSource;
  try {
    manifestSource = await rootBundle.loadString('FontManifest.json');
  } on FlutterError {
    return;
  }
  final manifest = (jsonDecode(manifestSource) as List).cast<Map>();
  for (final entry in manifest) {
    final loader = FontLoader(entry['family']! as String);
    for (final font in (entry['fonts']! as List).cast<Map>()) {
      loader.addFont(rootBundle.load(font['asset']! as String));
    }
    await loader.load();
  }
}

String? _colour(Color? colour) => colour == null
    ? null
    : 'rgba(${(colour.r * 255).round()}, ${(colour.g * 255).round()}, ${(colour.b * 255).round()}, ${colour.a.toStringAsFixed(3)})';
