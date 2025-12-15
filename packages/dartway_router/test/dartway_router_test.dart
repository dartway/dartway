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

    test('should configure skipZoneInRouteNames correctly', () {
      DwRouter.configure(skipZoneInRouteNames: false);
      expect(DwRouter.skipZoneInRouteNames, isFalse);

      DwRouter.configure(skipZoneInRouteNames: true);
      expect(DwRouter.skipZoneInRouteNames, isTrue);
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

    test('should build router with valid configuration', () {
      final router = DwRouter.config()
          .addNavigationZones([TestRoutes.values])
          .setNotFoundPage(const TestPage('Not Found'))
          .setInitialLocation('/home')
          .build();

      expect(router, isA<GoRouter>());
    });

    test('should support builder pattern chaining', () {
      final config = DwRouter.config()
          .addNavigationZones([TestRoutes.values])
          .setNotFoundPage(const TestPage('Not Found'))
          .setInitialLocation('/home');

      expect(config, isA<DwRouterConfig>());
      expect(() => config.build(), returnsNormally);
    });
  });

  group('NavigationParamsMixin', () {
    test('should parse int values correctly', () {
      final params = {'userId': '123'};
      final value = AppNavigationParams.userId.get(params);
      expect(value, equals(123));
    });

    test('should parse string values correctly', () {
      final params = {'userName': 'John'};
      final value = AppNavigationParams.userName.get(params) as String;
      expect(value, equals('John'));
    });

    test('should parse double values correctly', () {
      final params = {'price': '19.99'};
      final value = AppNavigationParams.price.get(params) as double;
      expect(value, equals(19.99));
    });

    test('should parse bool values correctly', () {
      final params = {'enabled': 'true'};
      final value = AppNavigationParams.enabled.get(params) as bool;
      expect(value, equals(true));
    });

    test('should return null for missing parameters', () {
      final params = <String, String>{};
      final value = AppNavigationParams.userId.get(params);
      expect(value, isNull);
    });

    test('should return default value', () {
      final params = <String, String>{};
      final value = AppNavigationParams.userId.getOrDefault(params, 0);
      expect(value, equals(0));
    });

    test('should throw FormatException for invalid int values', () {
      final params = {'userId': 'invalid'};
      expect(
          () => AppNavigationParams.userId.get(params), throwsFormatException);
    });

    test('should throw FormatException for invalid double values', () {
      final params = {'price': 'invalid'};
      expect(
          () => AppNavigationParams.price.get(params), throwsFormatException);
    });

    test('should return default value on parse error with getOrDefault', () {
      final params = {'userId': 'invalid'};
      final value = AppNavigationParams.userId.getOrDefault(params, 0);
      expect(value, equals(0));
    });

    test('should set parameter values correctly', () {
      final result = AppNavigationParams.userId.set(123);
      expect(result, equals({'userId': '123'}));
    });
  });

  group('NavigationZoneRouteExtension', () {
    test('should return simple name when skipZoneInRouteNames is true', () {
      DwRouter.configure(skipZoneInRouteNames: true);
      expect(TestRoutes.home.name, equals('home'));
    });

    test('should return full name when skipZoneInRouteNames is false', () {
      DwRouter.configure(skipZoneInRouteNames: false);
      expect(TestRoutes.home.name, equals('TestRoutes.home'));
    });

    test('should generate correct route path', () {
      expect(TestRoutes.home.routePath, equals('/home'));
      expect(TestRoutes.profile.routePath, equals('/profile'));
    });

    test('should generate correct full path', () {
      expect(TestRoutes.home.fullPath, equals('/home'));
      expect(TestRoutes.userDetail.fullPath, equals('/user/:userId'));
    });
  });
}

// Test route enums
// Navigation parameters enum - single generic enum for all types
enum AppNavigationParams<T> with NavigationParamsMixin<T> {
  userId<int>(), // int
  userName<String>(), // String
  price<double>(), // double
  enabled<bool>(), // bool
}

// Navigation routes enum - clean separation from parameters
enum TestRoutes implements NavigationZoneRoute {
  home(SimpleNavigationRouteDescriptor(page: TestPage('Home'))),
  profile(SimpleNavigationRouteDescriptor(page: TestPage('Profile'))),
  user(SimpleNavigationRouteDescriptor(page: TestPage('User'))),
  userDetail(ParameterizedNavigationRouteDescriptor(
    page: TestPage('User Detail'),
    parameter: AppNavigationParams.userId,
    parent: TestRoutes.user, // Make userDetail a child of user
  )),
  userName(ParameterizedNavigationRouteDescriptor(
    page: TestPage('User Name'),
    parameter: AppNavigationParams.userName,
    parent: TestRoutes.user, // Make userName a child of user
  )),
  price(ParameterizedNavigationRouteDescriptor(
    page: TestPage('Price'),
    parameter: AppNavigationParams.price,
  )),
  enabled(ParameterizedNavigationRouteDescriptor(
    page: TestPage('Enabled'),
    parameter: AppNavigationParams.enabled,
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
