import 'package:dartway_router/dartway_router.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:dartway_example_flutter/app/profile/profile_page/widgets/profile_settings_widget.dart';
import 'package:dartway_example_flutter/common/app_scaffold.dart';
import 'package:dartway_example_flutter/core/app_l10n.dart';
import 'package:dartway_example_flutter/core/dw_core.dart';
import 'package:dartway_example_flutter/core/router/router.dart';
import 'package:dartway_example_flutter/core/user_profile_provider.dart';
import 'package:dartway_example_flutter/core/user_profile_roles.dart';
import 'package:dartway_example_flutter/ui_kit/ui_kit.dart';

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;

    return AppScaffold.main(
      appBar: AppBar(
        title: AppText.title(l10n.profileTitle),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const ProfileSettingsWidget(),
            const Gap(24),
            if (ref.watchUserProfile.isClubAdmin) ...[
              AppButton.secondary(
                l10n.adminPanel,
                onTap: dw.action(
                  (context) => GoRouter.of(context)
                      .goNamed(AdminNavigationZone.admin.name),
                ),
              ),
              const Gap(24),
            ],
            AppButton.secondary(
              l10n.ourServices,
              onTap: dw.action(
                (context) => GoRouter.of(context)
                    .goNamed(AppNavigationZone.services.name),
              ),
            ),
            const Gap(24),
            AppButton.text(
              l10n.signOutAction,
              onTap: dw.action(
                (context) => ref.read(dw.sessionProvider!.notifier).signOut(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
