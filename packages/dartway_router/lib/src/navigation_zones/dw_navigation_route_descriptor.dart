import 'package:flutter/material.dart';

import 'dw_navigation_params_mixin.dart';
import 'dw_navigation_route.dart';

/// Declarative descriptor of a navigation route.
///
/// Describes *how* a route contributes to the final URL path. The descriptor
/// defines the page widget, parent relationship (for nested routes), and
/// path configuration (simple, parameterized, or zone root).
///
/// There are three types of route descriptors:
/// 1. **Zone Root** - The root route of a navigation zone (contributes empty path)
/// 2. **Simple** - A route without parameters (contributes route name as path)
/// 3. **Parameterized** - A route with path parameters (contributes parameter pattern)
///
/// Descriptors are created using factory constructors:
/// - [DwNavigationRouteDescriptor.zoneRoot] - For zone root routes
/// - [DwNavigationRouteDescriptor.simple] - For simple routes
/// - [DwNavigationRouteDescriptor.parameterized] - For routes with parameters
///
/// Example:
/// ```dart
/// enum AppRoutes implements DwNavigationRoute<AppSession> {
///   home(DwNavigationRouteDescriptor.zoneRoot(pageWidget: HomePage())),
///   profile(DwNavigationRouteDescriptor.simple(pageWidget: ProfilePage())),
///   userDetail(
///     DwNavigationRouteDescriptor.parameterized(
///       pageWidget: UserDetailPage(),
///       parameter: AppParams.userId,
///       parent: home,
///     ),
///   );
/// }
/// ```
abstract class DwNavigationRouteDescriptor<RouterState extends Listenable> {
  /// Internal constructor for route descriptors.
  ///
  /// Use the factory constructors instead:
  /// - [DwNavigationRouteDescriptor.zoneRoot]
  /// - [DwNavigationRouteDescriptor.simple]
  /// - [DwNavigationRouteDescriptor.parameterized]
  const DwNavigationRouteDescriptor._({
    required this.pageWidget,
    this.parent,
    this.extraPathSegment,
  });

  /// The page widget to display when this route is active.
  ///
  /// This widget is wrapped in a [Page] using the router's [pageBuilder]
  /// function, which applies transitions and other page-level configuration.
  final Widget pageWidget;

  /// Parent navigation route for nested routes.
  ///
  /// If provided, this route is a child of the parent route. The parent's
  /// path will be included in this route's full path.
  ///
  /// Set to `null` for root routes (routes at the top level of a zone).
  final DwNavigationRoute<RouterState>? parent;

  /// Optional static path segment placed before the core path segment.
  ///
  /// This allows you to add a static prefix to a route's path. For example,
  /// if you want a route to be at `/users/:userId` instead of just `/:userId`,
  /// you can set `extraPathSegment: 'users'`.
  ///
  /// Not allowed for zone root routes (they always have an empty path).
  ///
  /// Example:
  /// ```dart
  /// DwNavigationRouteDescriptor.parameterized(
  ///   pageWidget: UserDetailPage(),
  ///   parameter: AppParams.userId,
  ///   parent: home,
  ///   extraPathSegment: 'users', // Results in path: 'users/:userId'
  /// )
  /// ```
  final String? extraPathSegment;

  /// Builds the path segment contributed by this route.
  ///
  /// This method is called with the route's enum name and should return
  /// the path segment that this route contributes to the URL. The actual
  /// implementation depends on the route type:
  /// - Zone root: returns empty string
  /// - Simple: returns route name (or with extraPathSegment)
  /// - Parameterized: returns parameter pattern (e.g., ':userId')
  ///
  /// [routeName] - The name of the route (from the enum)
  String pathSegment(String routeName);

  /// Helper method to combine [extraPathSegment] with the core segment.
  ///
  /// If [extraPathSegment] is provided, returns `'$extraPathSegment/$coreSegment'`.
  /// Otherwise, returns [coreSegment] as-is.
  ///
  /// This is used internally by simple and parameterized route descriptors
  /// to build their path segments.
  @protected
  String buildPathSegment(String coreSegment) {
    if (extraPathSegment == null) return coreSegment;

    return '$extraPathSegment/$coreSegment';
  }

  // ---------------------------------------------------------------------------
  // Factory constructors (public DSL)
  // ---------------------------------------------------------------------------

  /// Creates a zone root route descriptor.
  ///
  /// Zone root routes are the entry points of navigation zones. They
  /// contribute an empty path segment, making them accessible at the zone's
  /// root path (typically `/`).
  ///
  /// Zone root routes cannot have a parent or extraPathSegment.
  ///
  /// Example:
  /// ```dart
  /// home(DwNavigationRouteDescriptor.zoneRoot(pageWidget: HomePage()))
  /// ```
  ///
  /// This creates a route accessible at `/` (assuming zoneRoot is empty).
  const factory DwNavigationRouteDescriptor.zoneRoot({
    required Widget pageWidget,
  }) = _ZoneRootRouteDescriptor;

