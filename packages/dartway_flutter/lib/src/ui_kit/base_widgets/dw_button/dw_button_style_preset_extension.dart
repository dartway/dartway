import 'package:dartway_flutter/dartway_flutter.dart';
import 'package:flutter/material.dart';

extension DwButtonStylePresetExtension on DwButtonStylePreset {
  Widget text(
    String label, {
    required DwUiAction<dynamic>? dwCallback,
    Widget? leading,
    Widget? trailing,
    bool showProgress = true,
    double? width,
    double? height,
    bool unfocusOnTap = true,
    bool requireValidation = false,
  }) => DwButton(
    Text(label),
    stylePreset: this,
    dwCallback: dwCallback,
    leading: leading,
    trailing: trailing,
    showProgress: showProgress,
    width: width,
    height: height,
    unfocusOnTap: unfocusOnTap,
    requireValidation: requireValidation,
  );

  Widget custom(
    Widget body, {
    required DwUiAction<dynamic> dwCallback,
    Widget? leading,
    Widget? trailing,
    bool showProgress = true,
    double? width,
    double? height,
    bool unfocusOnTap = true,
    bool requireValidation = false,
  }) => DwButton(
    body,
    stylePreset: this,
    dwCallback: dwCallback,
    leading: leading,
    trailing: trailing,
    showProgress: showProgress,
    width: width,
    height: height,
    unfocusOnTap: unfocusOnTap,
    requireValidation: requireValidation,
  );
}
