part of '../router.dart';

/// Admin-only zone (`/admin`) with its own sections: dashboard (zone root),
/// user management with a card per user, and application settings. Guards
/// redirect signed-out users to auth and non-admins back to the app — the
/// server's access rules are what actually keep its data from anyone else.
enum AdminNavigationZone implements DwNavigationRoute<AppRouterState> {
  admin(DwNavigationRouteDescriptor.zoneRoot(pageWidget: AdminDashboardPage())),
  users(
    DwNavigationRouteDescriptor.simple(
      pageWidget: AdminUsersPage(),
      parent: admin,
    ),
  ),
  // One user's card. A parameter rather than a "selected user" in state: a
  // link points at it, and it must open after a page reload too.
  userCard(
    DwNavigationRouteDescriptor.parameterized(
      pageWidget: AdminUserCardPage(),
      parameter: AdminParams.profileId,
      parent: users,
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
    (state) => !state.isSignedIn ? AuthNavigationZone.auth.fullPath : null,
    // Only once the role is known: while the profile loads the gate shows
    // nothing of the app, and an admin opening /admin must not be sent away
    // for not having loaded yet.
    (state) => state.role != null && state.role != UserRole.admin
        ? AppNavigationZone.home.fullPath
        : null,
  ];
}
