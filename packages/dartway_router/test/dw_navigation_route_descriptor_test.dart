import 'package:dartway_router/dartway_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Test router state
class TestRouterState extends ChangeNotifier {}

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
  List<DwNavigationGuard<TestRouterState>> get zoneGuards => [];
}

// Test params
enum TestParams<T> with DwNavigationParamsMixin<T> {
  userId<int>();
}

void main() {
  group('DwNavigationRouteDescriptor', () {
    group('zoneRoot', () {
      test('should create zone root descriptor', () {
        final descriptor = DwNavigationRouteDescriptor.zoneRoot(
          pageWidget: const HomePage(),
        );

        expect(descriptor.pageWidget, isA<HomePage>());
        expect(descriptor.parent, isNull);
        expect(descriptor.extraPathSegment, isNull);
        expect(descriptor.pathSegment('home'), '');
      });
    });

    group('simple', () {
      test('should create simple descriptor', () {
        final descriptor = DwNavigationRouteDescriptor.simple(
          pageWidget: const ProfilePage(),
        );

        expect(descriptor.pageWidget, isA<ProfilePage>());
        expect(descriptor.parent, isNull);
        expect(descriptor.extraPathSegment, isNull);
        expect(descriptor.pathSegment('profile'), 'profile');
      });

      test('should create simple descriptor with parent', () {
        final parent = TestRoutes.home;
        final descriptor = DwNavigationRouteDescriptor.simple(
          pageWidget: const ProfilePage(),
          parent: parent,
        );

        expect(descriptor.parent, parent);
        expect(descriptor.pathSegment('profile'), 'profile');
      });

      test('should create simple descriptor with extraPathSegment', () {
        final descriptor = DwNavigationRouteDescriptor.simple(
          pageWidget: const ProfilePage(),
          extraPathSegment: 'users',
        );

        expect(descriptor.extraPathSegment, 'users');
        expect(descriptor.pathSegment('profile'), 'users/profile');
      });
    });

    group('parameterized', () {
      test('should create parameterized descriptor', () {
        final parent = TestRoutes.home;
        final descriptor = DwNavigationRouteDescriptor.parameterized(
          pageWidget: const ProfilePage(),
          parameter: TestParams.userId,
          parent: parent,
        );

        expect(descriptor.pageWidget, isA<ProfilePage>());
        expect(descriptor.parent, parent);
        expect(descriptor.pathSegment('detail'), ':userId');
      });

      test('should create parameterized descriptor with extraPathSegment', () {
        final parent = TestRoutes.home;
        final descriptor = DwNavigationRouteDescriptor.parameterized(
          pageWidget: const ProfilePage(),
          parameter: TestParams.userId,
          parent: parent,
          extraPathSegment: 'users',
        );

        expect(descriptor.extraPathSegment, 'users');
        expect(descriptor.pathSegment('detail'), 'users/:userId');
      });
    });

    group('pathSegment', () {
      test('zone root should return empty string', () {
        final descriptor = DwNavigationRouteDescriptor.zoneRoot(
          pageWidget: const HomePage(),
        );
        expect(descriptor.pathSegment('home'), '');
      });

      test('simple should return route name', () {
        final descriptor = DwNavigationRouteDescriptor.simple(
          pageWidget: const ProfilePage(),
        );
        expect(descriptor.pathSegment('profile'), 'profile');
      });

      test('parameterized should return parameter name with colon', () {
        final parent = TestRoutes.home;
        final descriptor = DwNavigationRouteDescriptor.parameterized(
          pageWidget: const ProfilePage(),
          parameter: TestParams.userId,
          parent: parent,
        );
        expect(descriptor.pathSegment('detail'), ':userId');
      });
    });
  });
}
