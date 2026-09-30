import 'package:dartway_core_flutter/dartway_core_flutter.dart';
import 'package:dartway_example_flutter/admin/settings/logic/settings_commands.dart';
import 'package:dartway_example_flutter/admin/settings/widgets/admin_setting_row.dart';
import 'package:dartway_example_flutter/core/app_l10n.dart';
import 'package:dartway_example_flutter/core/dw_core.dart';
import 'package:dartway_example_flutter/ui_kit/ui_kit.dart';
import 'package:dartway_example_shared/dartway_example_shared.dart';
import 'package:flutter/material.dart';

/// Every field of `ClubSettings`, one row each, showing the stored value or
/// its default. Write access is admin-only on the server.
class AdminSettingsForm extends StatelessWidget {
  const AdminSettingsForm({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    DwUiAction<DwCallResult<ClubSettings>> save(SaveClubSettings command) =>
        dw.action(
          (_) => SettingsCommands.save(command),
          onSuccessNotification: l10n.settingsSaved,
        );

    return DwReadBuilder(
      dw.request(const GetClubSettings()),
      placeholder: const ClubSettings(),
      builder: (context, stored) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // A value saved elsewhere restarts a text row's draft from it.
          AdminTextSettingRow(
            key: ValueKey(('clubName', stored.clubName)),
            label: l10n.clubNameLabel,
            value: stored.clubName,
            onSave: (name) => save(SaveClubSettings(clubName: name)),
          ),
          AdminToggleSettingRow(
            label: l10n.bookingEnabledLabel,
            value: stored.bookingEnabled,
            onChanged: (isEnabled) =>
                save(SaveClubSettings(bookingEnabled: isEnabled)),
          ),
          AdminTextSettingRow(
            key: ValueKey(('supportPhone', stored.supportPhone)),
            label: l10n.supportPhoneLabel,
            value: stored.supportPhone ?? '',
            // Emptied, the phone is cleared: the club has none.
            clearable: true,
            onSave: (phone) => save(
              SaveClubSettings(
                supportPhone: phone.isEmpty
                    ? const DwFieldPatch.clear()
                    : DwFieldPatch.set(phone),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
