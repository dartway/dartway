import 'package:flutter/material.dart';

import 'dw_navigation_route_descriptor.dart';
import 'dw_navigation_types.dart';

/// Abstract base class for navigation routes.
///
/// All navigation routes must implement this interface. Routes are defined
/// as enums that implement [DwNavigationRoute], providing type-safe navigation
/// throughout the application.
///
/// Each route has:
/// - A [descriptor] that defines how the route contributes to the URL path
/// - A [zoneRoot] that identifies the navigation zone this route belongs to
/// - An optional [shellRouteBuilder] for wrapping routes in a shell (e.g., bottom nav)
/// - [zoneGuards] for authentication/authorization checks
///
/// Example:
/// ```dart
/// enum AppRoutes implements DwNavigationRoute<AppSession> {
///   home(DwNavigationRouteDescriptor.zoneRoot(pageWidget: HomePage())),
///   profile(DwNavigationRouteDescriptor.simple(pageWidget: ProfilePage()));
///
///   const AppRoutes(this.descriptor);
///
///   @override
///   final DwNavigationRouteDescriptor<AppSession> descriptor;
///
///   @override
///   String get zoneRoot => '';
///
///   @override
///   DwShellRoutePageBuilder? get shellRouteBuilder => null;
///
///   @override
///   List<DwNavigationGuard<AppSession>> get zoneGuards => [];
/// }
/// ```
///
/// Type parameter [RouterState] must extend [Listenable] and is used for
/// router refresh notifications and guard evaluation.
abstract class DwNavigationRoute<RouterState extends Listenable>
    implements Enum {
  /// Describes how this route contributes to the navigation path.
  ///
  /// The descriptor contains the page widget, parent route (for nested routes),
  /// and path configuration (simple, parameterized, or zone root).
  final DwNavigationRouteDescriptor<RouterState> descriptor;

  /// Creates a navigation route with the given descriptor.
  DwNavigationRoute(this.descriptor);

  /// The root path segment for this navigation zone.
  ///
  /// All routes in the same zone share the same [zoneRoot]. This is typically
  /// an empty string for the main zone, or a path segment like 'app' or 'admin'
  /// for separate zones.
  ///
  /// Example:
  /// - Main zone: `zoneRoot => ''`
  /// - Admin zone: `zoneRoot => 'admin'`
  String get zoneRoot;

  /// Optional shell route builder for this navigation zone.
  ///
  /// If provided, all routes in this zone will be wrapped in a [ShellRoute]
  /// that uses this builder. This is useful for adding common UI elements like
  /// bottom navigation bars, sidebars, or persistent headers.
  ///
  /// Returns `null` if no shell is needed for this zone.
  ///
  /// Example:
  /// ```dart
  /// @override
  /// DwShellRoutePageBuilder? get shellRouteBuilder =>
  ///     (context, state, child) {
  ///       return Scaffold(
  ///         body: child,
  ///         bottomNavigationBar: MyBottomNav(),
  ///       );
  ///     };
  /// ```
  DwShellRoutePageBuilder? get shellRouteBuilder;

  /// List of navigation guards for this route.
  ///
  /// Guards are executed in order when navigating to this route. If any guard
  /// returns a non-null path, the user will be redirected to that path instead.
  ///
  /// Guards receive the [RouterState] instance and can check authentication,
  /// permissions, or any other condition.
  ///
  /// Example:
  /// ```dart
  /// @override
  /// List<DwNavigationGuard<AppSession>> get zoneGuards => [
  ///   (session) => !session.isAuthenticated ? '/login' : null,
  /// ];
  /// ```
  ///
  /// Returns an empty list if no guards are needed.
  List<DwNavigationGuard<RouterState>> get zoneGuards;
}
