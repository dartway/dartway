import 'package:dartway_flutter/dartway_flutter.dart';
import 'package:flutter/material.dart';

/// Contract for style presets that can be resolved into [TextStyle]
/// in the given [BuildContext].
abstract class DwTextStylePreset {
  const DwTextStylePreset();

  TextStyle resolveStyle(BuildContext context);
}

extension AppTextCallable on DwTextStylePreset {
  Widget call(
    String text, {
    TextAlign? textAlign,
    TextOverflow? overflow,
    int? maxLines,
  }) {
    return DwText(
      text,
      textStyle: this,
      textAlign: textAlign,
      overflow: overflow,
      maxLines: maxLines,
    );
  }
}
