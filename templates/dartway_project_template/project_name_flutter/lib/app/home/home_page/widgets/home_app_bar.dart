import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:project_name_flutter/core/dev/test_notification_button.dart';
import 'package:project_name_flutter/core/user_profile_provider.dart';
import 'package:project_name_flutter/ui_kit/ui_kit.dart';

class HomeAppBar extends ConsumerWidget implements PreferredSizeWidget {
  const HomeAppBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppBar(
      title: AppText.title('Hello, ${ref.watchUserProfile.firstName}'),
      actions: const [TestNotificationButton()],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
