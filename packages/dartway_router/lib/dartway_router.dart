/// A Flutter package that provides a convenient wrapper around Go Router
/// with easy route configuration and navigation utilities.
///
/// ## Features
/// - Type-safe navigation with enum-based routes
/// - Built-in bottom navigation bar widget
/// - Flexible page transitions (material, fade, slide, scale)
/// - Riverpod integration for state management
/// - Notification badges and custom widgets
/// - Comprehensive error handling and validation
///
/// ## Quick Start
/// ```dart
/// enum AppRoutes with NavigationParamsMixin<int> implements NavigationZoneRoute {
///   home,
///   profile;
///
///   @override
///   String get root => '';
///
///   @override
///   NavigationRouteDescriptor get descriptor {
///     switch (this) {
///       case AppRoutes.home:
///         return SimpleNavigationRouteDescriptor(page: HomePage());
///       case AppRoutes.profile:
///         return SimpleNavigationRouteDescriptor(page: ProfilePage());
///     }
///   }
/// }
///
/// // In your app
/// final router = ref.watch(dwRouterStateProvider(
///   navigationZones: [[AppRoutes.home, AppRoutes.profile]],
/// ));
/// ```
library;

export 'package:go_router/go_router.dart';

export 'src/navigation_zones/dw_navigation_params_mixin.dart';
export 'src/navigation_zones/dw_navigation_route.dart';
export 'src/navigation_zones/dw_navigation_route_descriptor.dart';
export 'src/navigation_zones/dw_navigation_route_extension.dart';
export 'src/navigation_zones/dw_navigation_types.dart';
export 'src/router/dw_go_router_options.dart';
export 'src/router/dw_router.dart';
export 'src/ui/dw_page_builder.dart';
