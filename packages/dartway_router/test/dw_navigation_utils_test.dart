import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dartway_router/dartway_router.dart';

void main() {
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

    test('should handle parameterized routes', () {
      final menuItems = [
        DwMenuItem.icon(
          route: TestRoutes.userDetail,
          displayTitle: 'User Detail',
          iconData: Icons.person,
        ),
      ];

      final index = DwNavigationUtils.findMatchingRouteIndex(
        '/user/123',
        menuItems,
      );

      expect(index, equals(0));
    });

    test('should handle routes with query parameters', () {
      final menuItems = [
        DwMenuItem.icon(
          route: TestRoutes.home,
          displayTitle: 'Home',
          iconData: Icons.home,
        ),
      ];

      final index = DwNavigationUtils.findMatchingRouteIndex(
        '/home?param=value',
        menuItems,
      );

      expect(index, equals(0));
    });

    test('should handle empty menu items list', () {
      final index = DwNavigationUtils.findMatchingRouteIndex(
        '/home',
        [],
      );

      expect(index, equals(-1));
    });

    test('should handle menu items with null routes', () {
      final menuItems = [
        DwMenuItem.custom(
          displayTitle: 'Custom',
          iconData: Icons.settings,
          customOnPressed: (ref) {},
        ),
      ];

      final index = DwNavigationUtils.findMatchingRouteIndex(
        '/home',
        menuItems,
      );

      expect(index, equals(-1));
    });
  });

  group('DwNavigationContext Extension', () {
    testWidgets('should provide navigation methods', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              // Test that the extension methods are available
              expect(context.goTo, isA<Function>());
              expect(context.pushTo, isA<Function>());
              expect(context.replaceWith, isA<Function>());
              expect(context.isCurrent, isA<Function>());

              return const Text('Test');
            },
          ),
        ),
      );
    });
  });
}

// Test route enum for navigation utils tests
// Navigation parameters enum - single generic enum for all types
enum AppNavigationParams<T> with NavigationParamsMixin<T> {
  userId<int>(), // int
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
  ));

  const TestRoutes(this.descriptor);

  @override
  final NavigationRouteDescriptor descriptor;

  @override
  String get root => '';
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
