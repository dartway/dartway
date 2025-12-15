part of '../app_router.dart';

enum AppNavigationZone implements NavigationZoneRoute {
  home(SimpleNavigationRouteDescriptor(page: HomePage())),
  profile(SimpleNavigationRouteDescriptor(page: ProfilePage())),
  settings(SimpleNavigationRouteDescriptor(page: SettingsPage())),
  userDetail(ParameterizedNavigationRouteDescriptor(
    page: UserDetailPage(),
    parameter: AppParams.userId,
  )),
  search(ParameterizedNavigationRouteDescriptor(
    page: UserDetailPage(), // Reusing for demo
    parameter: AppParams.searchQuery,
  )),
  productDetail(ParameterizedNavigationRouteDescriptor(
    page: UserDetailPage(), // Reusing for demo
    parameter: AppParams.price,
  )),
  featureToggle(ParameterizedNavigationRouteDescriptor(
    page: UserDetailPage(), // Reusing for demo
    parameter: AppParams.isEnabled,
  ));

  const AppNavigationZone(this.descriptor);

  @override
  final NavigationRouteDescriptor descriptor;

  @override
  String get root => '';
}
