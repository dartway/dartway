import 'package:adaptive_breakpoints/adaptive_breakpoints.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

extension DwBuildContextExtension on BuildContext {
  ThemeData get theme => Theme.of(this);
  TextTheme get textTheme => Theme.of(this).textTheme;
  ColorScheme get colorScheme => Theme.of(this).colorScheme;

  void popOnTrue(bool value) {
    if (mounted && value) pop();
  }

  void popIfNotNull(dynamic value) {
    if (mounted && value != null) pop();
  }

  void mountedPushNamed(String name) {
    if (mounted) pushNamed(name);
  }

  void mountedGoNamed(String name) {
    if (mounted) goNamed(name);
  }

  static final double _maxMobileScreenWidth =
      (defaultTargetPlatform == TargetPlatform.android ||
              defaultTargetPlatform == TargetPlatform.iOS)
          ? AdaptiveWindowType.medium.widthRangeValues.end
          : AdaptiveWindowType.small.widthRangeValues.end;

  bool get isMobile => MediaQuery.sizeOf(this).width <= _maxMobileScreenWidth;
}
