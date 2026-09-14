import 'package:dartway_example_flutter/admin/settings/widgets/admin_setting_row.dart';
import 'package:dartway_example_flutter/core/app_settings/app_setting_key.dart';
import 'package:dartway_example_flutter/core/dw_core.dart';
import 'package:dartway_example_flutter/shared/widgets/load_failed_message.dart';
import 'package:dartway_example_shared/dartway_example_shared.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// Every setting the app declares, one row each.
///
/// The screen is a loop over the catalogue rather than a hand-written field per
/// setting: adding an entry to `AppSettingKey` makes it appear here, and there
/// is no second place to forget. Write access is admin-only on the server.
class AdminSettingsForm extends ConsumerWidget {
  const AdminSettingsForm({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref
        .watch(dw.request(const ListAppSettings()))
        .section(
          loadingValue: const <AppSetting>[],
          onRetry: () =>
              ref.read(dw.request(const ListAppSettings()).notifier).refetch(),
          builder: (stored) {
            final storedValues = {for (final s in stored) s.id: s.value};
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final setting in AppSettingKey.values)
                  AdminSettingRow(
                    setting: setting,
                    storedValue: storedValues[setting.key],
                  ),
              ],
            );
          },
        );
  }
}
