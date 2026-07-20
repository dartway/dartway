import 'package:dartway_example_flutter/core/dw_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:gap/gap.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:dartway_example_client/dartway_example_client.dart';
import 'package:dartway_example_flutter/core/app_l10n.dart';
import 'package:dartway_example_flutter/ui_kit/ui_kit.dart';

/// Club settings form over AppSetting (clubName). Reads the setting and saves
/// edits — write access is admin-only on the server.
class AdminSettingsForm extends ConsumerWidget {
  const AdminSettingsForm({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref
        .watch(dw.repo.modelList<AppSetting>())
        .dwBuildListAsync(
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
              return AppText.body(context.l10n.noSettingsConfigured);
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

    final l10n = context.l10n;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: AppTextFormField(
            value: value.value,
            onChanged: (v) => value.value = v,
            labelText: l10n.clubNameLabel,
          ),
        ),
        const Gap(12),
        AppButton.primary(
          l10n.saveAction,
          onTap: canSave
              ? dw.action(
                  (context) => dw.repo.saveModel(
                    setting.copyWith(settingValue: value.value.trim()),
                  ),
                  onSuccessNotification: l10n.settingsSaved,
                )
              : null,
        ),
      ],
    );
  }
}
