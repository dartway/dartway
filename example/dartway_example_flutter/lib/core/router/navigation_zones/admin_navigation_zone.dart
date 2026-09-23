part of '../router.dart';

/// Admin-only zone (`/admin`) with its own sections: dashboard (zone root),
/// user management and application settings. Guards redirect signed-out users
/// to auth and non-admins back to the app — the panel is club-admin only; the
/// server's access rules are what actually keep its data from anyone else.
enum AdminNavigationZone implements DwNavigationRoute<AppRouterState> {
  admin(DwNavigationRouteDescriptor.zoneRoot(pageWidget: AdminDashboardPage())),
  users(
    DwNavigationRouteDescriptor.simple(
      pageWidget: AdminUsersPage(),
      parent: admin,
    ),
  ),
  settings(
    DwNavigationRouteDescriptor.simple(
      pageWidget: AdminSettingsPage(),
      parent: admin,
    ),
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
    (state, target) =>
        state.isSignedIn ? null : AuthNavigationZone.signInFrom(target),
    // Only once the role is known: while the profile loads the gate shows
    // nothing of the app, and an admin opening /admin must not be sent away
    // for not having loaded yet.
    (state, _) => state.role != null && state.role != UserRole.admin
        ? AppNavigationZone.schedule.fullPath
        : null,
  ];
}
