part of '../ui_kit.dart';

/// The app's layout breakpoints, owned here.
///
/// The framework deliberately has no opinion on where "mobile" ends: that is a
/// design decision. Change it in one place and the whole app follows.
abstract final class AppBreakpoints {
  /// Where a mobile *layout* stops making sense — one column, thumb-sized
  /// targets, no side panels.
  static const double mobileMaxWidth = 600;

  /// Where the desktop shell starts wrapping the app in a phone frame.
  ///
  /// A separate number on purpose. These are two different questions, and they
  /// used to ride on one: "is this a mobile layout" and "is this a desktop wide
  /// enough to frame a phone in the middle of it". Sharing a threshold means a
  /// 700px browser window — narrow, but no phone — gets a phone frame drawn
  /// around it.
  static const double deviceFrameMinWidth = 1024;
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
