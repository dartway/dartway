import 'package:adaptive_breakpoints/adaptive_breakpoints.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

extension DwBuildContextExtension on BuildContext {
  ThemeData get theme => Theme.of(this);
  TextTheme get textTheme => Theme.of(this).textTheme;
  ColorScheme get colorScheme => Theme.of(this).colorScheme;

  static final double _maxMobileScreenWidth =
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS)
      ? AdaptiveWindowType.medium.widthRangeValues.end
      : AdaptiveWindowType.small.widthRangeValues.end;

  bool get isMobile => MediaQuery.sizeOf(this).width <= _maxMobileScreenWidth;
}
