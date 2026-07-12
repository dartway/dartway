part of '../ui_kit.dart';

/// The app's layout breakpoints — a single number, owned here.
///
/// The framework deliberately has no opinion on where "mobile" ends: that is a
/// design decision. Change it in one place and the whole app follows.
abstract final class AppBreakpoints {
  static const double mobileMaxWidth = 600;
}

/// Theme shortcuts. `dartway_lints` allows raw theme access only inside
/// `ui_kit/`, which is exactly where these live.
extension AppBuildContextX on BuildContext {
  ThemeData get theme => Theme.of(this);
  TextTheme get textTheme => Theme.of(this).textTheme;
  ColorScheme get colorScheme => Theme.of(this).colorScheme;

  bool get isMobile =>
      MediaQuery.sizeOf(this).width <= AppBreakpoints.mobileMaxWidth;
}
