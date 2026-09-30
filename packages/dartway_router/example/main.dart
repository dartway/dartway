// Example: two navigation zones (auth + app) with a guard using AppSession.

import 'package:dartway_router/dartway_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// -----------------------------------------------------------------------------
// Entry point & app
// -----------------------------------------------------------------------------

void main() {
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'DartWay Router Example',
      theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: true),
      routerConfig: ref.watch(appRouterProvider).router,
    );
  }
}

// -----------------------------------------------------------------------------
// Router (defined after route enums)
// -----------------------------------------------------------------------------

// The router follows appSessionProvider: signing in or out re-runs the
// guards, which move the person between the zones — no page navigates itself.
final appRouterProvider = Provider<DwAppRouter<AppSession>>(
  (ref) => DwAppRouter<AppSession>(
    ref: ref,
    routerState: appSessionProvider,
    navigationZones: [AppRoutes.values, AuthRoutes.values],
    pageBuilder: DwPageBuilder.fade,
    options: DwGoRouterOptions(
      initialLocation: AuthRoutes.auth.fullPath,
      debugLogDiagnostics: true,
    ),
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
      (
        BuildContext context,
        GoRouterState state,
        StatefulNavigationShell navigationShell,
      ) {
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

enum AppParams<T> with DwNavigationParamsMixin<T> { bookId<int>() }

// -----------------------------------------------------------------------------
// Router state (used by guards and pages)
// -----------------------------------------------------------------------------

/// What the guards decide by: an immutable value, so the router re-runs them
/// only when it actually changes.
typedef AppSession = ({bool isLoggedIn});

final appSessionProvider = NotifierProvider<AppSessionController, AppSession>(
  AppSessionController.new,
);

class AppSessionController extends Notifier<AppSession> {
  @override
  AppSession build() => (isLoggedIn: false);

  void login() => state = (isLoggedIn: true);

  void logout() => state = (isLoggedIn: false);
}

// -----------------------------------------------------------------------------
// Pages
// -----------------------------------------------------------------------------

class AuthPage extends ConsumerWidget {
  const AuthPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Login')),
      body: Center(
        child: ElevatedButton(
          onPressed: () => ref.read(appSessionProvider.notifier).login(),
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

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: Center(
        child: ElevatedButton(
          onPressed: () => ref.read(appSessionProvider.notifier).logout(),
          child: const Text('Logout'),
        ),
      ),
    );
  }
}
