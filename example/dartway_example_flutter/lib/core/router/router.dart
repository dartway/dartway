import 'package:dartway_core_flutter/dartway_core_flutter.dart';
import 'package:dartway_example_flutter/admin/dashboard/admin_dashboard_page.dart';
import 'package:dartway_example_flutter/admin/settings/admin_settings_page.dart';
import 'package:dartway_example_flutter/admin/users/admin_users_page.dart';
import 'package:dartway_example_flutter/app/bookings/my_bookings_page.dart';
import 'package:dartway_example_flutter/app/chat/staff_chat_page.dart';
import 'package:dartway_example_flutter/app/news/news_page.dart';
import 'package:dartway_example_flutter/app/profile/profile_page/profile_page.dart';
import 'package:dartway_example_flutter/app/schedule/schedule_page.dart';
import 'package:dartway_example_flutter/app/services/services_page.dart';
import 'package:dartway_example_flutter/app/workouts/workouts_page.dart';
import 'package:dartway_example_flutter/auth/auth_page.dart';
import 'package:dartway_example_flutter/core/dw_core.dart';
import 'package:dartway_example_flutter/core/router/app_router_state.dart';
import 'package:dartway_example_shared/dartway_example_shared.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

export 'package:dartway_example_flutter/core/router/app_router_state.dart';

part 'navigation_zones/admin_navigation_zone.dart';
part 'navigation_zones/app_navigation_zone.dart';
part 'navigation_zones/auth_navigation_zone.dart';

final appRouterStateProvider = Provider<AppRouterState>((ref) {
  final state = AppRouterState(ref);
  ref.onDispose(state.dispose);
  return state;
});

/// The app router: three zones (app, admin, auth) with cross-redirect guards.
/// Signed-out users are redirected to the auth zone; signed-in users are kept
/// out of it, and non-admins out of the admin zone.
final appRouterProvider = Provider<DwAppRouter<AppRouterState>>((ref) {
  final routerState = ref.watch(appRouterStateProvider);
  final router = DwAppRouter<AppRouterState>(
    routerState: routerState,
    navigationZones: [
      AppNavigationZone.values,
      AdminNavigationZone.values,
      AuthNavigationZone.values,
    ],
    pageBuilder: DwPageBuilder.fade,
    options: DwGoRouterOptions(
      initialLocation: AppNavigationZone.schedule.fullPath,
      debugLogDiagnostics: false,
    ),
  );

  // Error reports carry the current route — the framework has no access to
  // the app's router, so the app registers a lazy source once.
  dw.errorContext.registerRouteSource(() {
    final configuration = router.router.routerDelegate.currentConfiguration;
    return configuration.isEmpty ? '/' : configuration.uri.path;
  });

  ref.onDispose(router.router.dispose);
  return router;
});
