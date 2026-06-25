part of '../router.dart';

/// Main app zone. `home` is the zone root. Guard redirects signed-out users to
/// the auth zone. Add parameterized routes with
/// `DwNavigationRouteDescriptor.parameterized` + a [DwNavigationParamsMixin] enum.
enum AppNavigationZone implements DwNavigationRoute<AppRouterState> {
  home(
    DwNavigationRouteDescriptor.zoneRoot(pageWidget: HomePage()),
  ),
  profile(
    DwNavigationRouteDescriptor.simple(
      pageWidget: ProfilePage(),
      parent: home,
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
