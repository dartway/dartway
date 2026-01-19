// import 'package:flutter/material.dart';
// import 'package:flutter_riverpod/flutter_riverpod.dart';
// import 'package:go_router/go_router.dart';

// import '../navigation_params/navigation_parameters_providers.dart';
// import '../navigation_zones/dw_navigation_route.dart';
// import '../navigation_zones/navigation_zone_route.dart';
// import 'dw_router_config.dart';

// /// Core router class for DartWay Router package.
// ///
// /// Provides static methods for configuring and creating GoRouter instances
// /// with validation and error handling.
// class DwRouter {
//   /// Prepare a GoRouter instance with the given configuration
//   ///
//   /// This method creates and configures a GoRouter with validation and error handling.
//   /// It's used internally by [DwRouterConfig.build()] and should not be called directly.
//   ///
//   /// [navigationZones] - List of navigation zones, each containing routes
//   /// [notFoundPageWidget] - Widget to display when no route matches
//   /// [initialLocation] - Initial route path to navigate to
//   /// [refreshListenable] - Listenable to trigger router refresh
//   /// [redirect] - Function to handle route redirects
//   /// [manualRedirect] - Function to handle manual redirects based on GoRouterState
//   /// [pageFactory] - Factory for creating page transitions
//   static GoRouter prepareRouter({
//     required DwRouterConfig config,
//   }) {

//   }

//   static GoRoute _buildRoute(
//     DwNavigationRoute route,
//     List<List<DwNavigationRoute>> zones, {
//     required Page<dynamic> Function(
//       BuildContext context,
//       LocalKey key,
//       Widget child,
//     ) pageBuilder,
//   }) {
//     return GoRoute(
//       path: route.routePath,
//       name: route.name,
//       pageBuilder: (context, state) {
//         return pageBuilder(
//           context,
//           ValueKey('${route.name}-${state.fullPath}'),
//           route.descriptor.page,
//         );
//       },
//       routes: zones
//           .map((zone) => zone
//               .where((e) => e.descriptor.parent == route)
//               .map((e) => _buildRoute(e, zones, pageBuilder: pageBuilder)))
//           .expand((x) => x)
//           .toList(),
//     );
//   }

//   static _getCurrentRoute(
//     Uri currentUri,
//     Iterable<DwNavigationRoute> navigationRoutes,
//   ) {
//     final urlSections = currentUri.toString().split('?')[0].split('/');
//     final currentRoute = navigationRoutes.firstWhere(
//       (element) {
//         final routeSections = element.fullPath.split('/');

//         for (var i = 0; i < urlSections.length; i++) {
//           if (i >= routeSections.length) {
//             return false;
//           }
//           if (routeSections[i].startsWith(':') ||
//               urlSections[i] == routeSections[i]) {
//             continue;
//           } else {
//             return false;
//           }
//         }

//         return true;
//       },
//     );

//     return currentRoute;
//   }
// }
