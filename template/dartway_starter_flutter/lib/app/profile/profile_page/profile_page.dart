import 'package:dartway_starter_flutter/app/profile/identity/profile_identity_section.dart';
import 'package:dartway_starter_flutter/core/app_l10n.dart';
import 'package:dartway_starter_flutter/core/dw_core.dart';
import 'package:dartway_starter_flutter/core/profile/my_profile.dart';
import 'package:dartway_starter_flutter/core/router/router.dart';
import 'package:dartway_starter_flutter/shared/widgets/app_scaffold.dart';
import 'package:dartway_starter_flutter/ui_kit/ui_kit.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

import 'widgets/avatar_picker.dart';
import 'widgets/profile_settings_widget.dart';

class ProfilePage extends StatelessWidget implements DwFeature {
  const ProfilePage({super.key});

  @override
  DwFeatureSpec get dwFeature => const DwFeatureSpec(
    id: 'profile/my-profile',
    title: 'My profile',
    purpose:
        'A member manages their own account — photo, name, how they sign in '
        '— and finds the way out of the app.',
    behaviors: [
      'Tapping the photo picks an image, which uploads straight to storage '
          'and becomes the profile photo; it can be removed again.',
      'Name and gender are saved only when changed.',
      'The phone and the e-mail the member signs in with are added or changed '
          'by a code sent to the new one (see profile/identity).',
      'The way into the admin panel is shown to admins only.',
      'Signing out returns to the sign-in screen.',
    ],
    requirements: [
      'The admin button is convenience, not access: the route guard and the '
          "server's access rules decide who actually gets in.",
    ],
  );

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final profile = context.profile;

    return AppScaffold.main(
      appBar: AppBar(title: AppText.title(l10n.profileTitle)),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AvatarPicker(avatarUrl: profile.avatarUrl),
            const Gap(16),
            const ProfileSettingsWidget(),
            const Gap(8),
            const ProfileIdentitySection(),
            const Gap(24),
            if (profile.isAdmin) ...[
              AppButton.secondary(
                l10n.adminPanel,
                onTap: dw.action(
                  (context) => GoRouter.of(
                    context,
                  ).goNamed(AdminNavigationZone.admin.name),
                ),
              ),
              const Gap(16),
            ],
            AppButton.text(
              l10n.signOutAction,
              // The router takes it from here: signed out, the guards send
              // every zone but auth to the sign-in screen.
              onTap: dw.action((_) => dw.signOut()),
            ),
            const Gap(24),
          ],
        ),
      ),
    );
  }
}
