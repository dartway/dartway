import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../navigation_zones/dw_navigation_route.dart';
import '../navigation_zones/dw_navigation_route_extension.dart';
import 'dw_go_router_options.dart';

class DwRouter<RouterState extends Listenable> {
  DwRouter({
    required this.navigationZones,
    required this.pageBuilder,
    this.routerState,
    this.options = const DwGoRouterOptions(),
  }) {
    _validate();
    _buildRegistry();
    router = _buildRouter();
  }

  // ------------------------------------------------------------
  // Public API
  // ------------------------------------------------------------

  /// Optional router state for refresh notifications.
  ///
  /// When provided, the router will refresh when this [Listenable] notifies
  /// its listeners. This is useful for authentication state changes or other
  /// global state that affects navigation.
  ///
  /// Required when using [zoneGuards] in your routes.
  final RouterState? routerState;

  /// Navigation structure grouped by zones.
  ///
  /// Each inner list represents a navigation zone (e.g., authenticated zone,
  /// public zone). Routes within a zone can share a common shell builder
  /// and guards.
  ///
  /// Example:
  /// ```dart
  /// navigationZones: [
  ///   [AppRoutes.home, AppRoutes.profile],  // Authenticated zone
  ///   [AuthRoutes.login, AuthRoutes.signup], // Public zone
  /// ]
  /// ```
  final List<List<DwNavigationRoute<RouterState>>> navigationZones;

  /// Centralized page builder function for all route transitions.
  ///
  /// This function is called for every route to create a [Page] instance.
  /// It provides a single point of control for all page transitions in the app.
  /// You can use predefined builders from [DwPageBuilder] or create custom ones.
  ///
  /// Example:
  /// ```dart
  /// pageBuilder: DwPageBuilder.fade
  /// ```
  final Page<dynamic> Function(
    BuildContext context,
    LocalKey key,
    Widget child,
  ) pageBuilder;

  /// Runtime configuration options for GoRouter.
  ///
  /// These options are passed directly to the underlying [GoRouter] instance.
  /// See [DwGoRouterOptions] for available options.
  final DwGoRouterOptions options;

  /// The underlying GoRouter instance.
  ///
  /// This is created during initialization and should be passed to
  /// [MaterialApp.router] or [CupertinoApp.router] as the `routerConfig`.
  late final GoRouter router;

  // ------------------------------------------------------------
  // Internal state
  // ------------------------------------------------------------

  /// Internal registry mapping route names to route instances.
  ///
  /// Used for efficient route lookup by name from [GoRouterState].
  final Map<String, DwNavigationRoute<RouterState>> _routeRegistry = {};

  // ------------------------------------------------------------
  // Route resolving API
  // ------------------------------------------------------------

  /// Gets the top-level route from the current navigation state.
  ///
  /// Returns the route that corresponds to the top route in the navigation
  /// stack, or `null` if no matching route is found.
  ///
  /// This is useful for determining which route is currently active at the
  /// top of the navigation stack.
  ///
  /// Example:
  /// ```dart
  /// final currentRoute = router.topRouteFromState(GoRouterState.of(context));
  /// if (currentRoute == AppRoutes.profile) {
  ///   // Handle profile route
  /// }
  /// ```
  DwNavigationRoute<RouterState>? topRouteFromState(
    GoRouterState state,
  ) {
    final name = state.topRoute?.name;
    return name == null ? null : _routeRegistry[name];
  }

  /// Gets the root route (zone root) from the current navigation state.
  ///
  /// Traverses up the route hierarchy to find the root route of the zone.
  /// Returns `null` if the top route cannot be found.
  ///
  /// This is useful for determining which navigation zone is currently active,
  /// which can be helpful for shell builders that need to show different
  /// UI based on the active zone.
  ///
  /// Example:
  /// ```dart
  /// final rootRoute = router.rootRouteFromState(GoRouterState.of(context));
  /// if (rootRoute == AppRoutes.home) {
  ///   // Show authenticated shell
  /// }
  /// ```
  DwNavigationRoute<RouterState>? rootRouteFromState(
    GoRouterState state,
  ) {
    final top = topRouteFromState(state);
    if (top == null) return null;

    DwNavigationRoute<RouterState> route = top;
    while (route.descriptor.parent != null) {
      route = route.descriptor.parent!;
    }
    return route;
  }

  // ------------------------------------------------------------
  // Build GoRouter
  // ------------------------------------------------------------

  /// Builds the underlying GoRouter instance.
  ///
  /// This method constructs a [GoRouter] with all configured routes, options,
  /// and redirect logic. It handles zone guards and custom redirects.
  GoRouter _buildRouter() {
    return GoRouter(
      routes: _buildRoutes(),
      errorBuilder: options.errorBuilder,

      // Pass through all GoRouter options
      navigatorKey: options.navigatorKey,
      initialLocation: options.initialLocation,
      initialExtra: options.initialExtra,
      refreshListenable: routerState,
      redirectLimit: options.redirectLimit,
      routerNeglect: options.routerNeglect,
      debugLogDiagnostics: options.debugLogDiagnostics,
      overridePlatformDefaultLocation: options.overridePlatformDefaultLocation,
      requestFocus: options.requestFocus,
      restorationScopeId: options.restorationScopeId,
      observers: options.observers,
      onException: options.onException,
      extraCodec: options.extraCodec,
      redirect: (context, state) {
        // First, check zone guards
        final targetRoute = topRouteFromState(state);

        if (targetRoute != null &&
            targetRoute.zoneGuards.isNotEmpty &&
            routerState != null) {
          // Execute guards in order until one returns a redirect path
          for (final guard in targetRoute.zoneGuards) {
            final redirectPath = guard(routerState!);
            if (redirectPath != null) {
              return redirectPath;
            }
          }
        }

        // Then check custom redirect from options
        return options.redirect?.call(context, state);
      },
    );
  }

