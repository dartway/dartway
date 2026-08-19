import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'dw_navigation_route.dart';

/// Extension on [DwNavigationRoute] providing computed properties for navigation.
///
/// This extension adds convenient properties and methods for working with
/// navigation routes, including path computation and active route detection.
extension DwNavigationRouteExtension on DwNavigationRoute {
  /// Gets the path segment contributed by this route.
  ///
  /// This is the relative path segment for this route, computed by calling
  /// [DwNavigationRouteDescriptor.pathSegment] with the route's enum name.
  ///
  /// For zone root routes, this returns an empty string.
  /// For simple routes, this returns the route name.
  /// For parameterized routes, this returns the parameter pattern (e.g., ':userId').
  String get _path => descriptor.pathSegment(toString().split('.').last);

  /// Gets the route path for this route.
  ///
  /// For root routes (routes without a parent), this returns the full path
  /// from the zone root, including the zone root prefix.
  ///
  /// For child routes (routes with a parent), this returns only the relative
  /// path segment, not including the parent's path.
  ///
  /// Examples:
  /// - Zone root route: `routePath => '/'`
  /// - Simple root route: `routePath => '/profile'`
  /// - Child route: `routePath => ':userId'` (not '/parent/:userId')
  ///
  /// Use [fullPath] to get the complete path from root for child routes.
  String get routePath =>
      '${descriptor.parent == null ? '/$zoneRoot${zoneRoot != '' && _path != '' ? '/' : ''}' : ''}$_path';

  /// Gets the full hierarchical path for this route from the root.
  ///
  /// This always returns the complete path from the zone root, regardless
  /// of whether the route is a root route or a child route.
  ///
  /// For root routes, this returns the same value as [routePath].
  /// For child routes, this includes the full path from the root, traversing
  /// up the parent chain.
  ///
  /// Examples:
  /// - Zone root route: `fullPath => '/'`
  /// - Simple root route: `fullPath => '/profile'`
  /// - Child route with parent: `fullPath => '/:userId'` (includes parent path)
  /// - Nested route: `fullPath => '/extra/nested'` (includes all parent segments)
  ///
  /// This property handles path concatenation intelligently to avoid double
  /// slashes when the parent path ends with '/'.
  String get fullPath {
    if (descriptor.parent == null) {
      return routePath;
    }
    final parentPath = descriptor.parent!.fullPath;
    // Avoid double slashes when parent path ends with '/' and _path doesn't start with '/'
    if (parentPath == '/' || parentPath.endsWith('/')) {
      return '$parentPath$_path';
    }
    return '$parentPath/$_path';
  }

  /// Checks if this route is currently active in the navigation stack.
  ///
  /// Returns `true` when the current location is this route's own address, or
  /// an address nested under it — a parent route stays active while one of its
  /// children is on screen, which is what keeps a navigation item highlighted
  /// on a nested page.
  ///
  /// Path parameters are resolved before the comparison: [fullPath] is a
  /// template (`/project/:projectId/issues`) while the location is a concrete
  /// address (`/project/7/issues`), so every `:param` segment is compared
  /// against [GoRouterState.pathParameters] instead of being matched
  /// literally. A parameter the current location does not carry leaves the
  /// route inactive — its value is unknown, so this route cannot be the open
  /// one.
  ///
  /// The comparison runs per path segment, so a route is never active merely
  /// because its path is a string prefix of the location: `/news` is not
  /// active at `/newsletter`.
  ///
  /// A zone root with an empty path (`/`) is active at its own address only,
  /// never as the ancestor of every route in its zone.
  ///
  /// Example:
  /// ```dart
  /// if (AppRoutes.profile.isActive(context)) {
  ///   // Show active state in UI
  /// }
  /// ```
  ///
  /// This is useful for highlighting active items in navigation menus or
  /// bottom navigation bars.
  bool isActive(BuildContext context) {
    final state = GoRouterState.of(context);
    final location = state.uri.pathSegments;
    final template = fullPath
        .split('/')
        .where((segment) => segment.isNotEmpty)
        .toList();

    if (template.isEmpty) return location.isEmpty;
    if (template.length > location.length) return false;

    for (var i = 0; i < template.length; i++) {
      final segment = template[i];
      final expected = segment.startsWith(':')
          ? state.pathParameters[segment.substring(1)]
          : segment;

      if (expected != location[i]) return false;
    }

    return true;
  }
}
