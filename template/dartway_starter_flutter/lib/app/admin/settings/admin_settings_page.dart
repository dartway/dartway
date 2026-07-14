import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

import '../../../core/app_l10n.dart';
import '../../../ui_kit/ui_kit.dart';
import '../common/admin_scaffold.dart';
import 'widgets/admin_settings_form.dart';

/// Application settings backed by the AppSetting model — write access is
/// admin-only on the server. New settings appear here as the model grows.
class AdminSettingsPage extends StatelessWidget {
  const AdminSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AdminScaffold(
      title: context.l10n.adminSettings,
      body: ListView(
        children: [
          AppText.title(context.l10n.appSettings),
          const Gap(8),
          const AdminSettingsForm(),
        ],
      ),
    );
  }
}
