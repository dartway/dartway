import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:dartway_example_flutter/core/app_core.dart';

class TestNotificationButton extends ConsumerWidget {
  const TestNotificationButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return IconButton(
      onPressed: () async {
        AppCore.serverpodClient.development.testNotification(
          notificationText: 'Test notification',
        );
      },
      icon: const Icon(Icons.send_and_archive),
    );
  }
}
