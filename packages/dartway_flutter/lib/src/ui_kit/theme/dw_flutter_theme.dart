import 'package:dartway_flutter/dartway_flutter.dart';
import 'default_styling/dw_default_text_style_presets.dart';
import '../base_widgets/dw_button/private/dw_default_button_style_presets.dart';
import 'package:flutter/material.dart';

@immutable
class DwFlutterTheme extends ThemeExtension<DwFlutterTheme> {
  const DwFlutterTheme({
    required this.multiLinkText,
    required this.multiLinkTextLink,
    required this.primaryButton,
    required this.secondaryButton,
    required this.textButton,
  });

  final DwTextStylePreset multiLinkText;
  final DwTextStylePreset multiLinkTextLink;
  final DwButtonStylePreset primaryButton;
  final DwButtonStylePreset secondaryButton;
  final DwButtonStylePreset textButton;

  @override
  DwFlutterTheme copyWith({
    DwTextStylePreset? multiLinkText,
    DwTextStylePreset? multiLinkTextLink,
    DwButtonStylePreset? primaryButton,
    DwButtonStylePreset? secondaryButton,
    DwButtonStylePreset? textButton,
  }) {
    return DwFlutterTheme(
      multiLinkText: multiLinkText ?? this.multiLinkText,
      multiLinkTextLink: multiLinkTextLink ?? this.multiLinkTextLink,
      primaryButton: primaryButton ?? this.primaryButton,
      secondaryButton: secondaryButton ?? this.secondaryButton,
      textButton: textButton ?? this.textButton,
    );
  }

  @override
  DwFlutterTheme lerp(ThemeExtension<DwFlutterTheme>? other, double t) {
    if (other is! DwFlutterTheme) return this;

    return copyWith(
      multiLinkText: other.multiLinkText,
      multiLinkTextLink: other.multiLinkTextLink,
      primaryButton: other.primaryButton,
      secondaryButton: other.secondaryButton,
      textButton: other.textButton,
    );
  }

  static const fallback = DwFlutterTheme(
    multiLinkText: DwDefaultTextStyle.multiLinkText,
    multiLinkTextLink: DwDefaultTextStyle.multiLinkTextLink,
    primaryButton: DwDefaultButtonStylePreset.primary,
    secondaryButton: DwDefaultButtonStylePreset.secondary,
    textButton: DwDefaultButtonStylePreset.text,
  );
}
