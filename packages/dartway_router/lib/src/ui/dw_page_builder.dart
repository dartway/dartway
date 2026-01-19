import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Collection of predefined page factories for DartWay Router.
///
/// Provides common page transition animations (material, fade, slide, scale)
/// with customizable parameters. These builders can be used as the [pageBuilder]
/// parameter when creating a [DwRouter].
///
/// All transition builders accept optional [curve] and [duration] parameters
/// for customization. The default transition duration is 300 milliseconds.
///
/// Example:
/// ```dart
/// final router = DwRouter(
///   navigationZones: [routes],
///   pageBuilder: DwPageBuilder.fade,
/// );
///
/// // Or with custom duration:
/// pageBuilder: (context, key, child) =>
///     DwPageBuilder.fade(context, key, child, duration: Duration(milliseconds: 500)),
/// ```
class DwPageBuilder {
  /// Default duration for page transitions.
  ///
  /// Used by fade, slide, and scale transitions when no custom duration
  /// is provided.
  static const Duration defaultTransitionDuration = Duration(milliseconds: 300);

  /// Creates a standard MaterialPage with no transition animation.
  ///
  /// This is the default page type used by Material Design apps. It provides
  /// the standard platform navigation behavior without custom animations.
  ///
  /// Example:
  /// ```dart
  /// pageBuilder: DwPageBuilder.material
  /// ```
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

  /// Creates a page with a fade transition animation.
  ///
  /// The page fades in when entering and fades out when leaving.
  ///
  /// [curve] - The animation curve (default: [Curves.easeInOut])
  /// [duration] - The transition duration (default: [defaultTransitionDuration])
  ///
  /// Example:
  /// ```dart
  /// pageBuilder: DwPageBuilder.fade
  ///
  /// // Or with custom parameters:
  /// pageBuilder: (context, key, child) =>
  ///     DwPageBuilder.fade(
  ///       context,
  ///       key,
  ///       child,
  ///       curve: Curves.easeOut,
  ///       duration: Duration(milliseconds: 500),
  ///     ),
  /// ```
  static Page<dynamic> fade(
    BuildContext context,
    LocalKey key,
    Widget child, {
    Curve curve = Curves.easeInOut,
    Duration duration = defaultTransitionDuration,
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

  /// Creates a page with a slide transition animation.
  ///
  /// The page slides in from the specified direction when entering and
  /// slides out in the opposite direction when leaving.
  ///
  /// [from] - The direction to slide from (default: [AxisDirection.right])
  /// [curve] - The animation curve (default: [Curves.easeInOut])
  /// [duration] - The transition duration (default: [defaultTransitionDuration])
  ///
  /// Example:
  /// ```dart
  /// pageBuilder: DwPageBuilder.slide
  ///
  /// // Or slide from bottom:
  /// pageBuilder: (context, key, child) =>
  ///     DwPageBuilder.slide(
  ///       context,
  ///       key,
  ///       child,
  ///       from: AxisDirection.bottom,
  ///     ),
  /// ```
  static Page<dynamic> slide(
    BuildContext context,
    LocalKey key,
    Widget child, {
    AxisDirection from = AxisDirection.right,
    Curve curve = Curves.easeInOut,
    Duration duration = defaultTransitionDuration,
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

  /// Creates a page with a scale (zoom) transition animation.
  ///
  /// The page scales from small to full size when entering and scales down
  /// when leaving, creating a zoom effect.
  ///
  /// [curve] - The animation curve (default: [Curves.easeInOut])
  /// [duration] - The transition duration (default: [defaultTransitionDuration])
  ///
  /// Example:
  /// ```dart
  /// pageBuilder: DwPageBuilder.scale
  ///
  /// // Or with custom parameters:
  /// pageBuilder: (context, key, child) =>
  ///     DwPageBuilder.scale(
  ///       context,
  ///       key,
  ///       child,
  ///       curve: Curves.elasticOut,
  ///       duration: Duration(milliseconds: 600),
  ///     ),
  /// ```
  static Page<dynamic> scale(
    BuildContext context,
    LocalKey key,
    Widget child, {
    Curve curve = Curves.easeInOut,
    Duration duration = defaultTransitionDuration,
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
