// import 'package:dartway_router/dartway_router.dart';
// import 'package:flutter/material.dart';

// /// Extension on BuildContext for easier navigation
// ///
// /// Provides convenient methods for navigation using [DwNavigationRoute] instances.
// extension DwBuildContextNavigationExtension on BuildContext {
//   /// Navigate to a route
//   ///
//   /// Replaces the current route stack with the specified route.
//   ///
//   /// [route] - The route to navigate to
//   /// [pathParameters] - Optional path parameters for the route
//   /// [extra] - Optional extra data to pass to the route
//   void goTo(
//     DwNavigationRoute route, {
//     Map<String, String>? pathParameters,
//     Object? extra,
//   }) {
//     DwNavigationUtils.goToRoute(this, route,
//         pathParameters: pathParameters, extra: extra);
//   }

//   /// Push a route
//   ///
//   /// Adds the specified route to the navigation stack.
//   ///
//   /// [route] - The route to push
//   /// [pathParameters] - Optional path parameters for the route
//   /// [extra] - Optional extra data to pass to the route
//   void pushTo(
//     DwNavigationRoute route, {
//     Map<String, String>? pathParameters,
//     Object? extra,
//   }) {
//     DwNavigationUtils.pushRoute(this, route,
//         pathParameters: pathParameters, extra: extra);
//   }

//   /// Replace current route
//   ///
//   /// Replaces the current route in the navigation stack with the specified route.
//   ///
//   /// [route] - The route to replace with
//   /// [pathParameters] - Optional path parameters for the route
//   /// [extra] - Optional extra data to pass to the route
//   void replaceWith(
//     DwNavigationRoute route, {
//     Map<String, String>? pathParameters,
//     Object? extra,
//   }) {
//     DwNavigationUtils.replaceRoute(this, route,
//         pathParameters: pathParameters, extra: extra);
//   }

//   /// Check if current route matches
//   ///
//   /// Returns true if the current route matches the specified route.
//   ///
//   /// [route] - The route to check against
//   bool isCurrent(DwNavigationRoute route) {
//     return DwNavigationUtils.isCurrentRoute(this, route);
//   }
// }
