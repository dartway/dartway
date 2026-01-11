// import 'package:dartway_router/dartway_router.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter_riverpod/flutter_riverpod.dart';

// /// A menu item for bottom navigation bar.
// ///
// /// Provides different named constructors for creating menu items with
// /// Material icons, SVG icons, or custom actions. Supports badges for
// /// notifications and custom widgets.
// ///
// /// Example:
// /// ```dart
// /// DwMenuItem.icon(
// ///   route: AppRoutes.home,
// ///   displayTitle: 'Home',
// ///   iconData: Icons.home,
// ///   activeIconData: Icons.home_filled,
// ///   badge: NotificationBadge(notificationProvider: messageCountProvider),
// /// )
// /// ```
// class DwMenuItem {
//   /// Create a menu item with Material Design icon
//   const DwMenuItem.icon({
//     required this.route,
//     required this.displayTitle,
//     required this.iconData,
//     this.activeIconData,
//     this.customOnPressed,
//     this.badge,
//     this.changeIconColor = false,
//   })  : svgIcon = null,
//         activeSvgIcon = null;

//   /// Create a menu item with SVG icon
//   const DwMenuItem.svg({
//     required this.route,
//     required this.displayTitle,
//     required this.svgIcon,
//     this.activeSvgIcon,
//     this.customOnPressed,
//     this.badge,
//     this.changeIconColor = true,
//   })  : iconData = null,
//         activeIconData = null;

//   /// Create a custom menu item with no route (for custom actions)
//   const DwMenuItem.custom({
//     required this.displayTitle,
//     required this.iconData,
//     required this.customOnPressed,
//     this.badge,
//   })  : route = null,
//         svgIcon = null,
//         activeSvgIcon = null,
//         activeIconData = null,
//         changeIconColor = false;

//   final DwNavigationRoute? route;
//   final String displayTitle;
//   final IconData? iconData;
//   final String? svgIcon;
//   final IconData? activeIconData;
//   final String? activeSvgIcon;
//   final Function(WidgetRef)? customOnPressed;
//   final bool changeIconColor;
//   final Widget? badge;
// }
