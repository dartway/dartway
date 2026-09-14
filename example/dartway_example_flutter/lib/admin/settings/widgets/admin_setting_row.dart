import 'package:dartway_example_flutter/admin/settings/logic/app_setting_label.dart';
import 'package:dartway_example_flutter/core/app_l10n.dart';
import 'package:dartway_example_flutter/core/app_settings/app_setting_key.dart';
import 'package:dartway_example_flutter/core/dw_core.dart';
import 'package:dartway_example_flutter/ui_kit/ui_kit.dart';
import 'package:dartway_example_shared/dartway_example_shared.dart';
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
    required this.storedValue,
  });

  final AppSettingKey<Object?> setting;

  /// The stored text, or `null` while nobody has saved this setting.
  final String? storedValue;

  /// Saves this setting alone. Two admins editing different settings
  /// therefore cannot overwrite each other.
  DwUiAction<DwCallResult<AppSetting>> _save(
    BuildContext context,
    String rawValue,
  ) => dw.action(
    (_) => dw.command(SaveAppSetting(key: setting.key, value: rawValue)),
    onSuccessNotification: context.l10n.settingsSaved,
  );

  @override
  Widget build(BuildContext context) {
    final label = setting.label(context.l10n);
    final value = setting.parse(storedValue);

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: switch (setting.type) {
        AppSettingType.toggle => _ToggleRow(
          label: label,
          value: value as bool,
          onChanged: (isEnabled) => _save(context, isEnabled.toString()),
        ),
        AppSettingType.text || AppSettingType.number => _TextRow(
          // A value saved elsewhere restarts the draft from it.
          key: ValueKey(value),
          label: label,
          value: value.toString(),
          isNumeric: setting.type == AppSettingType.number,
          onSave: (rawValue) => _save(context, rawValue),
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
  final DwUiAction<void> Function(bool value) onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: AppText.body(label)),
        // A toggle saves on change: there is nothing to type, so a Save button
        // would only add a step. It shows the stored value, so it flips when
        // the saved setting comes back.
        AppCheckbox(
          value: value,
          onChanged: (isEnabled) => onChanged(isEnabled)(context),
        ),
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
    super.key,
  });

  final String label;
  final String value;
  final bool isNumeric;
  final DwUiAction<void> Function(String rawValue) onSave;

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
          onTap: canSave ? onSave(trimmed) : null,
        ),
      ],
    );
  }
}
