import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

import '../../../core/app_l10n.dart';
import '../../../ui_kit/ui_kit.dart';
import '../common/admin_scaffold.dart';
import 'widgets/admin_counters.dart';

/// Admin home: headline counters over live model lists. Event analytics
/// (visits, conversion, retention) arrives with the analytics milestone —
/// this screen is its future home.
class AdminDashboardPage extends StatelessWidget {
  const AdminDashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AdminScaffold(
      title: context.l10n.adminDashboard,
      body: ListView(
        children: [
          const AdminCounters(),
          const Gap(16),
          AppText.body(context.l10n.countersLiveHint),
        ],
      ),
    );
  }
}
