import 'package:dartway_router/dartway_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Test router state
class TestRouterState extends ChangeNotifier {}

// Test routes
enum TestRoutes implements DwNavigationRoute<TestRouterState> {
  home(DwNavigationRouteDescriptor.zoneRoot(pageWidget: HomePage())),
  profile(
    DwNavigationRouteDescriptor.simple(
      pageWidget: ProfilePage(),
    ),
  ),
  userDetail(
    DwNavigationRouteDescriptor.parameterized(
      pageWidget: UserDetailPage(),
      parameter: TestParams.userId,
      parent: home,
    ),
  ),
  nested(
    DwNavigationRouteDescriptor.simple(
      pageWidget: NestedPage(),
      parent: home,
      extraPathSegment: 'extra',
    ),
  );

  const TestRoutes(this.descriptor);

  @override
  final DwNavigationRouteDescriptor<TestRouterState> descriptor;

  @override
  String get zoneRoot => '';

  @override
  DwShellRoutePageBuilder? get shellRouteBuilder => null;

  @override
  List<DwNavigationGuard<TestRouterState>> get zoneGuards => [];
}

// Test pages
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) => const Text('Home');
}

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) => const Text('Profile');
}

class UserDetailPage extends StatelessWidget {
  const UserDetailPage({super.key});

  @override
  Widget build(BuildContext context) => const Text('UserDetail');
}

class NestedPage extends StatelessWidget {
  const NestedPage({super.key});

  @override
  Widget build(BuildContext context) => const Text('Nested');
}

// Test params
enum TestParams<T> with DwNavigationParamsMixin<T> {
  userId<int>();
}

void main() {
  group('DwNavigationRouteExtension', () {
    group('routePath', () {
      test('should return path with zone root for root route', () {
        // zoneRoot route returns '/' as routePath
        expect(TestRoutes.home.routePath, '/');
      });

      test('should return path with route name for simple route', () {
        // Simple route without parent returns full path from root
        expect(TestRoutes.profile.routePath, '/profile');
      });

      test('should return relative path for parameterized child route', () {
        // Child route (with parent) returns only its path segment, not full path
        expect(TestRoutes.userDetail.routePath, ':userId');
      });

      test('should return relative path with extra segment for nested route',
          () {
        // Child route (with parent) returns only its path segment including extraPathSegment
        expect(TestRoutes.nested.routePath, 'extra/nested');
      });
    });

    group('fullPath', () {
      test('should return same as routePath for root route', () {
        // For root routes, fullPath equals routePath
        expect(TestRoutes.home.fullPath, TestRoutes.home.routePath);
        expect(TestRoutes.home.fullPath, '/');
      });

      test('should include parent path for child route', () {
        // fullPath includes parent's fullPath + current path segment
        // home.fullPath = '/' + userDetail._path = ':userId'
        expect(TestRoutes.userDetail.fullPath, '/:userId');
      });

      test('should include full hierarchy for nested route', () {
        // fullPath includes parent's fullPath + current path segment
        // home.fullPath = '/' + nested._path = 'extra/nested'
        expect(TestRoutes.nested.fullPath, '/extra/nested');
      });
    });

    group('isActive', () {
      testWidgets('should return true when route is active', (tester) async {
        final navigatorKey = GlobalKey<NavigatorState>();
        final router = GoRouter(
          navigatorKey: navigatorKey,
          initialLocation: '/profile',
          routes: [
            GoRoute(
              path: '/',
              name: 'home',
              builder: (context, state) => const HomePage(),
            ),
            GoRoute(
              path: '/profile',
              name: 'profile',
              builder: (context, state) => const ProfilePage(),
            ),
          ],
        );

        await tester.pumpWidget(
          MaterialApp.router(routerConfig: router),
        );
        await tester.pumpAndSettle();

        final context = tester.element(find.byType(ProfilePage));
        expect(TestRoutes.profile.isActive(context), isTrue);
        expect(TestRoutes.home.isActive(context), isFalse);
      });

      testWidgets('should return false when route is not active',
          (tester) async {
        final navigatorKey = GlobalKey<NavigatorState>();
        final router = GoRouter(
          navigatorKey: navigatorKey,
          initialLocation: '/',
          routes: [
            GoRoute(
              path: '/',
              name: 'home',
              builder: (context, state) => const HomePage(),
            ),
            GoRoute(
              path: '/profile',
              name: 'profile',
              builder: (context, state) => const ProfilePage(),
            ),
          ],
        );

        await tester.pumpWidget(
          MaterialApp.router(routerConfig: router),
        );
        await tester.pumpAndSettle();

        final context = tester.element(find.byType(HomePage));
        expect(TestRoutes.profile.isActive(context), isFalse);
        expect(TestRoutes.home.isActive(context), isTrue);
      });

      testWidgets('should return true for nested routes', (tester) async {
        final navigatorKey = GlobalKey<NavigatorState>();
        final router = GoRouter(
          navigatorKey: navigatorKey,
          initialLocation: '/extra/nested',
          routes: [
            GoRoute(
              path: '/',
              name: 'home',
              builder: (context, state) => const HomePage(),
              routes: [
                GoRoute(
                  path: 'extra/nested',
                  name: 'nested',
                  builder: (context, state) => const NestedPage(),
                ),
              ],
            ),
          ],
        );

        await tester.pumpWidget(
          MaterialApp.router(routerConfig: router),
        );
        await tester.pumpAndSettle();

        final context = tester.element(find.byType(NestedPage));
        // fullPath should be '/extra/nested' which matches the actual route
        expect(TestRoutes.nested.fullPath, '/extra/nested');
        expect(TestRoutes.nested.isActive(context), isTrue);
      });
    });
  });
}
