import 'package:dartway_core_flutter/dartway_core_flutter.dart';
import 'package:dartway_starter_flutter/admin/settings/logic/settings_commands.dart';
import 'package:dartway_starter_flutter/admin/settings/widgets/admin_setting_row.dart';
import 'package:dartway_starter_flutter/core/app_l10n.dart';
import 'package:dartway_starter_flutter/core/dw_core.dart';
import 'package:dartway_starter_flutter/ui_kit/ui_kit.dart';
import 'package:dartway_starter_shared/dartway_starter_shared.dart';
import 'package:flutter/material.dart';

/// Every field of `AppSettings`, one row each, showing the stored value or its
/// default. A setting added to the contract gets its row here.
///
/// Write access is admin-only on the server.
class AdminSettingsForm extends StatelessWidget {
  const AdminSettingsForm({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    DwUiAction<DwCallResult<AppSettings>> save(SaveAppSettings command) =>
        dw.action(
          (_) => SettingsCommands.save(command),
          onSuccessNotification: l10n.settingsSaved,
        );

    return DwReadBuilder(
      dw.request(const GetAppSettings()),
      placeholder: const AppSettings(),
      builder: (context, stored) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AdminTextSettingRow(
            // A value saved elsewhere restarts the draft from it.
            key: ValueKey(stored.appName),
            label: l10n.appNameLabel,
            value: stored.appName,
            onSave: (name) => save(SaveAppSettings(appName: name)),
          ),
          AdminToggleSettingRow(
            label: l10n.signUpEnabledLabel,
            value: stored.signUpEnabled,
            onChanged: (isEnabled) =>
                save(SaveAppSettings(signUpEnabled: isEnabled)),
          ),
        ],
      ),
    );
  }
}
