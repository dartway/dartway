// import 'package:dartway_router/dartway_router.dart';
// import 'package:flutter/material.dart';

// /// Navigation utilities for easier route management
// class DwNavigationUtils {
//   /// Navigate to a route by name with parameters
//   ///
//   /// Replaces the current route stack with the specified route.
//   ///
//   /// [context] - The build context
//   /// [route] - The route to navigate to
//   /// [pathParameters] - Optional path parameters for the route
//   /// [extra] - Optional extra data to pass to the route
//   static void goToRoute(
//     BuildContext context,
//     DwNavigationRoute route, {
//     Map<String, String>? pathParameters,
//     Object? extra,
//   }) {
//     context.goNamed(
//       route.name,
//       pathParameters: pathParameters ?? {},
//       extra: extra,
//     );
//   }

//   /// Push a route by name with parameters
//   ///
//   /// Adds the specified route to the navigation stack.
//   ///
//   /// [context] - The build context
//   /// [route] - The route to push
//   /// [pathParameters] - Optional path parameters for the route
//   /// [extra] - Optional extra data to pass to the route
//   static void pushRoute(
//     BuildContext context,
//     DwNavigationRoute route, {
//     Map<String, String>? pathParameters,
//     Object? extra,
//   }) {
//     context.pushNamed(
//       route.name,
//       pathParameters: pathParameters ?? {},
//       extra: extra,
//     );
//   }

//   /// Replace current route with a new one
//   ///
//   /// Replaces the current route in the navigation stack with the specified route.
//   ///
//   /// [context] - The build context
//   /// [route] - The route to replace with
//   /// [pathParameters] - Optional path parameters for the route
//   /// [extra] - Optional extra data to pass to the route
//   static void replaceRoute(
//     BuildContext context,
//     DwNavigationRoute route, {
//     Map<String, String>? pathParameters,
//     Object? extra,
//   }) {
//     context.pushReplacementNamed(
//       route.name,
//       pathParameters: pathParameters ?? {},
//       extra: extra,
//     );
//   }

//   /// Check if current route matches the given route
//   ///
//   /// Compares the current route's full path with the specified route's full path.
//   ///
//   /// [context] - The build context
//   /// [route] - The route to check against
//   /// Returns true if the current route matches the specified route
//   static bool isCurrentRoute(BuildContext context, DwNavigationRoute route) {
//     final currentLocation = GoRouterState.of(context).fullPath;
//     return currentLocation == route.fullPath;
//   }

//   /// Get current route from context
//   ///
//   /// Returns the current route if available, or null if not in a GoRouter context.
//   /// This is a simplified implementation - in a real scenario, you'd need to
//   /// maintain a registry of all routes to match against.
//   static DwNavigationRoute? getCurrentRoute(BuildContext context) {
//     try {
//       // Check if GoRouterState is available
//       GoRouterState.of(context);
//       // This is a simplified implementation - in a real scenario,
//       // you'd need to maintain a registry of all routes to match against
//       // For now, we'll return null and let the navigation bar handle it
//       return null;
//     } on GoException catch (e) {
//       // If GoRouterState is not available or there's a GoRouter error
//       debugPrint(
//           'DwNavigationUtils.getCurrentRoute: GoRouter error - ${e.message}');
//       return null;
//     } catch (e) {
//       // If any other error occurs
//       debugPrint('DwNavigationUtils.getCurrentRoute: Unexpected error - $e');
//       return null;
//     }
//   }

//   /// Find matching route index for a given path
//   static int findMatchingRouteIndex(
//     String currentPath,
//     List<DwMenuItem> menuItems,
//   ) {
//     final urlSections = currentPath.split('?')[0].split('/');

//     for (int i = 0; i < menuItems.length; i++) {
//       final item = menuItems[i];
//       if (item.route == null) continue;

//       final routeSections = item.route!.fullPath.split('/');

//       // Early exit if lengths don't match
//       if (urlSections.length != routeSections.length) continue;

//       bool matches = true;
//       for (var j = 0; j < urlSections.length; j++) {
//         if (!routeSections[j].startsWith(':') &&
//             urlSections[j] != routeSections[j]) {
//           matches = false;
//           break;
//         }
//       }

//       if (matches) {
//         return i;
//       }
//     }

//     return -1; // No match found
//   }
// }
