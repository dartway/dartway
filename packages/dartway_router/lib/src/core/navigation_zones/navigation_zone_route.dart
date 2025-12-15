import 'package:dartway_router/dartway_router.dart';

abstract class NavigationZoneRoute implements Enum {
  final NavigationRouteDescriptor descriptor;

  NavigationZoneRoute(this.descriptor);

  String get root;
}

/// Extension on [NavigationZoneRoute] providing computed properties for navigation
extension NavigationZoneRouteExtension on NavigationZoneRoute {
  /// Get the route name for navigation
  ///
  /// Returns either the simple enum name (e.g., 'home') or the full enum path
  /// (e.g., 'AppRoutes.home') based on [DwRouter.skipZoneInRouteNames] setting.
  String get name =>
      DwRouter.skipZoneInRouteNames ? toString().split('.').last : toString();

  /// Get the path segment for this route
  ///
  /// Uses the descriptor's path if available, otherwise falls back to the enum name.
  String get _path => descriptor.path ?? toString().split('.').last;

  /// Get the complete route path for this route
  ///
  /// Constructs the full path including root and path segments.
  /// For root routes, includes the root prefix.
  String get routePath =>
      '${descriptor.parent == null ? '/$root${root != '' && _path != '' ? '/' : ''}' : ''}$_path';

  /// Get the full hierarchical path for this route
  ///
  /// For child routes, includes the full path from root.
  /// For root routes, returns the same as [routePath].
  String get fullPath => descriptor.parent == null
      ? routePath
      : '${descriptor.parent!.fullPath}/$_path';
}
