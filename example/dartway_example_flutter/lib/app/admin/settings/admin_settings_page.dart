import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

import '../../../core/app_l10n.dart';
import '../../../ui_kit/ui_kit.dart';
import '../common/admin_scaffold.dart';
import 'widgets/admin_settings_form.dart';

/// Application settings backed by the AppSetting model — write access is
/// admin-only on the server. New settings appear here as the model grows.
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
      'The club name is editable here and nothing else yet.',
      'Saving is offered only once the value has actually changed and is not '
          'blank.',
      'With no settings row in the database the screen says so instead of '
          'showing an empty form.',
    ],
    requirements: [
      'Everyone signed in reads the settings; only an admin writes them, and '
          'the server is what enforces it.',
    ],
    implementationNotes: [
      'The form names its setting keys by hand. A settings screen driven by '
          'the AppSetting rows themselves is the obvious next step and is '
          'deliberately not taken here — one field keeps the example readable.',
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
