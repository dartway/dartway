part of '../app_router.dart';

enum AppRoutes implements DwNavigationRoute<RouterRefreshNotifier> {
  catalog(DwNavigationRouteDescriptor.zoneRoot(pageWidget: BookListPage())),
  bookDetail(
    DwNavigationRouteDescriptor.parameterized(
      pageWidget: BookDetailPage(),
      parameter: AppParams.bookId,
      parent: catalog,
      extraPathSegment: 'books',
    ),
  ),
  profile(DwNavigationRouteDescriptor.simple(pageWidget: ProfilePage()));

  const AppRoutes(this.descriptor);

  @override
  final DwNavigationRouteDescriptor<RouterRefreshNotifier> descriptor;

  @override
  String get zoneRoot => '';

  @override
  List<DwNavigationGuard<RouterRefreshNotifier>> get zoneGuards => [
    (notifier) => !notifier.isLoggedIn ? AuthRoutes.auth.fullPath : null,
  ];

  @override
  DwShellRoutePageBuilder? get shellRouteBuilder =>
      (BuildContext context, GoRouterState state, Widget child) {
        return DwPageBuilder.fade(
          context,
          state.pageKey,
          Consumer(
            child: child,
            builder: (context, ref, child) {
              final currentRootRoute = ref
                  .read(appRouterProvider)
                  .rootRouteFromState(state);

              final currentIndex = currentRootRoute == AppRoutes.profile
                  ? 1
                  : 0;

              return Scaffold(
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
              );
            },
          ),
        );
      };
}
