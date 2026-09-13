import 'package:dartway_example_flutter/core/app_l10n.dart';
import 'package:dartway_example_flutter/core/dw_core.dart';
import 'package:dartway_example_flutter/core/profile/my_profile.dart';
import 'package:dartway_example_flutter/ui_kit/ui_kit.dart';
import 'package:dartway_example_shared/dartway_example_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:gap/gap.dart';

/// The signed-in user's own profile: photo, name and gender.
class ProfileSettingsWidget extends StatelessWidget {
  const ProfileSettingsWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final profile = context.profile;
    // Keyed by the fields it edits: when they change — this user's own save
    // coming back on the profile channel, or an edit on another device — the
    // form starts again from the profile as it now is, rather than keeping a
    // draft of a value that no longer exists.
    return _ProfileForm(
      key: ValueKey((profile.firstName, profile.gender)),
      profile: profile,
    );
  }
}

class _ProfileForm extends HookWidget {
  const _ProfileForm({required this.profile, super.key});

  final ProfileView profile;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final firstName = useState(profile.firstName);
    final gender = useState(profile.gender);

    final trimmedName = firstName.value.trim();
    final nameChanged = trimmedName != profile.firstName;
    final genderChanged = gender.value != profile.gender;
    final imageUrl = profile.imageUrl;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Form(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: CircleAvatar(
                radius: 48,
                foregroundImage: imageUrl == null
                    ? null
                    : NetworkImage(imageUrl),
                child: const Icon(Icons.person_outline, size: 32),
              ),
            ),

            const Gap(24),

            AppTextFormField(
              value: firstName.value,
              onChanged: (value) => firstName.value = value,
              labelText: l10n.firstNameLabel,
              hintText: l10n.firstNameHint,
              validator: (value) =>
                  (value ?? '').trim().isEmpty ? l10n.firstNameRequired : null,
            ),

            const Gap(16),

            AppText.body(l10n.genderLabel),
            const Gap(8),
            DropdownButtonFormField<UserGender>(
              initialValue: gender.value,
              onChanged: (value) => gender.value = value,
              decoration: const InputDecoration(border: OutlineInputBorder()),
              items: [
                DropdownMenuItem<UserGender>(
                  value: null,
                  child: Text(l10n.genderNotSpecified),
                ),
                for (final value in UserGender.values)
                  DropdownMenuItem<UserGender>(
                    value: value,
                    child: Text(l10n.genderValue(value.name)),
                  ),
              ],
            ),

            const Gap(24),

            if (nameChanged || genderChanged) ...[
              AppButton.primary(
                l10n.saveChanges,
                requireValidation: true,
                // Only what changed is sent: an unchanged field is kept, and
                // "not specified" clears the gender rather than being
                // indistinguishable from leaving it alone.
                onTap: dw.action(
                  (_) => dw.command(
                    UpdateMyProfile(
                      firstName: nameChanged ? trimmedName : null,
                      gender: switch (gender.value) {
                        _ when !genderChanged => const DwPatch.keep(),
                        final UserGender value => DwPatch.set(value),
                        null => const DwPatch.clear(),
                      },
                    ),
                  ),
                  onSuccessNotification: l10n.profileUpdated,
                ),
              ),
              const Gap(16),
            ],
          ],
        ),
      ),
    );
  }
}
