import 'package:dartway_example_flutter/core/app_l10n.dart';
import 'package:dartway_example_flutter/core/dev/test_error_button.dart';
import 'package:dartway_example_flutter/core/profile/my_profile.dart';
import 'package:dartway_example_flutter/ui_kit/ui_kit.dart';
import 'package:flutter/material.dart';

class ScheduleAppBar extends StatelessWidget implements PreferredSizeWidget {
  const ScheduleAppBar({super.key});

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: AppText.title(context.l10n.helloUser(context.profile.firstName)),
      actions: const [ConnectionStatusIndicator(), TestErrorButton()],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
