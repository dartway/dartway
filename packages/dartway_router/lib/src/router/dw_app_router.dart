import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderListenable;
import 'package:go_router/go_router.dart';

import '../navigation_zones/dw_navigation_route.dart';
import '../navigation_zones/dw_navigation_route_extension.dart';
import '../navigation_zones/dw_navigation_types.dart';
import 'dw_go_router_options.dart';

/// The app's router: navigation zones over one [GoRouter], built inside a
/// Riverpod provider.
///
/// ```dart
/// final appRouterProvider = Provider<DwAppRouter<AppRouterState>>(
///   (ref) => DwAppRouter<AppRouterState>(
///     ref: ref,
///     routerState: appRouterStateProvider,
///     navigationZones: [AppNavigationZone.values, AuthNavigationZone.values],
///     pageBuilder: DwPageBuilder.fade,
///   ),
/// );
/// ```
///
/// The router follows [routerState] through `ref` and re-runs its guards
/// whenever the value changes, and it disposes itself with the provider that
/// built it — the app holds no `Listenable` and disposes nothing.
class DwAppRouter<RouterState> {
  DwAppRouter({
    required Ref ref,
    required this.navigationZones,
    required this.pageBuilder,
    this.routerState,
    this.options = const DwGoRouterOptions(),
  }) {
    _validate();
    _buildRegistry();
    _followRouterState(ref);
    router = _buildRouter();
    ref.onDispose(_dispose);
  }

  // ------------------------------------------------------------
  // Public API
  // ------------------------------------------------------------

  /// What the zone guards decide by: a provider of an immutable value — a
  /// record or a class with value equality — derived from the providers it
  /// depends on (the signed-in account, the profile's role).
  ///
  /// Each guard is handed its current value. Whenever the value changes the
  /// router re-runs the guards on the location it shows, so signing in leaves
  /// the sign-in screen and signing out returns to it with nothing else wired.
  ///
  /// Required when any route declares [DwNavigationRoute.zoneGuards].
  final ProviderListenable<RouterState>? routerState;

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

  /// The subscription to [routerState]; `null` when the router has none.
  ProviderSubscription<RouterState>? _state;

  /// What go_router listens to (`refreshListenable`), notified whenever
  /// [routerState] changes. go_router asks for a [Listenable]; the router
  /// keeps it to itself so the app does not have to hold one.
  _RouterRefresh? _refresh;

  void _followRouterState(Ref ref) {
    final source = routerState;
    if (source == null) return;

    final refresh = _refresh = _RouterRefresh();
    _state = ref.listen<RouterState>(source, (_, _) => refresh.notify());
  }

