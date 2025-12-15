import 'package:dartway_flutter/dartway_flutter.dart';
import 'package:flutter/material.dart';

import 'dw_default_button_style_presets.dart';

enum DwDefaultButtonType {
  primary,
  secondary,
  text;

  DwButtonStylePreset resolvePreset(BuildContext context) {
    DwButtonStylePreset buttonStyle;

    final theme = Theme.of(context).extension<DwFlutterTheme>();

    switch (this) {
      case DwDefaultButtonType.primary:
        buttonStyle =
            theme?.primaryButton ?? DwDefaultButtonStylePreset.primary;
        break;
      case DwDefaultButtonType.secondary:
        buttonStyle =
            theme?.secondaryButton ?? DwDefaultButtonStylePreset.secondary;
        break;
      case DwDefaultButtonType.text:
        buttonStyle = theme?.textButton ?? DwDefaultButtonStylePreset.text;
        break;
    }

    return buttonStyle;
  }
}
