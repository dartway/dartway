import 'package:dartway_router/dartway_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../app/bookings/my_bookings_page.dart';
import '../../app/chat/staff_chat_page.dart';
import '../../app/news/news_page.dart';
import '../../app/profile/profile_page/profile_page.dart';
import '../../app/schedule/schedule_page.dart';
import '../../app/services/services_page.dart';
import '../../auth/auth_page.dart';
import 'app_router_state.dart';

export 'app_router_state.dart';

part 'navigation_zones/app_navigation_zone.dart';
part 'navigation_zones/auth_navigation_zone.dart';

final appRouterStateProvider = Provider<AppRouterState>(
  (ref) => AppRouterState(ref),
);

/// The app router: two zones (app + auth) with cross-redirect guards. Signed-out
/// users are redirected to the auth zone; signed-in users are kept out of it.
final appRouterProvider = Provider<DwRouter<AppRouterState>>((ref) {
  final routerState = ref.watch(appRouterStateProvider);
  return DwRouter<AppRouterState>(
    routerState: routerState,
    navigationZones: [
      AppNavigationZone.values,
      AuthNavigationZone.values,
    ],
    pageBuilder: DwPageBuilder.fade,
    options: DwGoRouterOptions(
      initialLocation: AppNavigationZone.schedule.fullPath,
      debugLogDiagnostics: false,
    ),
  );
});
