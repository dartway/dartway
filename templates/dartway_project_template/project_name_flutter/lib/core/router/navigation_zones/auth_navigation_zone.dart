part of '../router.dart';

enum AuthNavigationZone implements NavigationZoneRoute {
  auth(
    SimpleNavigationRouteDescriptor(
      page: AuthPage(),
    ),
  );

  const AuthNavigationZone(this.descriptor);

  @override
  final NavigationRouteDescriptor descriptor;

  @override
  String get root => '';
}
