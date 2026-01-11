// import 'package:collection/collection.dart';
// import 'package:dartway_router/dartway_router.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter_riverpod/flutter_riverpod.dart';
// import 'package:flutter_svg/flutter_svg.dart';

// class DwBottomNavigationBar extends ConsumerStatefulWidget {
//   const DwBottomNavigationBar({
//     super.key,
//     required this.menuItems,
//     this.bottomNavigationBarTheme,
//     this.itemBuilder = defaultItemBuilder,
//     this.pathParameters,
//     this.showSelectedLabels,
//     this.showUnselectedLabels,
//     this.type,
//   });

//   final List<DwMenuItem> menuItems;
//   final BottomNavigationBarThemeData? bottomNavigationBarTheme;
//   final BottomNavigationBarItem Function(
//     WidgetRef ref,
//     DwMenuItem item,
//     bool isActive,
//   ) itemBuilder;
//   final Map<String, String>? pathParameters;
//   final bool? showSelectedLabels;
//   final bool? showUnselectedLabels;
//   final BottomNavigationBarType? type;

//   static BottomNavigationBarItem defaultItemBuilder(
//     WidgetRef ref,
//     DwMenuItem item,
//     bool isActive,
//   ) {
//     return BottomNavigationBarItem(
//       icon: Stack(
//         children: [
//           // Main icon
//           item.svgIcon != null
//               ? SvgPicture.asset(
//                   placeholderBuilder: (context) => const SizedBox.square(
//                     dimension: 24,
//                   ),
//                   isActive
//                       ? item.activeSvgIcon ?? item.svgIcon!
//                       : item.svgIcon!,
//                   colorFilter: item.changeIconColor
//                       ? ColorFilter.mode(
//                           isActive
//                               ? Theme.of(ref.context)
//                                   .colorScheme
//                                   .primaryFixedDim
//                               : Theme.of(ref.context).colorScheme.outline,
//                           BlendMode.srcIn,
//                         )
//                       : null,
//                 )
//               : Icon(
//                   isActive
//                       ? item.activeIconData ?? item.iconData!
//                       : item.iconData!,
//                 ),
//           // Badge overlay
//           if (item.badge != null) item.badge!,
//         ],
//       ),
//       label: item.displayTitle,
//     );
//   }

//   @override
//   ConsumerState<DwBottomNavigationBar> createState() =>
//       _MainNavigationBarState();
// }

// class _MainNavigationBarState extends ConsumerState<DwBottomNavigationBar> {
//   int _currentIndex = -1;
//   String? _lastRoute;

//   @override
//   void didChangeDependencies() {
//     super.didChangeDependencies();

//     if (!mounted) return;

//     try {
//       final uri = GoRouter.of(context).routerDelegate.currentConfiguration.uri;
//       final currentRoute = uri.toString().split('?')[0];

//       // Only recalculate if route actually changed
//       if (_lastRoute != currentRoute) {
//         _lastRoute = currentRoute;
//         _currentIndex = DwNavigationUtils.findMatchingRouteIndex(
//           currentRoute,
//           widget.menuItems,
//         );

//         // Fallback to first item if no match found or invalid index
//         if (_currentIndex == -1 || _currentIndex >= widget.menuItems.length) {
//           _currentIndex = 0;
//         }
//       }
//     } catch (e) {
//       // If GoRouter is not available (e.g., in tests), default to first item
//       if (_currentIndex == -1 || _currentIndex >= widget.menuItems.length) {
//         _currentIndex = 0;
//       }
//     }
//   }

//   @override
//   void dispose() {
//     _lastRoute = null;
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     final theme = widget.bottomNavigationBarTheme ??
//         Theme.of(context).bottomNavigationBarTheme;
//     return BottomNavigationBarTheme(
//       data: theme,
//       child: BottomNavigationBar(
//         currentIndex: _currentIndex,
//         elevation: theme.elevation ?? 0,
//         onTap: (index) {
//           ref.menuItemTap(widget.menuItems[index]);
//         },
//         showSelectedLabels: widget.showSelectedLabels,
//         showUnselectedLabels: widget.showUnselectedLabels,
//         type: widget.type,
//         items: widget.menuItems
//             .mapIndexed(
//               (index, item) => widget.itemBuilder(
//                 ref,
//                 item,
//                 index == _currentIndex,
//               ),
//             )
//             .toList(),
//       ),
//     );
//   }
// }
