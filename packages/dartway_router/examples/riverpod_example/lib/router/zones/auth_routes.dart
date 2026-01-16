part of '../app_router.dart';

enum AuthRoutes implements DwNavigationRoute<RouterRefreshNotifier> {
  auth(DwNavigationRouteDescriptor.simple(pageWidget: AuthPage()));

  const AuthRoutes(this.descriptor);

  @override
  final DwNavigationRouteDescriptor<RouterRefreshNotifier> descriptor;

  @override
  String get zoneRoot => '';

  @override
  DwShellRoutePageBuilder? get shellRouteBuilder => null;

  @override
  List<DwNavigationGuard<RouterRefreshNotifier>> get zoneGuards => [
    (notifier) => notifier.isLoggedIn ? AppRoutes.catalog.fullPath : null,
  ];
}
