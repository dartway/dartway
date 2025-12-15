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
library dartway_router;

export 'package:go_router/go_router.dart';

// ============================================================================
// CORE ROUTING COMPONENTS
// ============================================================================

// Router
export 'src/core/router/dw_router.dart';
export 'src/core/router/dw_router_config.dart';
export 'src/core/router/dw_router_state.dart';

// Navigation Zones
export 'src/core/navigation_zones/navigation_route_descriptor.dart';
export 'src/core/navigation_zones/navigation_zone_route.dart';

// Navigation Parameters
export 'src/core/navigation_params/navigation_parameters_providers.dart';
export 'src/core/navigation_params/navigation_params_mixin.dart';

// State Management
export 'src/core/redirects/redirects_state_model.dart';

// ============================================================================
// UI COMPONENTS
// ============================================================================

export 'src/ui/page_transition/dw_page_builders.dart';
export 'src/ui/page_transition/dw_page_builder.dart';

// Navigation Bar
export 'src/ui/dw_bottom_navigation_bar.dart';
export 'src/ui/dw_menu_item.dart';

// Widgets
export 'src/ui/widgets/fade_transition_page.dart';
export 'src/ui/widgets/not_found_page.dart';
export 'src/ui/widgets/notification_badge.dart';

// ============================================================================
// UTILITIES
// ============================================================================

export 'src/utils/ref_navigation_extensions.dart';
export 'src/utils/dw_navigation_utils.dart';
export 'src/utils/build_context_extension.dart';
