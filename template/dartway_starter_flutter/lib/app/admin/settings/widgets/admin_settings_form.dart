import 'package:dartway_serverpod_core_flutter/dartway_serverpod_core_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:gap/gap.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:dartway_starter_client/dartway_starter_client.dart';
import 'package:dartway_starter_flutter/core/app_l10n.dart';
import 'package:dartway_starter_flutter/ui_kit/ui_kit.dart';

/// Settings form over AppSetting (appName). Reads the setting and saves
/// edits — write access is admin-only on the server.
class AdminSettingsForm extends ConsumerWidget {
  const AdminSettingsForm({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watchModelList<AppSetting>().dwBuildListAsync(
          loadingItemsCount: 1,
          childBuilder: (settings) {
            AppSetting? appName;
            for (final setting in settings) {
              if (setting.settingKey == 'appName') {
                appName = setting;
                break;
              }
            }
            if (appName == null) {
              return AppText.body(context.l10n.noSettingsConfigured);
            }
            return _AppNameField(setting: appName);
          },
        );
  }
}

class _AppNameField extends HookWidget {
  const _AppNameField({required this.setting});

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
            labelText: l10n.appNameLabel,
          ),
        ),
        const Gap(12),
        AppButton.primary(
          l10n.saveAction,
          onTap: canSave
              ? DwUiAction.create(
                  (context) => DwRepository.saveModel(
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
