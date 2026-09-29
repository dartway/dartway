import 'package:dartway_starter_flutter/core/app_l10n.dart';
import 'package:dartway_starter_flutter/ui_kit/ui_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:gap/gap.dart';

/// A setting that is on or off. It saves as it is flipped: there is nothing
/// to type, so a Save button would only add a step. It shows the stored
/// value, so it flips when the saved setting comes back.
class AdminToggleSettingRow extends StatelessWidget {
  const AdminToggleSettingRow({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final DwUiAction<void> Function(bool value) onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Expanded(child: AppText.body(label)),
          AppCheckbox(
            value: value,
            onChanged: (isEnabled) => onChanged(isEnabled)(context),
          ),
        ],
      ),
    );
  }
}

/// A text setting. Saving is offered once the value has actually changed and
/// is not blank.
class AdminTextSettingRow extends HookWidget {
  const AdminTextSettingRow({
    super.key,
    required this.label,
    required this.value,
    required this.onSave,
  });

  final String label;
  final String value;
  final DwUiAction<void> Function(String value) onSave;

  @override
  Widget build(BuildContext context) {
    final draft = useState(value);
    final trimmed = draft.value.trim();
    final canSave = trimmed.isNotEmpty && trimmed != value;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: AppTextFormField(
              value: draft.value,
              onChanged: (edited) => draft.value = edited,
              labelText: label,
            ),
          ),
          const Gap(12),
          AppButton.primary(
            context.l10n.saveAction,
            onTap: canSave ? onSave(trimmed) : null,
          ),
        ],
      ),
    );
  }
}
