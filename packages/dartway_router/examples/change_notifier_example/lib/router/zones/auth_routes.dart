part of '../app_router.dart';

enum AuthRoutes implements DwNavigationRoute<AppSession> {
  auth(SimpleNavigationRouteDescriptor(page: AuthPage()));

  const AuthRoutes(this.descriptor);

  @override
  final DwNavigationRouteDescriptor descriptor;

  @override
  String get zoneRoot => '';

  @override
  DwShellRoutePageBuilder? get shellRouteBuilder => null;

  @override
  List<DwNavigationGuard<AppSession>> get zoneGuards => [
    (appSession) => appSession.isAuthorized ? AppRoutes.catalog.fullPath : null,
  ];
}
