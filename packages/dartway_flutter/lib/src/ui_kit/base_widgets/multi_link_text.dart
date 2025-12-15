import 'package:collection/collection.dart';
import 'package:dartway_flutter/dartway_flutter.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

class MultiLinkTextPart {
  MultiLinkTextPart(this.text, this.linkText, this.onLinkTap);

  final String? text;
  final String? linkText;
  final DwUiAction? onLinkTap;
}

class MultiLinkText extends StatefulWidget {
  MultiLinkText.single({
    super.key,
    String? text,
    String? linkText,
    DwUiAction? onLinkTap,
    this.textAlign,
    this.textStyle,
    this.linkStyle,
  }) : parts = [MultiLinkTextPart(text, linkText, onLinkTap)];

  const MultiLinkText.multi({
    super.key,
    required this.parts,
    this.textAlign,
    this.textStyle,
    this.linkStyle,
  });

  final TextAlign? textAlign;
  final List<MultiLinkTextPart> parts;

  /// Preset for normal text
  final DwTextStylePreset? textStyle;

  /// Preset for link text
  final DwTextStylePreset? linkStyle;

  @override
  State<MultiLinkText> createState() => _MultiLinkTextState();
}

class _MultiLinkTextState extends State<MultiLinkText> {
  late List<TapGestureRecognizer?> _recognizers;

  @override
  void initState() {
    super.initState();
    _initRecognizers();
  }

  @override
  void didUpdateWidget(MultiLinkText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.parts != widget.parts) {
      _disposeRecognizers();
      _initRecognizers();
    }
  }

  void _initRecognizers() {
    _recognizers =
        widget.parts.map((e) {
          if (e.linkText != null && e.onLinkTap != null) {
            final recognizer =
                TapGestureRecognizer()
                  ..onTap = () => e.onLinkTap!.call(context);
            return recognizer;
          }
          return null;
        }).toList();
  }

  void _disposeRecognizers() {
    for (final r in _recognizers) {
      r?.dispose();
    }
  }

  @override
  void dispose() {
    _disposeRecognizers();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeExt =
        Theme.of(context).extension<DwFlutterTheme>() ??
        DwFlutterTheme.fallback;

    final baseStyle = (widget.textStyle ?? themeExt.multiLinkText).resolveStyle(
      context,
    );
    final linkStyle = (widget.linkStyle ?? themeExt.multiLinkTextLink)
        .resolveStyle(context);

    return RichText(
      textAlign: widget.textAlign ?? TextAlign.center,
      text: TextSpan(
        style: baseStyle,
        children: [
          ...widget.parts
              .mapIndexed(
                (i, e) => <InlineSpan>[
                  if (i != 0) const TextSpan(text: ' '),
                  if (e.text != null) TextSpan(text: e.text),
                  if (e.text != null && e.linkText != null)
                    const TextSpan(text: ' '),
                  if (e.linkText != null)
                    TextSpan(
                      text: e.linkText,
                      style: linkStyle,
                      recognizer: _recognizers[i],
                    ),
                ],
              )
              .expand((sublist) => sublist),
        ],
      ),
    );
  }
}
