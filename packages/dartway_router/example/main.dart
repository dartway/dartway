// Example app for dartway_router: two zones (auth + app) with guard using AppSession.
// Run: cd example && flutter run

import 'package:dartway_router/dartway_router.dart';
import 'package:flutter/material.dart';

// -----------------------------------------------------------------------------
// Entry point & app
// -----------------------------------------------------------------------------

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'DartWay Router Example',
      theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: true),
      routerConfig: appRouter.router,
    );
  }
}

// -----------------------------------------------------------------------------
// Router (defined after route enums)
// -----------------------------------------------------------------------------

final appRouter = DwRouter<AppSession>(
  routerState: AppSession(),
  navigationZones: [
    AppRoutes.values,
    AuthRoutes.values,
  ],
  pageBuilder: DwPageBuilder.fade,
  options: DwGoRouterOptions(
    initialLocation: AuthRoutes.auth.fullPath,
    debugLogDiagnostics: true,
  ),
);

// -----------------------------------------------------------------------------
// Routes: auth zone
// -----------------------------------------------------------------------------

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
        (session) => session.isLoggedIn ? AppRoutes.catalog.fullPath : null,
      ];
}

// -----------------------------------------------------------------------------
// Routes: app zone (protected by guard)
// -----------------------------------------------------------------------------

enum AppRoutes implements DwNavigationRoute<AppSession> {
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
  final DwNavigationRouteDescriptor<AppSession> descriptor;

  @override
  String get zoneRoot => '';

  @override
  List<DwNavigationGuard<AppSession>> get zoneGuards => [
        (session) => !session.isLoggedIn ? AuthRoutes.auth.fullPath : null,
      ];

  @override
  DwShellRoutePageBuilder? get shellRouteBuilder =>
      (BuildContext context, GoRouterState state, Widget child) {
        final currentRoot = appRouter.rootRouteFromState(state);
        final currentIndex = currentRoot == AppRoutes.profile ? 1 : 0;
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

// -----------------------------------------------------------------------------
// Navigation parameters
// -----------------------------------------------------------------------------

enum AppParams<T> with DwNavigationParamsMixin<T> {
  bookId<int>();
}

// -----------------------------------------------------------------------------
// Router state (used by guards and pages)
// -----------------------------------------------------------------------------

class AppSession extends ChangeNotifier {
  static final AppSession _instance = AppSession._();
  factory AppSession() => _instance;
  AppSession._();

  bool _isLoggedIn = false;
  bool get isLoggedIn => _isLoggedIn;

  void login() {
    _isLoggedIn = true;
    notifyListeners();
  }

  void logout() {
    _isLoggedIn = false;
    notifyListeners();
  }
}

// -----------------------------------------------------------------------------
// Pages
// -----------------------------------------------------------------------------

class AuthPage extends StatelessWidget {
  const AuthPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Login')),
      body: Center(
        child: ElevatedButton(
          onPressed: () {
            AppSession().login();
            context.goNamed(AppRoutes.catalog.name);
          },
          child: const Text('Authorize'),
        ),
      ),
    );
  }
}

class BookListPage extends StatelessWidget {
  const BookListPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Catalog')),
      body: ListView(
        children: List.generate(
          10,
          (i) => ListTile(
            title: Text('Book $i'),
            onTap: () => context.goNamed(
              AppRoutes.bookDetail.name,
              pathParameters: AppParams.bookId.set(i),
            ),
          ),
        ),
      ),
    );
  }
}

class BookDetailPage extends StatelessWidget {
  const BookDetailPage({super.key});

  @override
  Widget build(BuildContext context) {
    final bookId = AppParams.bookId.fromPath(context);
    return Scaffold(
      appBar: AppBar(title: Text('Book $bookId')),
      body: Center(child: Text('Detail for book ID: $bookId')),
    );
  }
}

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: Center(
        child: ElevatedButton(
          onPressed: () {
            AppSession().logout();
            context.goNamed(AuthRoutes.auth.name);
          },
          child: const Text('Logout'),
        ),
      ),
    );
  }
}
