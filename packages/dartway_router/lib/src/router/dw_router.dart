import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../navigation_zones/dw_navigation_route.dart';
import '../navigation_zones/dw_navigation_route_extension.dart';
import 'dw_go_router_options.dart';

class DwRouter<NavigationNotifier extends Listenable> {
  DwRouter({
    required this.navigationZones,
    required this.pageBuilder,
    this.refreshListenable,
    this.options = const DwGoRouterOptions(),
  }) {
    _validate();
    _buildRegistry();
    router = _buildRouter();
  }

  // ------------------------------------------------------------
  // Public API
  // ------------------------------------------------------------

  final NavigationNotifier? refreshListenable;

  /// Navigation structure grouped by zones
  final List<List<DwNavigationRoute<NavigationNotifier>>> navigationZones;

  /// ЕДИНАЯ точка транзишнов
  final Page<dynamic> Function(
    BuildContext context,
    LocalKey key,
    Widget child,
  ) pageBuilder;

  /// Runtime options
  final DwGoRouterOptions options;

  /// GoRouter instance (передаётся в MaterialApp.router)
  late final GoRouter router;

  // ------------------------------------------------------------
  // Internal state
  // ------------------------------------------------------------

  final Map<String, DwNavigationRoute<NavigationNotifier>> _routeRegistry = {};

  // ------------------------------------------------------------
  // Route resolving API
  // ------------------------------------------------------------

  DwNavigationRoute<NavigationNotifier>? topRouteFromState(
    GoRouterState state,
  ) {
    final name = state.topRoute?.name;
    return name == null ? null : _routeRegistry[name];
  }

  DwNavigationRoute<NavigationNotifier>? rootRouteFromState(
    GoRouterState state,
  ) {
    final top = topRouteFromState(state);
    if (top == null) return null;

    DwNavigationRoute<NavigationNotifier> route = top;
    while (route.descriptor.parent != null) {
      route = route.descriptor.parent! as DwNavigationRoute<NavigationNotifier>;
    }
    return route;
  }

  // ------------------------------------------------------------
  // Build GoRouter
  // ------------------------------------------------------------

  GoRouter _buildRouter() {
    return GoRouter(
      routes: _buildRoutes(),
      errorBuilder: options.errorBuilder,

      // options
      navigatorKey: options.navigatorKey,
      initialLocation: options.initialLocation,
      initialExtra: options.initialExtra,
      refreshListenable: refreshListenable,
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
        final targetRoute = topRouteFromState(state);

        if (targetRoute != null &&
            targetRoute.zoneGuards.isNotEmpty &&
            refreshListenable != null) {
          for (final guard in targetRoute.zoneGuards) {
            final redirectPath = guard(refreshListenable!);
            if (redirectPath != null) {
              return redirectPath;
            }
          }
        }

        return options.redirect?.call(context, state);
      },
    );
  }

  // ------------------------------------------------------------
  // Build Routes
  // ------------------------------------------------------------

  List<RouteBase> _buildRoutes() {
    return navigationZones
        .map((zone) {
          final rootRoutes = zone
              .where((e) => e.descriptor.parent == null)
              .map(
                (route) => _buildRoute(
                  route,
                  navigationZones,
                ),
              )
              .toList();

          if (zone.first.shellRouteBuilder == null) {
            return rootRoutes;
          }

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

  GoRoute _buildRoute(
    DwNavigationRoute<NavigationNotifier> route,
    List<List<DwNavigationRoute<NavigationNotifier>>> zones,
  ) {
    return GoRoute(
      name: route.name,
      path: route.routePath,
      pageBuilder: (context, state) {
        return pageBuilder(
          context,
          ValueKey('${route.name}-${state.fullPath}'),
          route.descriptor.page,
        );
      },
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

  void _validate() {
    if (navigationZones.isEmpty) {
      throw ArgumentError('navigationZones cannot be empty');
    }

    if (navigationZones.any((zone) => zone.isEmpty)) {
      throw ArgumentError('navigationZones cannot contain empty zones');
    }

    final allRoutes = navigationZones.expand((z) => z).toList();

    // unique route paths
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

    // unique route names
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

    // valid paths
    for (final route in allRoutes) {
      final path =
          route.descriptor.parent == null ? route.routePath : route.fullPath;

      if (!path.startsWith('/')) {
        throw ArgumentError(
          'Invalid route path for ${route.name}: "$path"',
        );
      }
    }

    final hasGuards =
        navigationZones.expand((z) => z).any((r) => r.zoneGuards.isNotEmpty);

    if (hasGuards && refreshListenable == null) {
      throw ArgumentError(
        'refreshListenable is required when using zoneGuards',
      );
    }
  }
}
