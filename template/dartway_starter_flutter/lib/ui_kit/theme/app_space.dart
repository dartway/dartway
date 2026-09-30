part of '../ui_kit.dart';

/// The app's one spacing scale. A gap or an inset outside the kit is one of
/// these — `Gap(AppSpace.m)`, `EdgeInsets.all(AppSpace.l)`,
/// `EdgeInsets.symmetric(horizontal: AppSpace.l)` — and a number there fails
/// `dartway check` (`rawSpacing`). A value that belongs to one component
/// rather than to the layout stays inside that component, in the kit.
///
/// Change a step here and the whole app moves with it; add a step only when
/// the design has one, since a scale with every value on it is no scale.
abstract final class AppSpace {
  static const double xxs = 2;
  static const double xs = 4;
  static const double s = 8;
  static const double m = 12;
  static const double l = 16;
  static const double xl = 24;
  static const double xxl = 32;
}
