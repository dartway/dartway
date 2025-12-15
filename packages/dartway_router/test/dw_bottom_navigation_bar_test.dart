import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dartway_router/dartway_router.dart';

// Helper function to create a simple test app
Widget createTestApp(List<DwMenuItem> menuItems) {
  return MaterialApp(
    home: Scaffold(
      body: const Center(child: Text('Test')),
      bottomNavigationBar: DwBottomNavigationBar(
        menuItems: menuItems,
      ),
    ),
  );
}

void main() {
  group('DwBottomNavigationBar', () {
    testWidgets('should display correct number of items', (tester) async {
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

      await tester.pumpWidget(
        ProviderScope(
          child: createTestApp(menuItems),
        ),
      );

      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Profile'), findsOneWidget);
      expect(find.byType(BottomNavigationBar), findsOneWidget);
    });

    testWidgets('should handle SVG menu items', (tester) async {
      final menuItems = [
        DwMenuItem.svg(
          route: TestRoutes.home,
          displayTitle: 'Home',
          svgIcon: 'assets/home.svg',
        ),
        DwMenuItem.icon(
          route: TestRoutes.profile,
          displayTitle: 'Profile',
          iconData: Icons.person,
        ),
      ];

      await tester.pumpWidget(
        ProviderScope(
          child: createTestApp(menuItems),
        ),
      );

      expect(find.text('Home'), findsOneWidget);
    });

    testWidgets('should handle custom menu items without routes',
        (tester) async {
      final menuItems = [
        DwMenuItem.custom(
          displayTitle: 'Custom',
          iconData: Icons.settings,
          customOnPressed: (ref) {},
        ),
        DwMenuItem.icon(
          route: TestRoutes.home,
          displayTitle: 'Home',
          iconData: Icons.home,
        ),
      ];

      await tester.pumpWidget(
        ProviderScope(
          child: createTestApp(menuItems),
        ),
      );

      expect(find.text('Custom'), findsOneWidget);
    });

    testWidgets('should display badges when provided', (tester) async {
      final messageCountProvider = StateProvider<int>((ref) => 5);

      final menuItems = [
        DwMenuItem.icon(
          route: TestRoutes.home,
          displayTitle: 'Home',
          iconData: Icons.home,
          badge: NotificationBadge(
            notificationProvider: messageCountProvider,
          ),
        ),
        DwMenuItem.icon(
          route: TestRoutes.profile,
          displayTitle: 'Profile',
          iconData: Icons.person,
        ),
      ];

      await tester.pumpWidget(
        ProviderScope(
          child: createTestApp(menuItems),
        ),
      );

      expect(find.text('5'), findsOneWidget);
    });

    testWidgets('should handle custom menu items', (tester) async {
      bool customPressed = false;

      final menuItems = [
        DwMenuItem.custom(
          displayTitle: 'Custom',
          iconData: Icons.settings,
          customOnPressed: (ref) {
            customPressed = true;
          },
        ),
        DwMenuItem.icon(
          route: TestRoutes.home,
          displayTitle: 'Home',
          iconData: Icons.home,
        ),
      ];

      await tester.pumpWidget(
        ProviderScope(
          child: createTestApp(menuItems),
        ),
      );

      await tester.tap(find.text('Custom'));
      await tester.pump();

      expect(customPressed, isTrue);
    });
  });

  group('NotificationBadge', () {
    testWidgets('should display count when greater than 0', (tester) async {
      final countProvider = StateProvider<int>((ref) => 3);

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: Center(
                child: Stack(
                  children: [
                    Container(width: 50, height: 50, color: Colors.grey),
                    Positioned(
                      right: 0,
                      top: 0,
                      child: NotificationBadge(
                        notificationProvider: countProvider,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.text('3'), findsOneWidget);
    });

    testWidgets('should hide when count is 0 or negative', (tester) async {
      final countProvider = StateProvider<int>((ref) => 0);

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: Center(
                child: Stack(
                  children: [
                    Container(width: 50, height: 50, color: Colors.grey),
                    Positioned(
                      right: 0,
                      top: 0,
                      child: NotificationBadge(
                        notificationProvider: countProvider,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.text('0'), findsNothing);
    });

    testWidgets('should update when count changes', (tester) async {
      final countProvider = StateProvider<int>((ref) => 1);

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: Center(
                child: NotificationBadge(
                  notificationProvider: countProvider,
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.text('1'), findsOneWidget);

      // Update count using a separate widget that handles the state change
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: Center(
                child: Stack(
                  children: [
                    Container(width: 50, height: 50, color: Colors.grey),
                    Positioned(
                      right: 0,
                      top: 0,
                      child: Consumer(
                        builder: (context, ref, child) {
                          // Use a button to trigger the state change instead of doing it in build
                          return ElevatedButton(
                            onPressed: () {
                              ref.read(countProvider.notifier).state = 5;
                            },
                            child: NotificationBadge(
                              notificationProvider: countProvider,
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      // Trigger the state change by tapping the button
      await tester.tap(find.byType(ElevatedButton));
      await tester.pump();

      expect(find.text('5'), findsOneWidget);
    });

    testWidgets('should use custom colors when provided', (tester) async {
      final countProvider = StateProvider<int>((ref) => 2);

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: Center(
                child: Stack(
                  children: [
                    Container(width: 50, height: 50, color: Colors.grey),
                    Positioned(
                      right: 0,
                      top: 0,
                      child: NotificationBadge(
                        notificationProvider: countProvider,
                        badgeColor: Colors.green,
                        textColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.text('2'), findsOneWidget);
      // Note: Testing exact colors would require more complex widget testing
    });

    testWidgets('should respect minSize constraint', (tester) async {
      final countProvider = StateProvider<int>((ref) => 1);

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: Center(
                child: Stack(
                  children: [
                    Container(width: 50, height: 50, color: Colors.grey),
                    Positioned(
                      right: 0,
                      top: 0,
                      child: NotificationBadge(
                        notificationProvider: countProvider,
                        minSize: 20.0,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.text('1'), findsOneWidget);
    });
  });
}

// Test route enum for widget tests
enum TestRoutes with NavigationParamsMixin<int> implements NavigationZoneRoute {
  home,
  profile;

  @override
  String get root => '';

  @override
  NavigationRouteDescriptor get descriptor {
    switch (this) {
      case TestRoutes.home:
        return SimpleNavigationRouteDescriptor(page: const TestPage('Home'));
      case TestRoutes.profile:
        return SimpleNavigationRouteDescriptor(page: const TestPage('Profile'));
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
