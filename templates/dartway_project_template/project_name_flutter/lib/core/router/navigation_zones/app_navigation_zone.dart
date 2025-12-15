part of '../router.dart';

enum AppNavigationZone implements NavigationZoneRoute {
  home(
    SimpleNavigationRouteDescriptor(
      page: HomePage(),
    ),
  ),
  // post(
  //   ParameterizedNavigationRouteDescriptor(
  //     page: PostPage(),
  //     parameter: AppNavigationParams.postId,
  //     parent: AppNavigationZone.home,
  //     pathSegmentTemplate: 'post/$dwParameterSubstitutionPattern',
  //   ),
  // ),

  profile(
    SimpleNavigationRouteDescriptor(
      page: ProfilePage(),
    ),
  ),
  ;

  const AppNavigationZone(this.descriptor);

  @override
  final NavigationRouteDescriptor descriptor;

  @override
  String get root => '';
}
