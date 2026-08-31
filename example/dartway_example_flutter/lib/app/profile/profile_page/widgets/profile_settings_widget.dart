import 'package:dartway_serverpod_core_flutter/dartway_serverpod_core_flutter.dart';
import 'package:dartway_example_flutter/core/dw_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:gap/gap.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:dartway_example_client/dartway_example_client.dart';
import 'package:dartway_example_flutter/core/app_l10n.dart';
import 'package:dartway_example_flutter/core/user_profile_provider.dart';
import 'package:dartway_example_flutter/ui_kit/ui_kit.dart';

class ProfileSettingsWidget extends HookConsumerWidget {
  const ProfileSettingsWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch the current user profile using DartWay data layer
    final userProfile = ref.watchUserProfile;

    // Initialize form fields with default values
    final firstNameController = useTextEditingController(
      text: userProfile.firstName,
    );
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

    final l10n = context.l10n;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Photo: pick, upload, store the URL on the profile.
          //
          // `DwFileUploadHandler.pickAndUploadImageUrl` is the whole upload — it
          // opens the picker, sends the bytes to the storage configured on the
          // server (see cloudStorageConfig) and returns the public URL. What is
          // left is an ordinary save, so the photo travels the same CRUD path as
          // any other field.
          Center(
            child: DwActionBuilder(
              action: dw.action((_) async {
                // `path` is the folder in the bucket; the object's own name
                // is the framework's business and is random by design.
                final imageUrl =
                    await DwFileUploadHandler.pickAndUploadImageUrl(
                      path: 'avatars',
                    );
                // Null means the picker was dismissed — not a failure.
                if (imageUrl == null) return;
                await dw.repo.saveModel(
                  userProfile.copyWith(imageUrl: imageUrl),
                );
              }, onSuccessNotification: l10n.profilePhotoUpdated),
              builder: (context, onPressed, busy) => InkResponse(
                onTap: onPressed,
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 48,
                      foregroundImage: userProfile.imageUrl == null
                          ? null
                          : NetworkImage(userProfile.imageUrl!),
                      child: busy
                          ? const CircularProgressIndicator()
                          : const Icon(Icons.photo_camera_outlined, size: 32),
                    ),
                    const Gap(8),
                    AppText.caption(l10n.profilePhotoHint),
                  ],
                ),
              ),
            ),
          ),

          const Gap(24),

          // First Name Field
          AppTextFormField(
            value: firstNameController.text,
            onChanged: (value) => firstNameController.text = value,
            labelText: l10n.firstNameLabel,
            hintText: l10n.firstNameHint,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return l10n.firstNameRequired;
              }
              return null;
            },
          ),

          const Gap(16),

          // Gender Selector
          AppText.body(l10n.genderLabel),
          const Gap(8),
          DropdownButtonFormField<UserGender>(
            initialValue: selectedGender.value,
            onChanged: (UserGender? newValue) {
              selectedGender.value = newValue;
            },
            decoration: const InputDecoration(border: OutlineInputBorder()),
            items: [
              DropdownMenuItem<UserGender>(
                value: null,
                child: Text(l10n.genderNotSpecified),
              ),
              ...UserGender.values.map<DropdownMenuItem<UserGender>>((
                UserGender gender,
              ) {
                return DropdownMenuItem<UserGender>(
                  value: gender,
                  child: Text(l10n.genderValue(gender.name)),
                );
              }),
            ],
          ),

          const Gap(24),

          // Save Button (only shows when there are changes)
          if (hasChanges.value) ...[
            AppButton.primary(
              l10n.saveChanges,
              onTap: dw.action((context) async {
                await dw.repo.saveModel(
                  userProfile.copyWith(
                    firstName: firstNameController.text.trim(),
                    gender: selectedGender.value,
                  ),
                );
                hasChanges.value = false;
              }, onSuccessNotification: l10n.profileUpdated),
            ),
            const Gap(16),
          ],
        ],
      ),
    );
  }
}
