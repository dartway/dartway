// import 'package:dartway_router/dartway_router.dart';

// class DwRouterUtils {
//   static int getCurrentIndex(Uri uri, List<DwNavigationRoute?> routes) {
//     final urlSections = uri.toString().split('?')[0].split('/');
//     return routes.indexWhere(
//       (route) {
//         if (route == null) return false;
//         final routeSections = route.fullPath.split('/');
//         for (var i = 0; i < urlSections.length; i++) {
//           if (i >= routeSections.length) return true;
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
//   }
// }
