import 'package:flutter/material.dart';

/// Contract for color presets that can be resolved into [Color]
/// in the given [BuildContext].
abstract class DwColorPreset {
  const DwColorPreset();

  Color resolveColor(BuildContext context);
}
