part of '../router.dart';

/// Main app zone. `schedule` is the zone root. Guard redirects signed-out
/// users to the auth zone. Add parameterized routes with
/// `DwNavigationRouteDescriptor.parameterized` + a [DwNavigationParamsMixin] enum.
enum AppNavigationZone implements DwNavigationRoute<AppRouterState> {
  schedule(
    DwNavigationRouteDescriptor.zoneRoot(pageWidget: SchedulePage()),
  ),
  bookings(
    DwNavigationRouteDescriptor.simple(
      pageWidget: MyBookingsPage(),
      parent: schedule,
    ),
  ),
  news(
    DwNavigationRouteDescriptor.simple(
      pageWidget: NewsPage(),
      parent: schedule,
    ),
  ),
  chat(
    DwNavigationRouteDescriptor.simple(
      pageWidget: StaffChatPage(),
      parent: schedule,
    ),
  ),
  services(
    DwNavigationRouteDescriptor.simple(
      pageWidget: ServicesPage(),
      parent: profile,
    ),
  ),
  profile(
    DwNavigationRouteDescriptor.simple(
      pageWidget: ProfilePage(),
      parent: schedule,
    ),
  );

  const AppNavigationZone(this.descriptor);

  @override
  final DwNavigationRouteDescriptor<AppRouterState> descriptor;

  @override
  String get zoneRoot => '';

  @override
  DwShellRoutePageBuilder? get shellRouteBuilder => null;

  @override
  DwStatefulShellRouteBuilder? get statefulShellRouteBuilder => null;

  @override
  List<DwNavigationGuard<AppRouterState>> get zoneGuards => [
        (state) => !state.isSignedIn ? AuthNavigationZone.auth.fullPath : null,
      ];
}