  // ------------------------------------------------------------
  // Build Routes
  // ------------------------------------------------------------

  /// Builds the list of route configurations for GoRouter.
  ///
  /// Processes each navigation zone, creating root routes and wrapping them
  /// in a [ShellRoute] if the zone has a shell builder configured.
  ///
  /// Returns a flat list of [RouteBase] instances that GoRouter can use.
  List<RouteBase> _buildRoutes() {
    return navigationZones
        .map((zone) {
          // Find all root routes in this zone (routes without a parent)
          final rootRoutes = zone
              .where((e) => e.descriptor.parent == null)
              .map(
                (route) => _buildRoute(
                  route,
                  navigationZones,
                ),
              )
              .toList();

          // If zone has no shell builder, return routes directly
          if (zone.first.shellRouteBuilder == null) {
            return rootRoutes;
          }

          // Wrap routes in a ShellRoute if shell builder is configured
          return <RouteBase>[
            ShellRoute(
              pageBuilder: zone.first.shellRouteBuilder!,
              routes: rootRoutes,
            ),
          ];
        })
        .expand((e) => e)
        .toList();
  }

  /// Recursively builds a [GoRoute] from a [DwNavigationRoute].
  ///
  /// Creates a [GoRoute] with the route's path and page builder, then
  /// recursively builds child routes that have this route as their parent.
  ///
  /// [route] - The route to build
  /// [zones] - All navigation zones (needed to find child routes)
  GoRoute _buildRoute(
    DwNavigationRoute<RouterState> route,
    List<List<DwNavigationRoute<RouterState>>> zones,
  ) {
    return GoRoute(
      name: route.name,
      path: route.routePath,
      pageBuilder: (context, state) {
        // Use the centralized page builder with a unique key
        return pageBuilder(
          context,
          ValueKey('${route.name}-${state.uri.path}'),
          route.descriptor.pageWidget,
        );
      },
      // Recursively build child routes
      routes: zones
          .expand(
            (zone) => zone.where((e) => e.descriptor.parent == route).map(
                  (e) => _buildRoute(
                    e,
                    zones,
                  ),
                ),
          )
          .toList(),
    );
  }

  // ------------------------------------------------------------
  // Registry
  // ------------------------------------------------------------

  /// Builds the internal route registry.
  ///
  /// Populates [_routeRegistry] with all routes from all zones, mapping
  /// route names to route instances for efficient lookup.
  void _buildRegistry() {
    for (final zone in navigationZones) {
      for (final route in zone) {
        _routeRegistry[route.name] = route;
      }
    }
  }

  // ------------------------------------------------------------
  // Validation
  // ------------------------------------------------------------

  /// Validates the router configuration.
  ///
  /// Performs comprehensive validation checks:
  /// - Ensures navigation zones are not empty
  /// - Ensures no duplicate route paths
  /// - Ensures no duplicate route names
  /// - Ensures all paths are valid (start with '/')
  /// - Ensures routerState is provided when guards are used
  ///
  /// Throws [ArgumentError] if any validation fails.
  void _validate() {
    // Check that at least one zone exists
    if (navigationZones.isEmpty) {
      throw ArgumentError('navigationZones cannot be empty');
    }

    // Check that no zone is empty
    if (navigationZones.any((zone) => zone.isEmpty)) {
      throw ArgumentError('navigationZones cannot contain empty zones');
    }

    final allRoutes = navigationZones.expand((z) => z).toList();

    // Check for duplicate route paths
    final paths = <String, List<DwNavigationRoute>>{};
    for (final route in allRoutes) {
      paths.putIfAbsent(route.fullPath, () => []).add(route);
    }

    final duplicatePaths = paths.entries.where((e) => e.value.length > 1);
    if (duplicatePaths.isNotEmpty) {
      throw ArgumentError(
        'Duplicate route paths:\n'
        '${duplicatePaths.map((e) => e.key).join('\n')}',
      );
    }

    // Check for duplicate route names
    final names = <String, List<DwNavigationRoute>>{};
    for (final route in allRoutes) {
      names.putIfAbsent(route.name, () => []).add(route);
    }

    final duplicateNames = names.entries.where((e) => e.value.length > 1);
    if (duplicateNames.isNotEmpty) {
      throw ArgumentError(
        'Duplicate route names:\n'
        '${duplicateNames.map((e) => e.key).join('\n')}',
      );
    }

    // Validate that all paths start with '/'
    for (final route in allRoutes) {
      final path =
          route.descriptor.parent == null ? route.routePath : route.fullPath;

      if (!path.startsWith('/')) {
        throw ArgumentError(
          'Invalid route path for ${route.name}: "$path"',
        );
      }
    }

    // Check that routerState is provided when guards are used
    final hasGuards =
        navigationZones.expand((z) => z).any((r) => r.zoneGuards.isNotEmpty);

    if (hasGuards && routerState == null) {
      throw ArgumentError(
        'refreshListenable is required when using zoneGuards',
      );
    }
  }
}
