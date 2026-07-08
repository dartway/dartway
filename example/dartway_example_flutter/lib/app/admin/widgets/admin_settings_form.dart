import 'package:dartway_serverpod_core_flutter/dartway_serverpod_core_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:gap/gap.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:dartway_example_client/dartway_example_client.dart';
import 'package:dartway_example_flutter/ui_kit/ui_kit.dart';

/// Club settings form over AppSetting (clubName). Reads the setting and saves
/// edits — write access is admin-only on the server.
class AdminSettingsForm extends ConsumerWidget {
  const AdminSettingsForm({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watchModelList<AppSetting>().dwBuildListAsync(
          loadingItemsCount: 1,
          childBuilder: (settings) {
            AppSetting? clubName;
            for (final setting in settings) {
              if (setting.settingKey == 'clubName') {
                clubName = setting;
                break;
              }
            }
            if (clubName == null) {
              return AppText.body('No settings configured.');
            }
            return _ClubNameField(setting: clubName);
          },
        );
  }
}

class _ClubNameField extends HookWidget {
  const _ClubNameField({required this.setting});

  final AppSetting setting;

  @override
  Widget build(BuildContext context) {
    final value = useState(setting.settingValue);
    final canSave =
        value.value.trim().isNotEmpty && value.value != setting.settingValue;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: AppTextFormField(
            value: value.value,
            onChanged: (v) => value.value = v,
            labelText: 'Club name',
          ),
        ),
        const Gap(12),
        DwButton.primary(
          'Save',
          dwCallback: canSave
              ? DwUiAction.create(
                  (context) => DwRepository.saveModel(
                    setting.copyWith(settingValue: value.value.trim()),
                  ),
                  onSuccessNotification: 'Settings saved',
                )
              : null,
        ),
      ],
    );
  }
}
