import 'package:dartway_starter_flutter/admin/settings/widgets/admin_settings_form.dart';
import 'package:dartway_starter_flutter/core/app_l10n.dart';
import 'package:dartway_starter_flutter/core/router/admin_scaffold.dart';
import 'package:dartway_starter_flutter/ui_kit/ui_kit.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

/// The app's settings, one row per field of `AppSettings` — write access is
/// admin-only on the server.
class AdminSettingsPage extends StatelessWidget implements DwFeatureWidget {
  const AdminSettingsPage({super.key});

  @override
  DwFeatureSpec get dwFeature => const DwFeatureSpec(
    id: 'settings/app-settings',
    title: 'App settings',
    purpose:
        'An admin changes how the app behaves and what it says about itself '
        'without waiting for a release.',
    behaviors: [
      'Every setting the app has is a row, saved or not: an unsaved one shows '
          'its default.',
      'A text setting offers saving only once its value has actually changed '
          'and is not blank; a toggle saves as it is flipped.',
      'A setting another admin saves changes here live.',
      'Switching sign-up off makes the server refuse new accounts; existing '
          'ones still sign in.',
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
          AppText.title(context.l10n.appSettingsTitle),
          const Gap(AppSpace.s8),
          const AdminSettingsForm(),
        ],
      ),
    );
  }
}
