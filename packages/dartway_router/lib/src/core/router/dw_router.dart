import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../ui/page_transition/dw_page_builder.dart';
import '../navigation_params/navigation_parameters_providers.dart';
import '../navigation_zones/navigation_zone_route.dart';
import 'dw_router_config.dart';

/// Core router class for DartWay Router package.
///
/// Provides static methods for configuring and creating GoRouter instances
/// with validation and error handling.
class DwRouter {
  /// Whether to skip zone names in route names (default: true).
  /// When true, route names will be just the enum value (e.g., 'home').
  /// When false, route names will include the full enum path (e.g., 'AppRoutes.home').
  static bool skipZoneInRouteNames = false;

  static final _routerKey =
      GlobalKey<NavigatorState>(debugLabel: 'dwRouterKey');

  /// Create a new router configuration builder.
  ///
  /// Returns a [DwRouterConfig] instance that can be used to configure
  /// and build a GoRouter with the builder pattern.
  ///
  /// Example:
  /// ```dart
  /// final router = DwRouter.config()
  ///   .addNavigationZones([AppRoutes.values])
  ///   .setPageFactory(DwPageBuilders.fade)
  ///   .build();
  /// ```
  static DwRouterConfig config() => DwRouterConfig();

  /// Configure global router settings
  ///
  /// [skipZoneInRouteNames] - Whether to skip zone names in route names.
  /// When true, route names will be just the enum value (e.g., 'home').
  /// When false, route names will include the full enum path (e.g., 'AppRoutes.home').
  /// it's required when several zones have routes with the same name
  static void configure({
    required bool skipZoneInRouteNames,
  }) {
    DwRouter.skipZoneInRouteNames = skipZoneInRouteNames;
  }

  static Provider<GoRouter> provider(DwRouterConfig config) {
    return Provider<GoRouter>(
      (ref) {
        final redirects = config.redirectsProvider != null
            ? ref.watch(config.redirectsProvider!)
            : null;

        final configWithRedirects = config.withRedirects(redirects);
        return configWithRedirects.build();
      },
      dependencies: config.redirectsProvider != null
          ? [config.redirectsProvider!]
          : const [],
    );
  }

  /// Prepare a GoRouter instance with the given configuration
  ///
  /// This method creates and configures a GoRouter with validation and error handling.
  /// It's used internally by [DwRouterConfig.build()] and should not be called directly.
  ///
  /// [navigationZones] - List of navigation zones, each containing routes
  /// [notFoundPageWidget] - Widget to display when no route matches
  /// [initialLocation] - Initial route path to navigate to
  /// [refreshListenable] - Listenable to trigger router refresh
  /// [redirect] - Function to handle route redirects
  /// [manualRedirect] - Function to handle manual redirects based on GoRouterState
  /// [pageFactory] - Factory for creating page transitions
  static GoRouter prepareRouter({
    required List<List<NavigationZoneRoute>> navigationZones,
    required Widget notFoundPageWidget,
    String? initialLocation,
    Listenable? refreshListenable,
    NavigationZoneRoute? Function(
      BuildContext context,
      NavigationZoneRoute? route,
    )? redirect,
    NavigationZoneRoute? Function(
      BuildContext context,
      GoRouterState state,
    )? manualRedirect,
    required DwPageBuilder pageFactory,
  }) {
    // Validate input parameters
    _validateNavigationZones(navigationZones);
    return GoRouter(
      navigatorKey: _routerKey,
      debugLogDiagnostics: true,
      errorBuilder: (context, state) {
        debugPrint('DwRouter error with path ${state.fullPath}');
        return notFoundPageWidget;
      },
      routerNeglect: true,
      initialLocation: initialLocation ?? navigationZones.first.first.routePath,
      routes: <GoRoute>[
        ...navigationZones
            .map(
              (zone) => zone.where((e) => e.descriptor.parent == null).map(
                    (route) => _buildRoute(
                      route,
                      navigationZones,
                      pageFactory: pageFactory,
                    ),
                  ),
            )
            .expand((element) => element),
      ],
      refreshListenable: refreshListenable,
      redirect: (context, state) {
        if (manualRedirect != null) {
          final route = manualRedirect(context, state);
          if (route != null) return route.routePath;
        }

        if (redirect != null) {
          final currentRoute = _getCurrentRoute(
            state.uri,
            navigationZones.expand((e) => e),
          );

          final res = redirect(context, currentRoute)?.routePath;

          return res;
        }
        return null;
      },
    );
  }

  static GoRoute _buildRoute(
    NavigationZoneRoute route,
    List<List<NavigationZoneRoute>> zones, {
    required DwPageBuilder pageFactory,
  }) {
    return GoRoute(
      path: route.routePath,
      name: route.name,
      pageBuilder: (context, state) {
        final child = ProviderScope(
          overrides: [
            navigationPathParametersProvider.overrideWithValue(
              state.pathParameters,
            ),
            navigationExtraParameterProvider.overrideWithValue(
              state.extra,
            ),
          ],
          child: route.descriptor.page,
        );

        return pageFactory(
          context,
          ValueKey('${route.name}-${state.fullPath}'),
          child,
        );
      },
      routes: zones
          .map((zone) => zone
              .where((e) => e.descriptor.parent == route)
              .map((e) => _buildRoute(e, zones, pageFactory: pageFactory)))
          .expand((x) => x)
          .toList(),
    );
  }

  static _getCurrentRoute(
    Uri currentUri,
    Iterable<NavigationZoneRoute> navigationRoutes,
  ) {
    final urlSections = currentUri.toString().split('?')[0].split('/');
    final currentRoute = navigationRoutes.firstWhere(
      (element) {
        final routeSections = element.fullPath.split('/');

        for (var i = 0; i < urlSections.length; i++) {
          if (i >= routeSections.length) {
            return false;
          }
          if (routeSections[i].startsWith(':') ||
              urlSections[i] == routeSections[i]) {
            continue;
          } else {
            return false;
          }
        }

        return true;
      },
    );

    return currentRoute;
  }

  /// Validate navigation zones for common issues
  static void _validateNavigationZones(
      List<List<NavigationZoneRoute>> navigationZones) {
    if (navigationZones.isEmpty) {
      throw ArgumentError('Navigation zones cannot be empty');
    }

    if (navigationZones.any((zone) => zone.isEmpty)) {
      throw ArgumentError('Navigation zones cannot contain empty zones');
    }

    // Check for duplicate route paths
    final allRoutes = navigationZones.expand((zone) => zone).toList();
    final routePaths = <String, List<NavigationZoneRoute>>{};

    for (final route in allRoutes) {
      final path = route.fullPath;
      routePaths.putIfAbsent(path, () => []).add(route);
    }

    final duplicatePaths = routePaths.entries
        .where((entry) => entry.value.length > 1)
        .map((entry) =>
            '${entry.key}: ${entry.value.map((r) => r.name).join(', ')}')
        .toList();

    if (duplicatePaths.isNotEmpty) {
      throw ArgumentError(
          'Duplicate route paths found:\n${duplicatePaths.join('\n')}');
    }

    // Check for invalid route paths
    for (final route in allRoutes) {
      final pathToCheck =
          route.descriptor.parent == null ? route.routePath : route.fullPath;
      if (pathToCheck.isEmpty || !pathToCheck.startsWith('/')) {
        throw ArgumentError(
            'Invalid route path for ${route.name}: "$pathToCheck". Route paths must start with "/"');
      }
    }
  }
}
