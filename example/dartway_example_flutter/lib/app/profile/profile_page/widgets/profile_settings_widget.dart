import 'package:dartway_example_flutter/app/profile/profile_page/logic/profile_page_commands.dart';
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
    // coming back in its answer, or an edit on another device — the
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

  final UserProfile profile;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final firstName = useState(profile.firstName);
    final gender = useState(profile.gender);

    final change = ProfilePageCommands.changeOf(
      profile,
      firstName: firstName.value,
      gender: gender.value,
    );
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

            if (change != null) ...[
              AppButton.primary(
                l10n.saveChanges,
                requireValidation: true,
                onTap: dw.action(
                  (_) => ProfilePageCommands.save(change),
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
