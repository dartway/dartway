part of '../app_router.dart';

enum AppRoutes implements DwNavigationRoute<AppSession> {
  catalog(
    SimpleNavigationRouteDescriptor(page: BookListPage(), isZoneRoot: true),
  ),
  bookDetail(
    ParameterizedNavigationRouteDescriptor(
      page: BookDetailPage(),
      parameter: AppParams.bookId,
      parent: catalog,
      extraPathSegment: 'books',
    ),
  ),
  profile(SimpleNavigationRouteDescriptor(page: ProfilePage()));

  const AppRoutes(this.descriptor);

  @override
  final DwNavigationRouteDescriptor descriptor;

  @override
  String get zoneRoot => '';

  @override
  List<DwNavigationGuard<AppSession>> get zoneGuards => [
    (appSession) => !appSession.isAuthorized ? AuthRoutes.auth.fullPath : null,
  ];

  @override
  DwShellRoutePageBuilder? get shellRouteBuilder =>
      (BuildContext context, GoRouterState state, Widget child) {
        final currentRootRoute = appRouter.rootRouteFromState(state);

        final currentIndex = currentRootRoute == AppRoutes.profile ? 1 : 0;

        return DwPageBuilder.fade(
          context,
          state.pageKey,
          Scaffold(
            body: child,
            bottomNavigationBar: BottomNavigationBar(
              currentIndex: currentIndex,
              onTap: (index) {
                switch (index) {
                  case 0:
                    context.goNamed(AppRoutes.catalog.name);
                    break;
                  case 1:
                    context.goNamed(AppRoutes.profile.name);
                    break;
                }
              },
              items: const [
                BottomNavigationBarItem(
                  icon: Icon(Icons.list),
                  label: 'Catalog',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.person),
                  label: 'Profile',
                ),
              ],
            ),
          ),
        );
      };
}
