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
/// - An optional [shellRouteBuilder] or [statefulShellRouteBuilder] for wrapping
///   routes in a shell (e.g., bottom nav)
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
///   DwStatefulShellRouteBuilder? get statefulShellRouteBuilder => null;
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
  /// Creates a navigation route with the given descriptor.
  DwNavigationRoute(this.descriptor);

  /// Describes how this route contributes to the navigation path.
  ///
  /// The descriptor contains the page widget, parent route (for nested routes),
  /// and path configuration (simple, parameterized, or zone root).
  final DwNavigationRouteDescriptor<RouterState> descriptor;

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

  // ---------------------------------------------------------------------------
  // Shell builders
  // ---------------------------------------------------------------------------

  /// Optional simple shell builder for this zone.
  ///
  /// When non-null, all routes in this zone are wrapped in a [ShellRoute].
  /// This is useful for adding a persistent UI (bottom nav, sidebar) around
  /// routes. **Navigation state is not preserved** when switching tabs — the
  /// route is rebuilt each time.
  ///
  /// For state-preserving tabs use [statefulShellRouteBuilder] instead.
  /// If both are non-null, [statefulShellRouteBuilder] takes precedence.
  ///
  /// Returns `null` if no shell is needed.
  ///
  /// Example:
  /// ```dart
  /// @override
  /// DwShellRoutePageBuilder? get shellRouteBuilder =>
  ///     (context, state, child) => MaterialPage(
  ///       child: Scaffold(body: child, bottomNavigationBar: MyBottomNav()),
  ///     );
  /// ```
  DwShellRoutePageBuilder? get shellRouteBuilder;

  /// Optional stateful shell builder for this zone.
  ///
  /// When non-null, root routes in this zone are wrapped in a
  /// [StatefulShellRoute] where **each root route is an independent navigation
  /// branch**. The navigator stack of every branch (tab) is preserved across
  /// tab switches — unlike [shellRouteBuilder].
  ///
  /// The builder receives a [StatefulNavigationShell] instead of a plain child
  /// widget:
  /// - [StatefulNavigationShell.currentIndex] — active branch index
  /// - [StatefulNavigationShell.goBranch] — switch to a branch by index
  /// - The shell itself is the body widget
  ///
  /// If both builders are non-null, this one takes precedence.
  ///
  /// Example:
  /// ```dart
  /// @override
  /// DwStatefulShellRouteBuilder? get statefulShellRouteBuilder =>
  ///     (context, state, navigationShell) => MaterialPage(
  ///       child: Scaffold(
  ///         body: navigationShell,
  ///         bottomNavigationBar: BottomNavigationBar(
  ///           currentIndex: navigationShell.currentIndex,
  ///           onTap: (i) => navigationShell.goBranch(
  ///             i, initialLocation: i == navigationShell.currentIndex,
  ///           ),
  ///           items: const [
  ///             BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
  ///             BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
  ///           ],
  ///         ),
  ///       ),
  ///     );
  /// ```
  DwStatefulShellRouteBuilder? get statefulShellRouteBuilder;

  // ---------------------------------------------------------------------------
  // Guards
  // ---------------------------------------------------------------------------

  /// Navigation guards executed before entering any route in this zone.
  ///
  /// Guards run in order. If one returns a non-null path the user is redirected
  /// there instead. Return `null` to allow navigation to proceed.
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
