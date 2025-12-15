import 'package:dartway_serverpod_core_flutter/dartway_serverpod_core_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:gap/gap.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:project_name_client/project_name_client.dart';
import 'package:project_name_flutter/core/user_profile_provider.dart';
import 'package:project_name_flutter/ui_kit/ui_kit.dart';

class ProfileSettingsWidget extends HookConsumerWidget {
  const ProfileSettingsWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch the current user profile using DartWay data layer
    final userProfile = ref.watchUserProfile;

    // Initialize form fields with default values
    final firstNameController =
        useTextEditingController(text: userProfile.firstName);
    final selectedGender = useState<UserGender?>(userProfile.gender);

    // Track if any changes have been made
    final hasChanges = useState<bool>(false);

    // Update hasChanges whenever form values change
    useEffect(() {
      void checkForChanges() {
        final currentFirstName = firstNameController.text;
        final currentGender = selectedGender.value;

        final firstNameChanged = currentFirstName != userProfile.firstName;
        final genderChanged = currentGender != userProfile.gender;

        hasChanges.value = firstNameChanged || genderChanged;
      }

      firstNameController.addListener(checkForChanges);
      selectedGender.addListener(checkForChanges);

      return () {
        firstNameController.removeListener(checkForChanges);
        selectedGender.removeListener(checkForChanges);
      };
    }, []);

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // First Name Field
          AppTextFormField(
            value: firstNameController.text,
            onChanged: (value) => firstNameController.text = value,
            labelText: 'First Name',
            hintText: 'Enter your first name',
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'First name is required';
              }
              return null;
            },
          ),

          const Gap(16),

          // Gender Selector
          const DwText('Gender', textStyle: AppText.body),
          const Gap(8),
          DropdownButtonFormField<UserGender>(
            value: selectedGender.value,
            onChanged: (UserGender? newValue) {
              selectedGender.value = newValue;
            },
            decoration: const InputDecoration(
              hintText: 'Select your gender',
              border: OutlineInputBorder(),
            ),
            items: [
              const DropdownMenuItem<UserGender>(
                value: null,
                child: Text('Not specified'),
              ),
              ...UserGender.values
                  .map<DropdownMenuItem<UserGender>>((UserGender gender) {
                return DropdownMenuItem<UserGender>(
                  value: gender,
                  child: Text(gender.name.toUpperCase()),
                );
              }),
            ],
          ),

          const Gap(24),

          // Save Button (only shows when there are changes)
          if (hasChanges.value) ...[
            DwButton.primary(
              'Save Changes',
              dwCallback: DwUiAction.create(
                () async {
                  await ref.saveModel(
                    userProfile.copyWith(
                      firstName: firstNameController.text.trim(),
                      gender: selectedGender.value,
                    ),
                  );
                  hasChanges.value = false;
                },
                onSuccessNotification: 'Profile updated successfully!',
              ),
            ),
            const Gap(16),
          ],
        ],
      ),
    );
  }
}
