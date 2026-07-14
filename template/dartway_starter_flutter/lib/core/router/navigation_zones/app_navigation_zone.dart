part of '../router.dart';

/// Main app zone. `home` is the zone root. The guard redirects signed-out users
/// to the auth zone, so no page in this zone gates on auth by itself.
///
/// Add your screens here as you build the domain: `simple` for a plain page,
/// `DwNavigationRouteDescriptor.parameterized` + a [DwNavigationParamsMixin]
/// enum for routes that carry parameters.
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
