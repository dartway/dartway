import 'package:dartway_serverpod_core_flutter/dartway_serverpod_core_flutter.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:project_name_flutter/app/profile/profile_page/widgets/profile_settings_widget.dart';
import 'package:project_name_flutter/common/app_scaffold.dart';
import 'package:project_name_flutter/ui_kit/ui_kit.dart';

import '../water_intake/water_intake_widget.dart';

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppScaffold.main(
      appBar: AppBar(
        title: AppText.title('Profile'),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const ProfileSettingsWidget(),
            const Gap(24),
            const WaterIntakeWidget(),
            const Gap(24),
            DwButton.text(
              'Sign out',
              dwCallback: DwUiAction.create(
                () => ref.signOut(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
