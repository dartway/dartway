import 'package:dartway_router/dartway_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/app_session_provider.dart';

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ElevatedButton(
              onPressed: () {
                ref.read(isLoggedInProvider.notifier).state = false;
              },
              child: Text('Logout'),
            ),
            OutlinedButton(
              onPressed: () {
                context.go('/non-existent-route');
              },
              child: Text('Go To Non-existent Route'),
            ),
          ],
        ),
      ),
    );
  }
}
