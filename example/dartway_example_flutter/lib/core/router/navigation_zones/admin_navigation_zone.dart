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
  List<DwDecisionGuard<AppRouterState>> get zoneGuards => [
    (state, target) => state.isSignedIn
        ? DwGuardDecision.allow
        : DwGuardDecision.redirect(AuthNavigationZone.signInFrom(target)),
    (state, _) => switch (state.role) {
      null => DwGuardDecision.pending,
      UserRole.admin => DwGuardDecision.allow,
      _ => DwGuardDecision.redirect(AppNavigationZone.schedule.fullPath),
    },
  ];
}
