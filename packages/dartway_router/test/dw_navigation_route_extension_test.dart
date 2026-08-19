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
  DwStatefulShellRouteBuilder? get statefulShellRouteBuilder => null;

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
  userId<int>(),
  projectId<int>();
}

// A branch with a parameterized ancestor (`/project/:projectId`) plus plain
// roots, used to check what `isActive` answers at a concrete address.
enum ParameterizedRoutes implements DwNavigationRoute<TestRouterState> {
  home(DwNavigationRouteDescriptor.zoneRoot(pageWidget: LabeledPage('home'))),
  project(
    DwNavigationRouteDescriptor.parameterized(
      pageWidget: LabeledPage('project'),
      parameter: TestParams.projectId,
      parent: home,
      extraPathSegment: 'project',
    ),
  ),
  issues(
    DwNavigationRouteDescriptor.simple(
      pageWidget: LabeledPage('issues'),
      parent: project,
    ),
  ),
  milestones(
    DwNavigationRouteDescriptor.simple(
      pageWidget: LabeledPage('milestones'),
      parent: project,
    ),
  ),
  settings(
    DwNavigationRouteDescriptor.simple(pageWidget: LabeledPage('settings')),
  ),
  notifications(
    DwNavigationRouteDescriptor.simple(
      pageWidget: LabeledPage('notifications'),
      parent: settings,
    ),
  ),
  news(DwNavigationRouteDescriptor.simple(pageWidget: LabeledPage('news'))),
  newsletter(
    DwNavigationRouteDescriptor.simple(pageWidget: LabeledPage('newsletter')),
  );

  const ParameterizedRoutes(this.descriptor);

  @override
  final DwNavigationRouteDescriptor<TestRouterState> descriptor;

  @override
  String get zoneRoot => '';

  @override
  DwShellRoutePageBuilder? get shellRouteBuilder => null;

  @override
  DwStatefulShellRouteBuilder? get statefulShellRouteBuilder => null;

  @override
  List<DwNavigationGuard<TestRouterState>> get zoneGuards => [];
}

/// A page that renders its own name, so a test can reach its [BuildContext].
class LabeledPage extends StatelessWidget {
  const LabeledPage(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) => Text(label);
}

/// Builds the real router over [ParameterizedRoutes], opens [location] and
/// returns the context of the page labelled [leafLabel].
///
/// The router is built by [DwRouter] on purpose: the paths under test are the
/// ones the framework itself generates from the descriptors.
Future<BuildContext> pumpRouterAt(
  WidgetTester tester,
  String location,
  String leafLabel,
) async {
  final router = DwRouter<TestRouterState>(
    navigationZones: [ParameterizedRoutes.values],
    pageBuilder: DwPageBuilder.material,
    options: DwGoRouterOptions(initialLocation: location),
  );

  await tester.pumpWidget(MaterialApp.router(routerConfig: router.router));
  await tester.pumpAndSettle();

  return tester.element(find.text(leafLabel));
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

    group('isActive under a parameterized ancestor', () {
      testWidgets('the open route is active at its concrete address',
          (tester) async {
        final context = await pumpRouterAt(
          tester,
          '/project/7/issues',
          'issues',
        );

        // The route is declared as a template; the location is an address.
        expect(
          ParameterizedRoutes.issues.fullPath,
          '/project/:projectId/issues',
        );
        expect(ParameterizedRoutes.issues.isActive(context), isTrue);
      });

      testWidgets('the parameterized parent stays active under a child',
          (tester) async {
        final context = await pumpRouterAt(
          tester,
          '/project/7/issues',
          'issues',
        );

        expect(ParameterizedRoutes.project.isActive(context), isTrue);
      });

      testWidgets('a sibling under the same parent is not active',
          (tester) async {
        final context = await pumpRouterAt(
          tester,
          '/project/7/issues',
          'issues',
        );

        expect(ParameterizedRoutes.milestones.isActive(context), isFalse);
        expect(ParameterizedRoutes.settings.isActive(context), isFalse);
      });

      testWidgets('a parameterized route is active at its own address',
          (tester) async {
        final context = await pumpRouterAt(tester, '/project/7', 'project');

        expect(ParameterizedRoutes.project.isActive(context), isTrue);
        expect(ParameterizedRoutes.issues.isActive(context), isFalse);
      });
    });

    group('isActive without a parameterized ancestor', () {
      testWidgets('a parent stays active while its child is open',
          (tester) async {
        final context = await pumpRouterAt(
          tester,
          '/settings/notifications',
          'notifications',
        );

        expect(ParameterizedRoutes.notifications.isActive(context), isTrue);
        expect(ParameterizedRoutes.settings.isActive(context), isTrue);
        expect(ParameterizedRoutes.news.isActive(context), isFalse);
      });

      testWidgets('a string prefix of the location is not an active route',
          (tester) async {
        final context = await pumpRouterAt(tester, '/newsletter', 'newsletter');

        expect(ParameterizedRoutes.newsletter.isActive(context), isTrue);
        // '/news' is a string prefix of '/newsletter' but not a path ancestor.
        expect(ParameterizedRoutes.news.isActive(context), isFalse);
      });

      testWidgets('the zone root is active at its own address only',
          (tester) async {
        final atRoot = await pumpRouterAt(tester, '/', 'home');
        expect(ParameterizedRoutes.home.isActive(atRoot), isTrue);

        final atSettings = await pumpRouterAt(tester, '/settings', 'settings');
        // The zone root has an empty path: it is not the ancestor of the zone.
        expect(ParameterizedRoutes.home.isActive(atSettings), isFalse);
        expect(ParameterizedRoutes.settings.isActive(atSettings), isTrue);
      });
    });
  });
}
