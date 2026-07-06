import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:dartway_example_flutter/core/dev/test_notification_button.dart';
import 'package:dartway_example_flutter/core/user_profile_provider.dart';
import 'package:dartway_example_flutter/ui_kit/ui_kit.dart';

class ScheduleAppBar extends ConsumerWidget implements PreferredSizeWidget {
  const ScheduleAppBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppBar(
      title: AppText.title('Hello, ${ref.watchUserProfile.firstName}'),
      actions: const [
        ConnectionStatusIndicator(),
        TestNotificationButton(),
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