  /// Creates a simple route descriptor without parameters.
  ///
  /// Simple routes contribute their enum name as the path segment. They can
  /// optionally have a parent route (for nesting) and an extraPathSegment.
  ///
  /// Example:
  /// ```dart
  /// profile(DwNavigationRouteDescriptor.simple(pageWidget: ProfilePage()))
  /// ```
  ///
  /// This creates a route accessible at `/profile`.
  ///
  /// With parent:
  /// ```dart
  /// settings(
  ///   DwNavigationRouteDescriptor.simple(
  ///     pageWidget: SettingsPage(),
  ///     parent: home,
  ///   ),
  /// )
  /// ```
  ///
  /// This creates a route accessible at `/settings` (relative to parent).
  const factory DwNavigationRouteDescriptor.simple({
    required Widget pageWidget,
    DwNavigationRoute<RouterState>? parent,
    String? extraPathSegment,
  }) = _SimpleRouteDescriptor<RouterState>;

  /// Creates a parameterized route descriptor with a path parameter.
  ///
  /// Parameterized routes include a dynamic parameter in their path, such as
  /// a user ID or item ID. The parameter is defined using [DwNavigationParamsMixin].
  ///
  /// Parameterized routes must have a parent route (they cannot be root routes).
  ///
  /// Example:
  /// ```dart
  /// userDetail(
  ///   DwNavigationRouteDescriptor.parameterized(
  ///     pageWidget: UserDetailPage(),
  ///     parameter: AppParams.userId,
  ///     parent: home,
  ///   ),
  /// )
  /// ```
  ///
  /// This creates a route accessible at `/:userId` (relative to parent).
  ///
  /// With extraPathSegment:
  /// ```dart
  /// userDetail(
  ///   DwNavigationRouteDescriptor.parameterized(
  ///     pageWidget: UserDetailPage(),
  ///     parameter: AppParams.userId,
  ///     parent: home,
  ///     extraPathSegment: 'users',
  ///   ),
  /// )
  /// ```
  ///
  /// This creates a route accessible at `/users/:userId`.
  const factory DwNavigationRouteDescriptor.parameterized({
    required Widget pageWidget,
    required DwNavigationParamsMixin parameter,
    required DwNavigationRoute<RouterState>? parent,
    String? extraPathSegment,
  }) = _ParameterizedRouteDescriptor<RouterState>;
}

// -----------------------------------------------------------------------------
// Zone root implementation
// -----------------------------------------------------------------------------

/// Internal implementation of zone root route descriptor.
///
/// Zone root routes always contribute an empty path segment, making them
/// accessible at the zone's root path.
class _ZoneRootRouteDescriptor<RouterState extends Listenable>
    extends DwNavigationRouteDescriptor<RouterState> {
  const _ZoneRootRouteDescriptor({
    required super.pageWidget,
  }) : super._(
          extraPathSegment: null,
        );

  @override
  String pathSegment(String routeName) => '';
}

// -----------------------------------------------------------------------------
// Simple route implementation
// -----------------------------------------------------------------------------

/// Internal implementation of simple route descriptor.
///
/// Simple routes contribute their enum name as the path segment, optionally
/// prefixed with an extraPathSegment.
class _SimpleRouteDescriptor<RouterState extends Listenable>
    extends DwNavigationRouteDescriptor<RouterState> {
  const _SimpleRouteDescriptor({
    required super.pageWidget,
    super.parent,
    super.extraPathSegment,
  }) : super._();

  @override
  String pathSegment(String routeName) => buildPathSegment(routeName);
}

// -----------------------------------------------------------------------------
// Parameterized route implementation
// -----------------------------------------------------------------------------

/// Internal implementation of parameterized route descriptor.
///
/// Parameterized routes contribute a parameter pattern (e.g., ':userId')
/// as their path segment, optionally prefixed with an extraPathSegment.
class _ParameterizedRouteDescriptor<RouterState extends Listenable>
    extends DwNavigationRouteDescriptor<RouterState> {
  const _ParameterizedRouteDescriptor({
    required super.pageWidget,
    required super.parent,
    required this.parameter,
    super.extraPathSegment,
  }) : super._();

  /// The parameter mixin that defines the parameter name and type.
  final DwNavigationParamsMixin parameter;

  @override
  String pathSegment(String routeName) =>
      buildPathSegment(':${parameter.name}');
}
