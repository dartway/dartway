import 'package:dartway_flutter/dartway_flutter.dart';
import 'package:flutter/material.dart';

// extension DwTextStylePresetExtension on DwTextStylePreset {
//   Widget call(
//     String text, {
//     TextAlign? textAlign,
//     int? maxLines,
//     TextOverflow? overflow,
//     bool? softWrap,
//   }) => DwText(
//     text,
//     textStyle: this,
//     textAlign: textAlign,
//     maxLines: maxLines,
//     overflow: overflow,
//     softWrap: softWrap,
//   );
// }

class DwText extends StatelessWidget {
  final String text;
  final DwTextStylePreset textStyle;

  // Common text options
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;
  final bool? softWrap;

  // Base private constructor — fields are the same for all styles.
  // Style constructors remain const.
  const DwText(
    this.text, {
    required this.textStyle,
    this.textAlign,
    this.maxLines,
    this.overflow,
    this.softWrap,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: textStyle.resolveStyle(context),
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: overflow,
      softWrap: softWrap,
    );
  }
}
