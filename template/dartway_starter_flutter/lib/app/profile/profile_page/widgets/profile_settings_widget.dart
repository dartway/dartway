import 'package:dartway_starter_flutter/core/app_l10n.dart';
import 'package:dartway_starter_flutter/core/dw_core.dart';
import 'package:dartway_starter_flutter/core/profile/my_profile.dart';
import 'package:dartway_starter_flutter/ui_kit/ui_kit.dart';
import 'package:dartway_starter_shared/dartway_starter_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:gap/gap.dart';

/// The signed-in member's own name and gender.
class ProfileSettingsWidget extends StatelessWidget {
  const ProfileSettingsWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final profile = context.profile;
    // Keyed by the fields it edits: when they change — this member's own save
    // coming back in its answer, or an edit on another device — the form
    // starts again from the profile as it now is, rather than keeping a draft
    // of a value that no longer exists.
    return _ProfileForm(
      key: ValueKey((profile.firstName, profile.lastName, profile.gender)),
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
    final lastName = useState(profile.lastName ?? '');
    final gender = useState(profile.gender);

    final trimmedFirst = firstName.value.trim();
    final trimmedLast = lastName.value.trim();
    final firstChanged = trimmedFirst != profile.firstName;
    final lastChanged = trimmedLast != (profile.lastName ?? '');
    final genderChanged = gender.value != profile.gender;

    return Form(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppTextFormField(
            value: firstName.value,
            onChanged: (value) => firstName.value = value,
            labelText: l10n.firstNameLabel,
            hintText: l10n.firstNameHint,
            validator: (value) =>
                (value ?? '').trim().isEmpty ? l10n.firstNameRequired : null,
          ),
          const Gap(12),
          AppTextFormField(
            value: lastName.value,
            onChanged: (value) => lastName.value = value,
            labelText: l10n.lastNameLabel,
          ),
          const Gap(12),
          DropdownButtonFormField<UserGender>(
            initialValue: gender.value,
            onChanged: (value) => gender.value = value,
            decoration: InputDecoration(labelText: l10n.genderLabel),
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
          if (firstChanged || lastChanged || genderChanged) ...[
            const Gap(16),
            AppButton.primary(
              l10n.saveChanges,
              requireValidation: true,
              // Only what changed is sent: an unchanged field is kept, and a
              // cleared one is cleared rather than being indistinguishable
              // from leaving it alone.
              onTap: dw.action(
                (_) => dw.command(
                  UpdateMyProfile(
                    firstName: firstChanged ? trimmedFirst : null,
                    lastName: switch (trimmedLast) {
                      _ when !lastChanged => const DwFieldPatch.keep(),
                      '' => const DwFieldPatch.clear(),
                      final value => DwFieldPatch.set(value),
                    },
                    gender: switch (gender.value) {
                      _ when !genderChanged => const DwFieldPatch.keep(),
                      final UserGender value => DwFieldPatch.set(value),
                      null => const DwFieldPatch.clear(),
                    },
                  ),
                ),
                onSuccessNotification: l10n.profileUpdated,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
