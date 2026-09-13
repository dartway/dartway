import 'package:dartway_example_flutter/app/profile/profile_page/widgets/profile_settings_widget.dart';
import 'package:dartway_example_flutter/core/app_l10n.dart';
import 'package:dartway_example_flutter/core/dw_core.dart';
import 'package:dartway_example_flutter/core/profile/my_profile.dart';
import 'package:dartway_example_flutter/core/profile/profile_roles.dart';
import 'package:dartway_example_flutter/core/router/router.dart';
import 'package:dartway_example_flutter/shared/widgets/app_scaffold.dart';
import 'package:dartway_example_flutter/ui_kit/ui_kit.dart';
import 'package:dartway_router/dartway_router.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

class ProfilePage extends StatelessWidget implements DwFeature {
  const ProfilePage({super.key});

  @override
  DwFeatureSpec get dwFeature => const DwFeatureSpec(
    id: 'profile/my-profile',
    title: 'My profile',
    purpose:
        'A member manages their own account and finds the way out of the app.',
    behaviors: [
      'The way into the admin panel is shown to club admins only.',
      'Signing out returns to the auth flow.',
    ],
    requirements: [
      'The admin button is convenience, not access: the route guard and the '
          'server\'s access rules decide who actually gets in.',
    ],
  );

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return AppScaffold.main(
      appBar: AppBar(title: AppText.title(l10n.profileTitle)),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const ProfileSettingsWidget(),
            const Gap(24),
            if (context.profile.isClubAdmin) ...[
              AppButton.secondary(
                l10n.adminPanel,
                onTap: dw.action(
                  (context) => GoRouter.of(
                    context,
                  ).goNamed(AdminNavigationZone.admin.name),
                ),
              ),
              const Gap(24),
            ],
            AppButton.secondary(
              l10n.ourServices,
              onTap: dw.action(
                (context) => GoRouter.of(
                  context,
                ).goNamed(AppNavigationZone.services.name),
              ),
            ),
            const Gap(24),
            AppButton.text(
              l10n.signOutAction,
              // The router takes it from here: signed out, the guards send
              // every zone but auth to the sign-in screen.
              onTap: dw.action((_) => dw.signOut()),
            ),
          ],
        ),
      ),
    );
  }
}
