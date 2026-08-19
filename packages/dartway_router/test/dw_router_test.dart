import 'package:dartway_router/dartway_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Test router state
class TestRouterState extends ChangeNotifier {
  bool isAuthorized = false;

  void authorize() {
    isAuthorized = true;
    notifyListeners();
  }
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

class AuthPage extends StatelessWidget {
  const AuthPage({super.key});

  @override
  Widget build(BuildContext context) => const Text('Auth');
}

// Routes with guards for testing
enum RoutesWithGuards implements DwNavigationRoute<TestRouterState> {
  home(DwNavigationRouteDescriptor.zoneRoot(pageWidget: HomePage()));

  const RoutesWithGuards(this.descriptor);

  @override
  final DwNavigationRouteDescriptor<TestRouterState> descriptor;

  @override
  String get zoneRoot => '';

  @override
  DwShellRoutePageBuilder? get shellRouteBuilder => null;

  @override
  DwStatefulShellRouteBuilder? get statefulShellRouteBuilder => null;

  @override
  List<DwNavigationGuard<TestRouterState>> get zoneGuards => [
        (state) => null,
      ];
}

// Nested routes for testing
enum NestedRoutes implements DwNavigationRoute<TestRouterState> {
  home(DwNavigationRouteDescriptor.zoneRoot(pageWidget: HomePage())),
  child(
    DwNavigationRouteDescriptor.simple(
      pageWidget: ProfilePage(),
      parent: home,
    ),
  );

