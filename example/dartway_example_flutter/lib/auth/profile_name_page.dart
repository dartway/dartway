import 'package:dartway_example_flutter/core/app_l10n.dart';
import 'package:dartway_example_flutter/core/dw_core.dart';
import 'package:dartway_example_flutter/shared/widgets/app_scaffold.dart';
import 'package:dartway_example_flutter/ui_kit/ui_kit.dart';
import 'package:dartway_example_shared/dartway_example_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:gap/gap.dart';

/// Asks a signed-in user without a name for one.
///
/// The server learns whether an account is new only when the code is verified,
/// and signing in with a phone that had no account creates one — named with
/// whatever the registration step collected, which on the login step is
/// nothing. So the question is not asked by the sign-in flow but by
/// `SignedInGate`, of every profile that lacks a name: it covers the login
/// step, an app closed half-way, and any other road to an unnamed account.
class ProfileNamePage extends HookWidget implements DwFeature {
  const ProfileNamePage({super.key});

  @override
  DwFeatureSpec get dwFeature => const DwFeatureSpec(
    id: 'auth/profile-name',
    title: 'Name for a new account',
    purpose: 'Nobody reaches the club app nameless: the team sees the name.',
    behaviors: [
      'Shown instead of the app while the signed-in profile has no name.',
      'Saving the name lets the member into the app as soon as the profile '
          'update arrives.',
    ],
  );

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final name = useState('');

    return AppScaffold.inner(
      appBar: AppBar(
        centerTitle: true,
        title: AppText.title(l10n.whatIsYourName),
      ),
      body: Form(
        child: Column(
          children: [
            AppText.body(l10n.whatIsYourNameHint, textAlign: TextAlign.center),
            const Gap(24),
            AppTextFormField(
              labelText: l10n.nameLabel,
              value: name.value,
              onChanged: (value) => name.value = value,
              validator: (value) =>
                  (value ?? '').trim().isEmpty ? l10n.requiredField : null,
            ),
            const Spacer(),
            AppButton.primary(
              l10n.continueAction,
              requireValidation: true,
              // The gate lets the app through when the updated profile
              // arrives on the profile channel; nothing to do on success.
              onTap: dw.action(
                (_) =>
                    dw.command(UpdateMyProfile(firstName: name.value.trim())),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
