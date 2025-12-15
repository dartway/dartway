import 'package:dartway_router/dartway_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../router/app_router.dart';

// Example providers for notifications
final messageCountProvider = StateProvider<int>((ref) => 3);
final notificationCountProvider = StateProvider<int>((ref) => 0);

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Home')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Welcome to DartWay Router!'),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => context.goTo(AppNavigationZone.profile),
              child: const Text('Go to Profile'),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: () => context.pushTo(
                AppNavigationZone.userDetail,
                pathParameters: AppParams.userId.set(123),
              ),
              child: const Text('View User Detail'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                // Toggle message count for demo
                final current = ref.read(messageCountProvider);
                ref.read(messageCountProvider.notifier).state =
                    current > 0 ? 0 : 5;
              },
              child: const Text('Toggle Message Count'),
            ),
          ],
        ),
      ),
      bottomNavigationBar: DwBottomNavigationBar(
        menuItems: [
          DwMenuItem.icon(
            route: AppNavigationZone.home,
            displayTitle: 'Home',
            iconData: Icons.home,
            activeIconData: Icons.home_filled,
          ),
          DwMenuItem.icon(
            route: AppNavigationZone.profile,
            displayTitle: 'Profile',
            iconData: Icons.person_outline,
            activeIconData: Icons.person,
          ),
          DwMenuItem.icon(
            route: AppNavigationZone.settings,
            displayTitle: 'Messages',
            iconData: Icons.message_outlined,
            // Using NotificationBadge directly with the badge parameter
            badge: NotificationBadge(
              notificationProvider: messageCountProvider,
              badgeColor: Colors.red,
              textColor: Colors.white,
            ),
          ),
          DwMenuItem.icon(
            route: AppNavigationZone.settings,
            displayTitle: 'Settings',
            iconData: Icons.settings_outlined,
            activeIconData: Icons.settings,
            // Custom badge widget
            badge: Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: Colors.green,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
