part of '../router.dart';

/// Admin-only zone (`/admin`). Guards redirect signed-out users to auth and
/// non-admins back to the app — the panel is club-admin only.
enum AdminNavigationZone implements DwNavigationRoute<AppRouterState> {
  admin(
    DwNavigationRouteDescriptor.zoneRoot(pageWidget: AdminPage()),
  );

  const AdminNavigationZone(this.descriptor);

  @override
  final DwNavigationRouteDescriptor<AppRouterState> descriptor;

  @override
  String get zoneRoot => 'admin';

  @override
  DwShellRoutePageBuilder? get shellRouteBuilder => null;

  @override
  DwStatefulShellRouteBuilder? get statefulShellRouteBuilder => null;

  @override
  List<DwNavigationGuard<AppRouterState>> get zoneGuards => [
        (state) => !state.isSignedIn ? AuthNavigationZone.auth.fullPath : null,
        (state) => !state.isAdmin ? AppNavigationZone.schedule.fullPath : null,
      ];
}
