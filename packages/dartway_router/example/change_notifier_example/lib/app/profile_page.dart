import 'package:dartway_router/dartway_router.dart';
import 'package:flutter/material.dart';

import '../core/app_session_notifier.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ElevatedButton(
              onPressed: () {
                AppSession.instance.logout();
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