  void _dispose() {
    router.dispose();
    _refresh?.dispose();
  }

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
      refreshListenable: _refresh,
      redirectLimit: options.redirectLimit,
      routerNeglect: options.routerNeglect,
      debugLogDiagnostics: options.debugLogDiagnostics,
      overridePlatformDefaultLocation: options.overridePlatformDefaultLocation,
      requestFocus: options.requestFocus,
      restorationScopeId: options.restorationScopeId,
      observers: options.observers,
      onException: options.onException,
      extraCodec: options.extraCodec,
      onEnter: options.onEnter,
      redirect: (context, state) {
        // First, check zone guards
        final targetRoute = topRouteFromState(state);

        final subscription = _state;
        if (targetRoute != null &&
            targetRoute.zoneGuards.isNotEmpty &&
            subscription != null) {
          final target = DwNavigationTarget(
            uri: state.uri,
            routeName: state.topRoute?.name,
            pathParameters: state.pathParameters,
          );
          // Read once: every guard of this redirect decides by one value.
          final current = subscription.read();
          // Execute guards in order until one returns a redirect path
          for (final guard in targetRoute.zoneGuards) {
            final redirectPath = guard(current, target);
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

          // StatefulShellRoute: each root route becomes an independent branch,
          // preserving its navigation stack across tab switches.
          if (zone.first.statefulShellRouteBuilder != null) {
            return <RouteBase>[
              StatefulShellRoute.indexedStack(
                pageBuilder: zone.first.statefulShellRouteBuilder!,
                notifyRootObserver: options.shellNotifyRootObserver,
                branches: rootRoutes
                    .map((r) => StatefulShellBranch(routes: <RouteBase>[r]))
                    .toList(),
              ),
            ];
          }

          // ShellRoute: simple shell wrapper (state not preserved across tabs).
          if (zone.first.shellRouteBuilder != null) {
            return <RouteBase>[
              ShellRoute(
                pageBuilder: zone.first.shellRouteBuilder!,
                notifyRootObserver: options.shellNotifyRootObserver,
                routes: rootRoutes,
              ),
            ];
          }

          return rootRoutes;
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
      caseSensitive: options.caseSensitive,
      pageBuilder: (context, state) {
        // Use go_router's own per-page key, which is unique for every entry on
        // the stack (a random key for imperative pushes, preserved across
        // rebuilds). Deriving the key from name + path instead would collide
        // whenever the same location appears twice on the stack and trip the
        // Navigator's _debugCheckDuplicatedPageKeys assertion.
        return pageBuilder(
          context,
          state.pageKey,
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
  /// - Ensures no duplicate route names across zones
  /// - Ensures no duplicate route paths
  /// - Ensures all paths are valid (start with '/')
  /// - Ensures [routerState] is provided when guards are used
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

    // Keep every route paired with the zone it came from. Flattening the
    // zones throws that away, and it is precisely what a collision report
    // needs: the name of the offending value alone leaves the reader to find
    // its two declarations by hand.
    final allRoutes = <_ZonedRoute<RouterState>>[
      for (var zoneIndex = 0; zoneIndex < navigationZones.length; zoneIndex++)
        for (final route in navigationZones[zoneIndex])
          _ZonedRoute(route, zoneIndex),
    ];

    // Check for duplicate route names.
    //
    // Runs before the path check on purpose: two zones declaring one name
    // usually collide on the path as well, and the path is the symptom while
    // the shared name is the cause.
    _checkNoDuplicates(
      allRoutes,
      key: (zoned) => zoned.route.name,
      summary: (name) => 'Duplicate route name "$name".',
      explanation:
          'Route names are global across navigation zones. DwAppRouter keeps a '
          'single registry for the whole app and resolves routes by name, so a '
          'name may be declared once and only once. An enum gives its values a '
          'namespace of their own; the router does not. Rename one of the '
          'two — for a .simple route, set extraPathSegment on it first if the '
          'URL must stay the same: the new name changes nothing about the '
          'path once extraPathSegment names it instead.',
    );

    // Check for duplicate route paths
    _checkNoDuplicates(
      allRoutes,
      key: (zoned) => zoned.route.fullPath,
      summary: (path) => 'Duplicate route path "$path".',
      explanation:
          'A path is built from the zoneRoot of its zone, its parent chain and '
          'its own segment. Two routes resolving to the same address means one '
          'of them can never be reached.',
    );

    // Validate that all paths start with '/'
    for (final zoned in allRoutes) {
      final route = zoned.route;
      final path =
          route.descriptor.parent == null ? route.routePath : route.fullPath;

      if (!path.startsWith('/')) {
        throw ArgumentError(
          'Invalid route path for ${zoned.describe()}: "$path"',
        );
      }
    }

    // Check that routerState is provided when guards are used
    final hasGuards =
        navigationZones.expand((z) => z).any((r) => r.zoneGuards.isNotEmpty);

    if (hasGuards && routerState == null) {
      throw ArgumentError(
        'routerState is required when using zoneGuards: the guards decide by '
        'its value, and the router re-runs them when it changes.',
      );
    }
  }

  /// Throws unless [key] is unique across every route of every zone.
  ///
  /// The failure names the duplicated value and each route that declares it,
  /// zone included, so that the message itself ends the investigation.
  void _checkNoDuplicates(
    List<_ZonedRoute<RouterState>> routes, {
    required String Function(_ZonedRoute<RouterState> route) key,
    required String Function(String key) summary,
    required String explanation,
  }) {
    final grouped = <String, List<_ZonedRoute<RouterState>>>{};
    for (final zoned in routes) {
      grouped.putIfAbsent(key(zoned), () => []).add(zoned);
    }

    final duplicates =
        grouped.entries.where((e) => e.value.length > 1).toList();
    if (duplicates.isEmpty) return;

    throw ArgumentError(
      duplicates
          .map(
            (entry) => '${summary(entry.key)}\n'
                'Declared by:\n'
                '${entry.value.map((z) => '  - ${z.describe()}').join('\n')}\n'
                '\n$explanation',
          )
          .join('\n\n'),
    );
  }
}

/// The `refreshListenable` handed to go_router, notified when the router
/// state changes. Internal: an app never holds a `Listenable` for the router.
class _RouterRefresh extends ChangeNotifier {
  void notify() => notifyListeners();
}

/// A route paired with the index of the zone that declares it.
///
/// [DwAppRouter.navigationZones] is a list of lists; flattening it loses the one
/// fact a duplicate-route message has to carry — which zones the colliding
/// declarations came from.
class _ZonedRoute<RouterState> {
  const _ZonedRoute(this.route, this.zoneIndex);

  final DwNavigationRoute<RouterState> route;

  /// Position of the route's zone in [DwAppRouter.navigationZones].
  final int zoneIndex;

  /// `AdminRoutes.projects (navigationZones[1])` — the enum that declares
  /// the value, and where its zone sits in the list handed to the router.
  String describe() =>
      '${route.runtimeType}.${route.name} (navigationZones[$zoneIndex])';
}
