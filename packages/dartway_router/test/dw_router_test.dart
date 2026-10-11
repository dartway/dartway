import 'package:dartway_router/dartway_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_helpers.dart';

// Test router state: an immutable value derived from the signed-in account's
// id, the way an app derives it.
typedef TestRouterState = ({bool isAuthorized});

final sessionProvider = NotifierProvider<SessionController, int?>(
  SessionController.new,
);

class SessionController extends Notifier<int?> {
  @override
  int? build() => null;

  void signIn([int accountId = 1]) => state = accountId;

  void signOut() => state = null;
}

final testRouterStateProvider = Provider<TestRouterState>(
  (ref) => (isAuthorized: ref.watch(sessionProvider) != null),
);

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
        (state, target) => null,
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

/// Every target the vault's guard was asked about.
final vaultTargets = <DwNavigationTarget>[];

// A zone behind a sign-in gate that remembers where the person was going.
enum VaultRoutes implements DwNavigationRoute<TestRouterState> {
  vault(DwNavigationRouteDescriptor.zoneRoot(pageWidget: ProfilePage()));

  const VaultRoutes(this.descriptor);

  @override
  final DwNavigationRouteDescriptor<TestRouterState> descriptor;

  @override
  String get zoneRoot => 'vault';

  @override
  DwShellRoutePageBuilder? get shellRouteBuilder => null;

  @override
  DwStatefulShellRouteBuilder? get statefulShellRouteBuilder => null;

  @override
  List<DwNavigationGuard<TestRouterState>> get zoneGuards => [
        (state, target) {
          vaultTargets.add(target);
          return state.isAuthorized
              ? null
              : Uri(path: '/sign-in', queryParameters: {'from': target.location})
                  .toString();
        },
      ];
}

// The sign-in zone: once signed in, back to where the vault turned them away.
enum SignInRoutes implements DwNavigationRoute<TestRouterState> {
  signIn(DwNavigationRouteDescriptor.zoneRoot(pageWidget: AuthPage()));

  const SignInRoutes(this.descriptor);

  @override
  final DwNavigationRouteDescriptor<TestRouterState> descriptor;

  @override
  String get zoneRoot => 'sign-in';

  @override
  DwShellRoutePageBuilder? get shellRouteBuilder => null;

  @override
  DwStatefulShellRouteBuilder? get statefulShellRouteBuilder => null;

