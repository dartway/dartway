import 'package:dartway_starter_client/dartway_starter_client.dart';
import 'package:dartway_starter_flutter/app/admin/settings/logic/app_setting_label.dart';
import 'package:dartway_starter_flutter/core/app_l10n.dart';
import 'package:dartway_starter_flutter/core/app_settings/app_setting_key.dart';
import 'package:dartway_starter_flutter/core/app_settings/app_settings_reader.dart';
import 'package:dartway_starter_flutter/core/dw_core.dart';
import 'package:dartway_starter_flutter/ui_kit/ui_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:gap/gap.dart';

/// One setting, edited by whatever its [AppSettingType] calls for.
///
/// The switch is exhaustive: adding a type to the enum without a widget here
/// stops compiling.
class AdminSettingRow extends StatelessWidget {
  const AdminSettingRow({
    super.key,
    required this.setting,
    required this.storedSettings,
  });

  final AppSettingKey<Object?> setting;
  final List<AppSetting> storedSettings;

  /// Saves one row — its own. Two admins editing different settings therefore
  /// cannot overwrite each other, which is the whole reason a setting is a row
  /// and not an entry in one shared map.
  Future<void> _save(String rawValue) => dw.repo.saveModel(
    storedSettings.rowFor(setting)?.copyWith(settingValue: rawValue) ??
        AppSetting(settingKey: setting.key, settingValue: rawValue),
  );

  @override
  Widget build(BuildContext context) {
    final label = setting.label(context.l10n);
    final value = storedSettings.valueOf(setting);

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: switch (setting.type) {
        AppSettingType.toggle => _ToggleRow(
          label: label,
          value: value as bool,
          onChanged: (isEnabled) => _save(isEnabled.toString()),
        ),
        AppSettingType.text || AppSettingType.number => _TextRow(
          label: label,
          value: value.toString(),
          isNumeric: setting.type == AppSettingType.number,
          onSave: _save,
        ),
      },
    );
  }
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: AppText.body(label)),
        // A toggle saves on change: there is nothing to type, so a Save button
        // would only add a step.
        AppCheckbox(value: value, onChanged: onChanged),
      ],
    );
  }
}

class _TextRow extends HookWidget {
  const _TextRow({
    required this.label,
    required this.value,
    required this.isNumeric,
    required this.onSave,
  });

  final String label;
  final String value;
  final bool isNumeric;
  final Future<void> Function(String rawValue) onSave;

  @override
  Widget build(BuildContext context) {
    final draft = useState(value);
    final trimmed = draft.value.trim();
    final canSave = trimmed.isNotEmpty && trimmed != value;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: AppTextFormField(
            value: draft.value,
            onChanged: (edited) => draft.value = edited,
            labelText: label,
            keyboardType: isNumeric ? TextInputType.number : null,
          ),
        ),
        const Gap(12),
        AppButton.primary(
          context.l10n.saveAction,
          onTap: canSave
              ? dw.action(
                  (context) => onSave(trimmed),
                  onSuccessNotification: context.l10n.settingsSaved,
                )
              : null,
        ),
      ],
    );
  }
}
