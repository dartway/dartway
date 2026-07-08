import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:dartway_example_flutter/app/admin/widgets/admin_counters.dart';
import 'package:dartway_example_flutter/app/admin/widgets/admin_settings_form.dart';
import 'package:dartway_example_flutter/app/admin/widgets/admin_users_table.dart';
import 'package:dartway_example_flutter/common/app_scaffold.dart';
import 'package:dartway_example_flutter/ui_kit/ui_kit.dart';

/// Admin panel — club-admin only (the router guard redirects everyone else).
/// The first brick of a generic auto-admin: a users table over DwCrudConfig,
/// club settings and headline counters.
class AdminPage extends StatelessWidget {
  const AdminPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScaffold.inner(
      appBar: AppBar(title: AppText.title('Admin')),
      body: ListView(
        children: [
          const AdminCounters(),
          const Gap(24),
          AppText.title('Members'),
          const Gap(4),
          const AdminUsersTable(),
          const Gap(24),
          AppText.title('Club settings'),
          const Gap(8),
          const AdminSettingsForm(),
        ],
      ),
    );
  }
}
