import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Collection of predefined page factories for DartWay Router.
///
/// Provides common transitions (material, fade, slide, scale) with optional
/// parameters for customization.
class DwPageBuilders {
  /// Standard MaterialPage (no transition).
  static Page<dynamic> material(
    BuildContext context,
    LocalKey key,
    Widget child,
  ) {
    return MaterialPage(
      key: key,
      child: child,
    );
  }

  /// Fade transition.
  static Page<dynamic> fade(
    BuildContext context,
    LocalKey key,
    Widget child, {
    Curve curve = Curves.easeInOut,
    Duration duration = const Duration(milliseconds: 300),
  }) {
    return CustomTransitionPage(
      key: key,
      child: child,
      transitionDuration: duration,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: animation.drive(CurveTween(curve: curve)),
          child: child,
        );
      },
    );
  }

  /// Slide transition (from any direction).
  static Page<dynamic> slide(
    BuildContext context,
    LocalKey key,
    Widget child, {
    AxisDirection from = AxisDirection.right,
    Curve curve = Curves.easeInOut,
    Duration duration = const Duration(milliseconds: 300),
  }) {
    final offset = switch (from) {
      AxisDirection.up => const Offset(0, 1),
      AxisDirection.down => const Offset(0, -1),
      AxisDirection.left => const Offset(1, 0),
      AxisDirection.right => const Offset(-1, 0),
    };

    final tween =
        Tween(begin: offset, end: Offset.zero).chain(CurveTween(curve: curve));

    return CustomTransitionPage(
      key: key,
      child: child,
      transitionDuration: duration,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return SlideTransition(
          position: animation.drive(tween),
          child: child,
        );
      },
    );
  }

  /// Scale transition (zoom in/out).
  static Page<dynamic> scale(
    BuildContext context,
    LocalKey key,
    Widget child, {
    Curve curve = Curves.easeInOut,
    Duration duration = const Duration(milliseconds: 300),
  }) {
    return CustomTransitionPage(
      key: key,
      child: child,
      transitionDuration: duration,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return ScaleTransition(
          scale: animation.drive(CurveTween(curve: curve)),
          child: child,
        );
      },
    );
  }
}
