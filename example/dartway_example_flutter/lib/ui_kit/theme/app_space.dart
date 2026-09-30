part of '../ui_kit.dart';

/// The app's spacing scale: a closed set of steps, each named by its value.
/// A gap or an inset outside the kit is one of these — `Gap(AppSpace.s12)`,
/// `EdgeInsets.all(AppSpace.s16)`, `Row(spacing: AppSpace.s8)` — and a number
/// there fails `dartway check` (`rawSpacing`). A value that belongs to one
/// component rather than to the layout stays inside that component, in the
/// kit.
///
/// Named by value, so a step the design adds goes in between without renaming
/// the others; a value the design does not use does not become a step.
abstract final class AppSpace {
  static const double s2 = 2;
  static const double s4 = 4;
  static const double s6 = 6;
  static const double s8 = 8;
  static const double s10 = 10;
  static const double s12 = 12;
  static const double s16 = 16;
  static const double s20 = 20;
  static const double s24 = 24;
  static const double s28 = 28;
  static const double s32 = 32;
  static const double s36 = 36;
  static const double s48 = 48;
}
