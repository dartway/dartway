part of '../router.dart';

/// Auth zone. Guard redirects already signed-in users back to the app zone.
enum AuthNavigationZone implements DwNavigationRoute<AppRouterState> {
  auth(
    DwNavigationRouteDescriptor.simple(pageWidget: AuthPage()),
  );

  const AuthNavigationZone(this.descriptor);

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
        (state) => state.isSignedIn ? AppNavigationZone.home.fullPath : null,
      ];
}
