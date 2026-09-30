/// A Flutter package that provides a convenient wrapper around Go Router
/// with easy route configuration and navigation utilities.
///
/// ## Features
///
/// - **Type-Safe Navigation**: Enum-based routes with compile-time checking
/// - **Guards follow a provider**: the router re-runs its guards whenever a Riverpod provider's value changes
/// - **Navigation Zones**: Group routes into logical zones (authenticated, public, etc.)
/// - **Route Guards**: Protect routes with authentication/authorization guards
/// - **Type-Safe Parameters**: Extract and use navigation parameters with full type safety
/// - **Flexible Transitions**: Built-in page transitions (material, fade, slide, scale)
/// - **Shell Routes**: Easy shell route configuration for common UI patterns
/// - **Comprehensive Validation**: Automatic validation of route configuration
///
/// ## Quick Start
///
/// ```dart
/// // 1. What the guards decide by: an immutable value from a provider
/// typedef AppSession = ({bool isAuthenticated});
///
/// final appSessionProvider = Provider<AppSession>(
///   (ref) => (isAuthenticated: ref.watch(accountIdProvider) != null),
/// );
///
/// // 2. Define your routes
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
///   List<DwNavigationGuard<AppSession>> get zoneGuards => [
///     (session, _) => session.isAuthenticated ? null : '/login',
///   ];
/// }
///
/// // 3. Create the router in a provider
/// final appRouterProvider = Provider<DwAppRouter<AppSession>>(
///   (ref) => DwAppRouter<AppSession>(
///     ref: ref,
///     routerState: appSessionProvider,
///     navigationZones: [AppRoutes.values, AuthRoutes.values],
///     pageBuilder: DwPageBuilder.material,
///   ),
/// );
///
/// // 4. Use in your app
/// MaterialApp.router(routerConfig: ref.watch(appRouterProvider).router)
/// ```
///
/// See the [README](https://github.com/dartway/dartway_router) for detailed documentation.
library;

export 'package:go_router/go_router.dart';

export 'src/navigation_zones/dw_navigation_params_mixin.dart';
export 'src/navigation_zones/dw_navigation_route.dart';
export 'src/navigation_zones/dw_navigation_route_descriptor.dart';
export 'src/navigation_zones/dw_navigation_route_extension.dart';
export 'src/navigation_zones/dw_navigation_types.dart';
export 'src/router/dw_go_router_options.dart';
export 'src/router/dw_app_router.dart';
export 'src/ui/dw_page_builder.dart';
