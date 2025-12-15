import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dartway_router/dartway_router.dart';

void main() {
  group('DwRouter', () {
    test('should create router with valid navigation zones', () {
      expect(() {
        DwRouter.config().addNavigationZones([TestRoutes.values]).build();
      }, returnsNormally);
    });

    test('should throw error with empty navigation zones', () {
      expect(() {
        DwRouter.config().build();
      }, throwsArgumentError);
    });

    test('should throw error with empty zone in navigation zones', () {
      expect(() {
        DwRouter.config().addNavigationZones([[]]).build();
      }, throwsArgumentError);
    });

    test('should validate duplicate route paths', () {
      expect(() {
        DwRouter.config()
            .addNavigationZones([DuplicateTestRoutes.values]).build();
      }, throwsArgumentError);
    });
  });

  group('DwRouterConfig', () {
    test('should validate empty navigation zones', () {
      final config = DwRouterConfig();
      expect(() => config.build(), throwsArgumentError);
    });

    test('should validate initial location format', () {
      expect(() {
        DwRouter.config()
            .addNavigationZones([TestRoutes.values])
            .setInitialLocation('invalid-location')
            .build();
      }, throwsArgumentError);
    });

    test('should validate initial location matches route', () {
      expect(() {
        DwRouter.config()
            .addNavigationZones([TestRoutes.values])
            .setInitialLocation('/nonexistent')
            .build();
      }, throwsArgumentError);
    });
  });

  group('DwNavigationUtils', () {
    test('should find matching route index', () {
      final menuItems = [
        DwMenuItem.icon(
          route: TestRoutes.home,
          displayTitle: 'Home',
          iconData: Icons.home,
        ),
        DwMenuItem.icon(
          route: TestRoutes.profile,
          displayTitle: 'Profile',
          iconData: Icons.person,
        ),
      ];

      final index = DwNavigationUtils.findMatchingRouteIndex(
        '/home',
        menuItems,
      );

      expect(index, equals(0));
    });

    test('should return -1 for no match', () {
      final menuItems = [
        DwMenuItem.icon(
          route: TestRoutes.home,
          displayTitle: 'Home',
          iconData: Icons.home,
        ),
      ];

      final index = DwNavigationUtils.findMatchingRouteIndex(
        '/nonexistent',
        menuItems,
      );

      expect(index, equals(-1));
    });
  });

  group('NavigationParamsMixin', () {
    test('should parse int values correctly', () {
      final params = {'userId': '123'};
      final value = TestNavigationParams.userId.get(params) as int;
      expect(value, equals(123));
    });

    test('should parse string values correctly', () {
      final params = {'userName': 'John'};
      final value = TestNavigationParams.userName.get(params) as String;
      expect(value, equals('John'));
    });

    test('should return null for missing parameters', () {
      final params = <String, String>{};
      final value = TestNavigationParams.userId.get(params);
      expect(value, isNull);
    });

    test('should return default value', () {
      final params = <String, String>{};
      final value = TestNavigationParams.userId.getOrDefault(params, 0);
      expect(value, equals(0));
    });
  });
}

// Test route enums
// Navigation parameters enum - single enum that can be used with different types
enum TestNavigationParams<T> with NavigationParamsMixin<T> {
  userId<int>(), // int
  userName<String>(), // String
  price<double>(), // double
  isEnabled<bool>(), // bool
}

// Navigation routes enum - clean separation from parameters
enum TestRoutes implements NavigationZoneRoute {
  home(SimpleNavigationRouteDescriptor(page: TestPage('Home'))),
  profile(SimpleNavigationRouteDescriptor(page: TestPage('Profile'))),
  user(SimpleNavigationRouteDescriptor(page: TestPage('User'))),
  userDetail(ParameterizedNavigationRouteDescriptor(
    page: TestPage('User Detail'),
    parameter: TestNavigationParams.userId,
    parent: TestRoutes.user, // Make userDetail a child of user
  )),
  userName(ParameterizedNavigationRouteDescriptor(
    page: TestPage('User Name'),
    parameter: TestNavigationParams.userName,
    parent: TestRoutes.user, // Make userName a child of user
  ));

  const TestRoutes(this.descriptor);

  @override
  final NavigationRouteDescriptor descriptor;

  @override
  String get root => '';
}

enum DuplicateTestRoutes
    with NavigationParamsMixin<int>
    implements NavigationZoneRoute {
  home1,
  home2;

  @override
  String get root => '';

  @override
  NavigationRouteDescriptor get descriptor {
    switch (this) {
      case DuplicateTestRoutes.home1:
      case DuplicateTestRoutes.home2:
        return TestNavigationRouteDescriptor(
          page: const TestPage('Home'),
          path: 'home', // Both routes will have the same path '/home'
        );
    }
  }
}

class TestPage extends StatelessWidget {
  const TestPage(this.title, {super.key});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(child: Text(title)),
    );
  }
}

// Custom descriptor for testing duplicate routes
class TestNavigationRouteDescriptor extends NavigationRouteDescriptor {
  const TestNavigationRouteDescriptor({
    required super.page,
    super.path,
    super.parent,
  });
}
