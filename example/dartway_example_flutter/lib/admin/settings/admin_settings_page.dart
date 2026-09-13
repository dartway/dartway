import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

import 'package:dartway_example_flutter/core/app_l10n.dart';
import 'package:dartway_example_flutter/ui_kit/ui_kit.dart';
import 'package:dartway_example_flutter/shared/widgets/admin_scaffold.dart';
import 'widgets/admin_settings_form.dart';

/// Application settings, one row per key the app declares — write access is
/// admin-only on the server. A key added to `AppSettingKey` appears here.
class AdminSettingsPage extends StatelessWidget implements DwFeature {
  const AdminSettingsPage({super.key});

  @override
  DwFeatureSpec get dwFeature => const DwFeatureSpec(
    id: 'admin/settings',
    title: 'Club settings',
    purpose:
        'An admin changes what the app says about the club without waiting '
        'for a release.',
    behaviors: [
      'Every setting the app declares has a row, stored or not: an unstored '
          'one shows its default.',
      'A text setting offers saving only once its value has actually changed '
          'and is not blank; a toggle saves as it is flipped.',
      'A setting another admin saves changes here live.',
    ],
    requirements: [
      'Everyone signed in reads the settings; only an admin writes them, and '
          'the server is what enforces it.',
    ],
    implementationNotes: [
      'Each setting saves on its own, so two admins editing different '
          'settings cannot overwrite each other.',
    ],
  );

  @override
  Widget build(BuildContext context) {
    return AdminScaffold(
      title: context.l10n.adminSettings,
      body: ListView(
        children: [
          AppText.title(context.l10n.clubSettings),
          const Gap(8),
          const AdminSettingsForm(),
        ],
      ),
    );
  }
}
