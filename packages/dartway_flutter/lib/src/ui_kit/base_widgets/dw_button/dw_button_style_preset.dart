import 'package:flutter/material.dart';

/// Contract for style presets that can be resolved into [ButtonStyle]
/// in the given [BuildContext].
abstract class DwButtonStylePreset {
  const DwButtonStylePreset();

  ButtonStyle resolveStyle(BuildContext context);
}
