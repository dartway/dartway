import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

import '../../../core/app_l10n.dart';
import '../../../ui_kit/ui_kit.dart';
import '../common/admin_scaffold.dart';
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
    purpose: 'The landing screen of the panel: how big the club is right now.',
    behaviors: ['A line under the counters explains that they are live.'],
    implementationNotes: [
      'The counters themselves are admin/live-counters. This screen is their '
          'frame, and the future home of event analytics — visits, conversion, '
          'retention — which needs an analytics milestone, not another watch.',
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
