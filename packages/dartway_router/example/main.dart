// Example: two navigation zones (auth + app) with a guard using AppSession.

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

final appRouter = DwAppRouter<AppSession>(
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
  DwStatefulShellRouteBuilder? get statefulShellRouteBuilder => null;

  @override
  List<DwNavigationGuard<AppSession>> get zoneGuards => [
        // Signed in: on to where the app zone turned them away from — one of
        // the app's own paths, whatever else the link says.
        (session, target) => session.isLoggedIn
            ? _ownPath(target.uri.queryParameters['from']) ??
                AppRoutes.catalog.fullPath
            : null,
      ];
}

/// [location] when it is one of this app's own paths: a leading `/`, not `//`
/// — anything outside the app can write the link.
String? _ownPath(String? location) =>
    location != null && location.startsWith('/') && !location.startsWith('//')
        ? location
        : null;

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
  DwShellRoutePageBuilder? get shellRouteBuilder => null;

  @override
  DwStatefulShellRouteBuilder? get statefulShellRouteBuilder =>
      (BuildContext context, GoRouterState state, StatefulNavigationShell navigationShell) {
        return DwPageBuilder.fade(
          context,
          state.pageKey,
          Scaffold(
            body: navigationShell,
            bottomNavigationBar: BottomNavigationBar(
              currentIndex: navigationShell.currentIndex,
              onTap: (i) => navigationShell.goBranch(
                i,
                initialLocation: i == navigationShell.currentIndex,
              ),
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

  @override
  List<DwNavigationGuard<AppSession>> get zoneGuards => [
        // Signed out: to sign-in, remembering where they were going.
        (session, target) => session.isLoggedIn
            ? null
            : Uri(
                path: AuthRoutes.auth.fullPath,
                queryParameters: {'from': target.location},
              ).toString(),
      ];
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