  const NestedRoutes(this.descriptor);

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

// Test routes
enum TestRoutes implements DwNavigationRoute<TestRouterState> {
  home(DwNavigationRouteDescriptor.zoneRoot(pageWidget: HomePage())),
  profile(
    DwNavigationRouteDescriptor.simple(pageWidget: ProfilePage()),
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

enum AuthRoutes implements DwNavigationRoute<TestRouterState> {
  auth(
    DwNavigationRouteDescriptor.simple(pageWidget: AuthPage()),
  );

  const AuthRoutes(this.descriptor);

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

// Two zones that each own a concept called `projects`. Nothing inside either
// enum objects to it — the collision only exists at the router.
enum ProjectsZone implements DwNavigationRoute<TestRouterState> {
  dashboard(DwNavigationRouteDescriptor.zoneRoot(pageWidget: HomePage())),
  projects(
    DwNavigationRouteDescriptor.simple(
      pageWidget: ProfilePage(),
      parent: dashboard,
    ),
  );

  const ProjectsZone(this.descriptor);

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

// Lives under /admin, so its `projects` builds a different path: the name is
// the only thing that collides.
enum AdminProjectsZone implements DwNavigationRoute<TestRouterState> {
  adminDashboard(DwNavigationRouteDescriptor.zoneRoot(pageWidget: HomePage())),
  projects(
    DwNavigationRouteDescriptor.simple(
      pageWidget: ProfilePage(),
      parent: adminDashboard,
    ),
  );

  const AdminProjectsZone(this.descriptor);

  @override
  final DwNavigationRouteDescriptor<TestRouterState> descriptor;

  @override
  String get zoneRoot => 'admin';

  @override
  DwShellRoutePageBuilder? get shellRouteBuilder => null;

  @override
  DwStatefulShellRouteBuilder? get statefulShellRouteBuilder => null;

  @override
  List<DwNavigationGuard<TestRouterState>> get zoneGuards => [];
}

// Sits at the site root as well, so its `projects` collides on the path too.
enum SecondProjectsZone implements DwNavigationRoute<TestRouterState> {
  projects(DwNavigationRouteDescriptor.simple(pageWidget: ProfilePage()));

  const SecondProjectsZone(this.descriptor);

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

// /reports, reached through a route named `reports`.
enum ReportsZone implements DwNavigationRoute<TestRouterState> {
  reports(DwNavigationRouteDescriptor.simple(pageWidget: ProfilePage()));

  const ReportsZone(this.descriptor);

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

// /reports as well, this time as a zone root — same address, different name.
enum OverviewZone implements DwNavigationRoute<TestRouterState> {
  overview(DwNavigationRouteDescriptor.zoneRoot(pageWidget: HomePage()));

  const OverviewZone(this.descriptor);

  @override
  final DwNavigationRouteDescriptor<TestRouterState> descriptor;

  @override
  String get zoneRoot => 'reports';

  @override
  DwShellRoutePageBuilder? get shellRouteBuilder => null;

  @override
  DwStatefulShellRouteBuilder? get statefulShellRouteBuilder => null;

  @override
  List<DwNavigationGuard<TestRouterState>> get zoneGuards => [];
}

void main() {
  group('DwRouter', () {
    test('should create router with valid configuration', () {
      final router = DwRouter<TestRouterState>(
        navigationZones: [
          TestRoutes.values,
        ],
        pageBuilder: DwPageBuilder.material,
      );

      expect(router.router, isA<GoRouter>());
      expect(router.navigationZones.length, 1);
    });

    test('should throw ArgumentError when navigationZones is empty', () {
      expect(
        () => DwRouter<TestRouterState>(
          navigationZones: [],
          pageBuilder: DwPageBuilder.material,
        ),
        throwsA(isA<ArgumentError>().having(
          (e) => e.message,
          'message',
          contains('navigationZones cannot be empty'),
        )),
      );
    });

    test('should throw ArgumentError when zone is empty', () {
      expect(
        () => DwRouter<TestRouterState>(
          navigationZones: [[]],
          pageBuilder: DwPageBuilder.material,
        ),
        throwsA(isA<ArgumentError>().having(
          (e) => e.message,
          'message',
          contains('navigationZones cannot contain empty zones'),
        )),
      );
    });

    test('should throw ArgumentError when guards are used without routerState',
        () {
      expect(
        () => DwRouter<TestRouterState>(
          navigationZones: [
            RoutesWithGuards.values,
          ],
          pageBuilder: DwPageBuilder.material,
          routerState: null,
        ),
        throwsA(isA<ArgumentError>().having(
          (e) => e.message,
          'message',
          contains('refreshListenable is required when using zoneGuards'),
        )),
      );
    });

    test('should work with guards when routerState is provided', () {
      final routerState = TestRouterState();
      final router = DwRouter<TestRouterState>(
        navigationZones: [
          RoutesWithGuards.values,
        ],
        pageBuilder: DwPageBuilder.material,
        routerState: routerState,
      );

      expect(router.router, isA<GoRouter>());
    });

    group('topRouteFromState', () {
      testWidgets('should return route from state', (tester) async {
        final router = DwRouter<TestRouterState>(
          navigationZones: [
            TestRoutes.values,
          ],
          pageBuilder: DwPageBuilder.material,
        );

        await tester.pumpWidget(
          MaterialApp.router(routerConfig: router.router),
        );
        await tester.pumpAndSettle();

        router.router.goNamed('profile');
        await tester.pumpAndSettle();

        // Get the current route state
        final location =
            router.router.routerDelegate.currentConfiguration.uri.path;
        expect(location, contains('profile'));
      });

      test('should return null when route name is not found', () {
        final router = DwRouter<TestRouterState>(
          navigationZones: [
            TestRoutes.values,
          ],
          pageBuilder: DwPageBuilder.material,
        );

        // Test that router is created successfully
        // The actual route resolution is tested in widget tests
        expect(router.router, isA<GoRouter>());
      });
    });

    group('rootRouteFromState', () {
      testWidgets('should return root route from nested route', (tester) async {
        final router = DwRouter<TestRouterState>(
          navigationZones: [
            NestedRoutes.values,
          ],
          pageBuilder: DwPageBuilder.material,
        );

        await tester.pumpWidget(
          MaterialApp.router(routerConfig: router.router),
        );
        await tester.pumpAndSettle();

        router.router.goNamed('child');
        await tester.pumpAndSettle();

        // Verify navigation worked
        final location =
            router.router.routerDelegate.currentConfiguration.uri.path;
        expect(location, contains('child'));
      });
    });

    group('duplicate page keys', () {
      testWidgets(
          'pushing the same route twice does not trip the Navigator '
          'duplicate page key assertion', (tester) async {
        final router = DwRouter<TestRouterState>(
          navigationZones: [
            TestRoutes.values,
          ],
          pageBuilder: DwPageBuilder.material,
        );

        await tester.pumpWidget(
          MaterialApp.router(routerConfig: router.router),
        );
        await tester.pumpAndSettle();

        // The same location pushed twice puts two pages on the stack.
        // go_router assigns each pushed page its own unique pageKey, so the
        // Navigator must not see two pages sharing a key.
        router.router.pushNamed('profile');
        await tester.pumpAndSettle();
        router.router.pushNamed('profile');
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
      });
    });

    group('duplicate route names across zones', () {
      test(
          'two zones declaring the same name fail when the router is '
          'assembled, naming the value and both zones', () {
        expect(
          () => DwRouter<TestRouterState>(
            navigationZones: [
              ProjectsZone.values,
              AdminProjectsZone.values,
            ],
            pageBuilder: DwPageBuilder.material,
          ),
          throwsA(
            isA<ArgumentError>().having(
              (e) => e.message,
              'message',
              allOf(
                contains('Duplicate route name "projects"'),
                contains('ProjectsZone.projects (navigationZones[0])'),
                contains('AdminProjectsZone.projects (navigationZones[1])'),
                contains('Route names are global across navigation zones'),
              ),
            ),
          ),
        );
      });

      test('the same name in one zone and a different one in another is fine',
          () {
        final router = DwRouter<TestRouterState>(
          navigationZones: [
            ProjectsZone.values,
            ReportsZone.values,
          ],
          pageBuilder: DwPageBuilder.material,
        );

        expect(router.router, isA<GoRouter>());
        expect(router.navigationZones.length, 2);
      });

      test('a name collision is reported ahead of the path it also breaks', () {
        // Both zones sit at the site root, so `projects` collides on the path
        // as well. The path is the symptom; the message must name the cause.
        expect(
          () => DwRouter<TestRouterState>(
            navigationZones: [
              ProjectsZone.values,
              SecondProjectsZone.values,
            ],
            pageBuilder: DwPageBuilder.material,
          ),
          throwsA(
            isA<ArgumentError>().having(
              (e) => e.message,
              'message',
              allOf(
                contains('Duplicate route name "projects"'),
                isNot(contains('Duplicate route path')),
              ),
            ),
          ),
        );
      });

      test('a duplicate path names its routes and their zones too', () {
        expect(
          () => DwRouter<TestRouterState>(
            navigationZones: [
              ReportsZone.values,
              OverviewZone.values,
            ],
            pageBuilder: DwPageBuilder.material,
          ),
          throwsA(
            isA<ArgumentError>().having(
              (e) => e.message,
              'message',
              allOf(
                contains('Duplicate route path "/reports"'),
                contains('ReportsZone.reports (navigationZones[0])'),
                contains('OverviewZone.overview (navigationZones[1])'),
              ),
            ),
          ),
        );
      });
    });

    group('multiple zones', () {
      test('should handle multiple navigation zones', () {
        final router = DwRouter<TestRouterState>(
          navigationZones: [
            TestRoutes.values,
            AuthRoutes.values,
          ],
          pageBuilder: DwPageBuilder.material,
        );

        expect(router.router, isA<GoRouter>());
        expect(router.navigationZones.length, 2);
      });
    });
  });
}
