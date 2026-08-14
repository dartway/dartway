import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

import 'package:dartway_starter_flutter/core/app_l10n.dart';
import 'package:dartway_starter_flutter/ui_kit/ui_kit.dart';
import 'package:dartway_starter_flutter/shared/widgets/admin_scaffold.dart';
import 'widgets/admin_counters.dart';

/// Admin home: headline counters over live model lists. Event analytics
/// (visits, conversion, retention) arrives with the analytics milestone —
/// this screen is its future home.
class AdminDashboardPage extends StatelessWidget implements DwFeature {
  const AdminDashboardPage({super.key});

  @override
  DwFeatureSpec get dwFeature => const DwFeatureSpec(
    id: 'admin/dashboard',
    title: 'Admin dashboard',
    purpose:
        'The landing screen of the panel: how big the system is right now.',
    behaviors: ['A line under the counters explains that they are live.'],
    implementationNotes: [
      'Analytics belongs here when there is any — this screen is the frame, '
          'and the counters are their own feature (admin/live-counters).',
    ],
  );

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
