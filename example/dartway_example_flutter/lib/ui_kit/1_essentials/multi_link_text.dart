part of '../ui_kit.dart';

class MultiLinkTextPart {
  MultiLinkTextPart(this.text, this.linkText, this.onLinkTap);

  final String? text;
  final String? linkText;
  final DwUiAction? onLinkTap;
}

/// Rich text with tappable links, each running a [DwUiAction].
class MultiLinkText extends StatefulWidget {
  MultiLinkText.single({
    super.key,
    String? text,
    String? linkText,
    DwUiAction? onLinkTap,
    this.textAlign,
    this.textStyle = AppText.body,
    this.linkStyle = AppText.link,
  }) : parts = [MultiLinkTextPart(text, linkText, onLinkTap)];

  const MultiLinkText.multi({
    required this.parts,
    super.key,
    this.textAlign,
    this.textStyle = AppText.body,
    this.linkStyle = AppText.link,
  });

  final TextAlign? textAlign;
  final List<MultiLinkTextPart> parts;
  final AppText textStyle;
  final AppText linkStyle;

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
    _recognizers = widget.parts.map((e) {
      if (e.linkText != null && e.onLinkTap != null) {
        return TapGestureRecognizer()..onTap = () => e.onLinkTap!.call(context);
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
    final baseStyle = widget.textStyle.resolve(context);
    final linkStyle = widget.linkStyle.resolve(context);

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
