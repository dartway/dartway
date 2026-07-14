import 'package:dartway_router/dartway_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../dw_core.dart';
import '../../app/admin/dashboard/admin_dashboard_page.dart';
import '../../app/admin/settings/admin_settings_page.dart';
import '../../app/admin/users/admin_users_page.dart';
import '../../app/home/home_page.dart';
import '../../app/profile/profile_page/profile_page.dart';
import '../../auth/auth_page.dart';
import 'app_router_state.dart';

export 'app_router_state.dart';

part 'navigation_zones/admin_navigation_zone.dart';
part 'navigation_zones/app_navigation_zone.dart';
part 'navigation_zones/auth_navigation_zone.dart';

final appRouterStateProvider = Provider<AppRouterState>(
  (ref) => AppRouterState(ref),
);

/// The app router: two zones (app + auth) with cross-redirect guards. Signed-out
/// users are redirected to the auth zone; signed-in users are kept out of it.
final appRouterProvider = Provider<DwRouter<AppRouterState>>((ref) {
  final routerState = ref.watch(appRouterStateProvider);
  final router = DwRouter<AppRouterState>(
    routerState: routerState,
    navigationZones: [
      AppNavigationZone.values,
      AdminNavigationZone.values,
      AuthNavigationZone.values,
    ],
    pageBuilder: DwPageBuilder.fade,
    options: DwGoRouterOptions(
      initialLocation: AppNavigationZone.home.fullPath,
      debugLogDiagnostics: false,
    ),
  );

  // Error reports carry the current route — the framework has no access to
  // the app's router, so the app registers a lazy source once.
  dw.errorContext.registerRouteSource(() {
    final configuration = router.router.routerDelegate.currentConfiguration;
    return configuration.isEmpty ? '/' : configuration.uri.path;
  });

  return router;
});
