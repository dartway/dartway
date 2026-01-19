part of '../app_router.dart';

enum AuthRoutes implements DwNavigationRoute<AppSession> {
  auth(DwNavigationRouteDescriptor.simple(pageWidget: AuthPage()));

  const AuthRoutes(this.descriptor);

  @override
  final DwNavigationRouteDescriptor<AppSession> descriptor;

  @override
  String get zoneRoot => '';

  @override
  DwShellRoutePageBuilder? get shellRouteBuilder => null;

  @override
  List<DwNavigationGuard<AppSession>> get zoneGuards => [
    (appSession) => appSession.isLoggedIn ? AppRoutes.catalog.fullPath : null,
  ];
}
