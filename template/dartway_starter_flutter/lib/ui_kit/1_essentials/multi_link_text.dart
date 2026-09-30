part of '../ui_kit.dart';

class MultiLinkTextPart {
  MultiLinkTextPart(this.text, this.linkText, this.onLinkTap);

  final String? text;
  final String? linkText;
  final DwUiAction? onLinkTap;
}

/// Rich text with tappable links, each running a [DwUiAction].
class MultiLinkText extends HookWidget {
  MultiLinkText.single({
    super.key,
    String? text,
    String? linkText,
    DwUiAction? onLinkTap,
    this.textAlign,
    this.textStyle = AppTextStyle.body,
    this.linkStyle = AppTextStyle.link,
  }) : parts = [MultiLinkTextPart(text, linkText, onLinkTap)];

  const MultiLinkText.multi({
    required this.parts,
    super.key,
    this.textAlign,
    this.textStyle = AppTextStyle.body,
    this.linkStyle = AppTextStyle.link,
  });

  final TextAlign? textAlign;
  final List<MultiLinkTextPart> parts;
  final AppTextStyle textStyle;
  final AppTextStyle linkStyle;

  @override
  Widget build(BuildContext context) {
    // One recognizer per link, made again when the parts change and disposed
    // with the ones they replace.
    final recognizers = useMemoized(
      () => [
        for (final part in parts)
          if (part.onLinkTap case final action? when part.linkText != null)
            TapGestureRecognizer()..onTap = () => action.call(context)
          else
            null,
      ],
      [parts],
    );
    useEffect(
      () => () {
        for (final recognizer in recognizers) {
          recognizer?.dispose();
        }
      },
      [recognizers],
    );

    final baseStyle = textStyle.resolve(context);
    final linkStyle = this.linkStyle.resolve(context);

    return RichText(
      textAlign: textAlign ?? TextAlign.center,
      text: TextSpan(
        style: baseStyle,
        children: [
          ...parts
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
                      recognizer: recognizers[i],
                    ),
                ],
              )
              .expand((sublist) => sublist),
        ],
      ),
    );
  }
}