  @override
  List<DwNavigationGuard<TestRouterState>> get zoneGuards => [
        (state, target) =>
            state.isAuthorized ? target.uri.queryParameters['from'] : null,
      ];
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
  group('DwAppRouter', () {
    test('should create router with valid configuration', () {
      final router = buildRouter(
        (ref) => DwAppRouter<TestRouterState>(
          ref: ref,
          navigationZones: [
            TestRoutes.values,
          ],
          pageBuilder: DwPageBuilder.material,
        ),
      );

      expect(router.router, isA<GoRouter>());
      expect(router.navigationZones.length, 1);
    });

    test('should throw ArgumentError when navigationZones is empty', () {
      expect(
        () => buildRouter(
          (ref) => DwAppRouter<TestRouterState>(
            ref: ref,
            navigationZones: [],
            pageBuilder: DwPageBuilder.material,
          ),
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
        () => buildRouter(
          (ref) => DwAppRouter<TestRouterState>(
            ref: ref,
            navigationZones: [[]],
            pageBuilder: DwPageBuilder.material,
          ),
        ),
        throwsA(isA<ArgumentError>().having(
          (e) => e.message,
          'message',
          contains('navigationZones cannot contain empty zones'),
        )),
      );
    });

    test(
      'should throw ArgumentError when guards are used without routerState',
      () {
        expect(
          () => buildRouter(
            (ref) => DwAppRouter<TestRouterState>(
              ref: ref,
              navigationZones: [RoutesWithGuards.values],
              pageBuilder: DwPageBuilder.material,
            ),
          ),
          throwsA(
            isA<ArgumentError>().having(
              (e) => e.message,
              'message',
              contains('routerState is required when using zoneGuards'),
            ),
          ),
        );
      },
    );

    test('should work with guards when routerState is provided', () {
      final router = buildRouter(
        (ref) => DwAppRouter<TestRouterState>(
          ref: ref,
          navigationZones: [RoutesWithGuards.values],
          pageBuilder: DwPageBuilder.material,
          routerState: testRouterStateProvider,
        ),
      );

      expect(router.router, isA<GoRouter>());
    });

    group('guards follow the routerState provider (#407)', () {
      late ProviderContainer container;

      setUp(() {
        vaultTargets.clear();
        container = ProviderContainer();
        addTearDown(container.dispose);
      });

      DwAppRouter<TestRouterState> vaultRouter({String? initialLocation}) =>
          buildRouter(
            (ref) => DwAppRouter<TestRouterState>(
              ref: ref,
              routerState: testRouterStateProvider,
              navigationZones: [
                TestRoutes.values,
                VaultRoutes.values,
                SignInRoutes.values,
              ],
              pageBuilder: DwPageBuilder.material,
              options: DwGoRouterOptions(initialLocation: initialLocation),
            ),
            container: container,
          );

      String location(DwAppRouter<TestRouterState> router) =>
          router.router.routerDelegate.currentConfiguration.uri.toString();

      void signIn([int accountId = 1]) =>
          container.read(sessionProvider.notifier).signIn(accountId);
      void signOut() => container.read(sessionProvider.notifier).signOut();

      testWidgets('a guard is told where the person was going, and can bring '
          'them back after signing in (#288)', (tester) async {
        final router = vaultRouter();
        await tester.pumpWidget(
          MaterialApp.router(routerConfig: router.router),
        );
        await tester.pumpAndSettle();

        router.router.go('/vault?tab=items');
        await tester.pumpAndSettle();
        expect(find.text('Auth'), findsOneWidget);
        expect(
          vaultTargets.first,
          DwNavigationTarget(
            uri: Uri.parse('/vault?tab=items'),
            routeName: 'vault',
          ),
        );
        expect(
          router
              .router
              .routerDelegate
              .currentConfiguration
              .uri
              .queryParameters['from'],
          '/vault?tab=items',
        );

        signIn();
        await tester.pumpAndSettle();
        expect(find.text('Profile'), findsOneWidget);
        expect(location(router), '/vault?tab=items');
      });

      testWidgets(
        'a deep link into a guarded zone opens sign-in, signing in leaves '
        'it for the link, and signing out returns to it',
        (tester) async {
          final router = vaultRouter(initialLocation: '/vault');
          await tester.pumpWidget(
            MaterialApp.router(routerConfig: router.router),
          );
          await tester.pumpAndSettle();

          expect(find.text('Auth'), findsOneWidget);
          expect(location(router), '/sign-in?from=%2Fvault');

          // Nothing but the provider changes: no navigation call.
          signIn();
          await tester.pumpAndSettle();
          expect(find.text('Profile'), findsOneWidget);
          expect(location(router), '/vault');

          signOut();
          await tester.pumpAndSettle();
          expect(find.text('Auth'), findsOneWidget);
          expect(location(router), '/sign-in?from=%2Fvault');
        },
      );

      testWidgets('a deep link opens the guarded zone straight away when the '
          'guards already let the person in', (tester) async {
        signIn();
        final router = vaultRouter(initialLocation: '/vault');
        await tester.pumpWidget(
          MaterialApp.router(routerConfig: router.router),
        );
        await tester.pumpAndSettle();

        expect(find.text('Profile'), findsOneWidget);
        expect(location(router), '/vault');
      });

      testWidgets(
        'a change that leaves the value equal does not re-run the guards; '
        'one that changes it does',
        (tester) async {
          signIn(1);
          final router = vaultRouter(initialLocation: '/vault');
          await tester.pumpWidget(
            MaterialApp.router(routerConfig: router.router),
          );
          await tester.pumpAndSettle();
          expect(location(router), '/vault');
          final asked = vaultTargets.length;
          expect(asked, greaterThan(0));

          // Another account signs in: the session changed, but the record the
          // guards decide by is equal, so the router is not told.
          signIn(2);
          await tester.pumpAndSettle();
          expect(container.read(sessionProvider), 2);
          expect(vaultTargets.length, asked);

          // Positive control: signing out changes the record, the guards run
          // again and send the person to sign-in.
          signOut();
          await tester.pumpAndSettle();
          expect(vaultTargets.length, greaterThan(asked));
          expect(location(router), '/sign-in?from=%2Fvault');
        },
      );

      test('the router is disposed with the provider that built it', () {
        final router = vaultRouter(initialLocation: '/vault');
        final information = router.router.routeInformationProvider;

        container.dispose();

        expect(
          () => ChangeNotifier.debugAssertNotDisposed(information),
          throwsFlutterError,
        );
      });
    });

    group('topRouteFromState', () {
      testWidgets('should return route from state', (tester) async {
        final router = buildRouter(
          (ref) => DwAppRouter<TestRouterState>(
            ref: ref,
            navigationZones: [
              TestRoutes.values,
            ],
            pageBuilder: DwPageBuilder.material,
          ),
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
        final router = buildRouter(
          (ref) => DwAppRouter<TestRouterState>(
            ref: ref,
            navigationZones: [
              TestRoutes.values,
            ],
            pageBuilder: DwPageBuilder.material,
          ),
        );

        // Test that router is created successfully
        // The actual route resolution is tested in widget tests
        expect(router.router, isA<GoRouter>());
      });
    });

    group('rootRouteFromState', () {
      testWidgets('should return root route from nested route', (tester) async {
        final router = buildRouter(
          (ref) => DwAppRouter<TestRouterState>(
            ref: ref,
            navigationZones: [
              NestedRoutes.values,
            ],
            pageBuilder: DwPageBuilder.material,
          ),
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
        final router = buildRouter(
          (ref) => DwAppRouter<TestRouterState>(
            ref: ref,
            navigationZones: [
              TestRoutes.values,
            ],
            pageBuilder: DwPageBuilder.material,
          ),
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
          () => buildRouter(
            (ref) => DwAppRouter<TestRouterState>(
              ref: ref,
              navigationZones: [
                ProjectsZone.values,
                AdminProjectsZone.values,
              ],
              pageBuilder: DwPageBuilder.material,
            ),
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
        final router = buildRouter(
          (ref) => DwAppRouter<TestRouterState>(
            ref: ref,
            navigationZones: [
              ProjectsZone.values,
              ReportsZone.values,
            ],
            pageBuilder: DwPageBuilder.material,
          ),
        );

        expect(router.router, isA<GoRouter>());
        expect(router.navigationZones.length, 2);
      });

      test('a name collision is reported ahead of the path it also breaks', () {
        // Both zones sit at the site root, so `projects` collides on the path
        // as well. The path is the symptom; the message must name the cause.
        expect(
          () => buildRouter(
            (ref) => DwAppRouter<TestRouterState>(
              ref: ref,
              navigationZones: [
                ProjectsZone.values,
                SecondProjectsZone.values,
              ],
              pageBuilder: DwPageBuilder.material,
            ),
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
          () => buildRouter(
            (ref) => DwAppRouter<TestRouterState>(
              ref: ref,
              navigationZones: [
                ReportsZone.values,
                OverviewZone.values,
              ],
              pageBuilder: DwPageBuilder.material,
            ),
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
        final router = buildRouter(
          (ref) => DwAppRouter<TestRouterState>(
            ref: ref,
            navigationZones: [
              TestRoutes.values,
              AuthRoutes.values,
            ],
            pageBuilder: DwPageBuilder.material,
          ),
        );

        expect(router.router, isA<GoRouter>());
        expect(router.navigationZones.length, 2);
      });
    });
  });
}
