import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'dw_navigation_route.dart';

/// Extension on [DwNavigationRoute] providing computed properties for navigation
extension DwNavigationRouteExtension on DwNavigationRoute {
  /// Get the path segment for this route
  ///
  /// Uses the descriptor's path if available, otherwise falls back to the enum name.
  String get _path => descriptor.path ?? toString().split('.').last;

  /// Get the complete route path for this route
  ///
  /// Constructs the full path including root and path segments.
  /// For root routes, includes the root prefix.
  String get routePath =>
      '${descriptor.parent == null ? '/$zoneRoot${zoneRoot != '' && _path != '' ? '/' : ''}' : ''}$_path';

  /// Get the full hierarchical path for this route
  ///
  /// For child routes, includes the full path from root.
  /// For root routes, returns the same as [routePath].
  String get fullPath => descriptor.parent == null
      ? routePath
      : '${descriptor.parent!.fullPath}/$_path';

  bool isActive(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    return location == fullPath || location.startsWith('$fullPath/');
  }
}
