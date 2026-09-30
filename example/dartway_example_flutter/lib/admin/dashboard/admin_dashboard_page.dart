import 'package:dartway_example_flutter/admin/analytics/analytics_dashboards_section.dart';
import 'package:dartway_example_flutter/admin/dashboard/widgets/admin_counters.dart';
import 'package:dartway_example_flutter/core/app_l10n.dart';
import 'package:dartway_example_flutter/core/router/admin_scaffold.dart';
import 'package:dartway_example_flutter/ui_kit/ui_kit.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

/// Admin home: headline counters the server counts and keeps live, and under
/// them the analytics dashboards the club builds from the app's events.
class AdminDashboardPage extends StatelessWidget implements DwFeatureWidget {
  const AdminDashboardPage({super.key});

  @override
  DwFeatureSpec get dwFeature => const DwFeatureSpec(
    id: 'dashboard/admin-dashboard',
    title: 'Admin dashboard',
    purpose:
        'The landing screen of the panel: how big the club is right now, and '
        'what members do in the app.',
    behaviors: [
      'Members, upcoming sessions and news posts, counted by the server.',
      'A member signing up, a session scheduled or a post published anywhere '
          'changes the numbers live.',
      'A line under the counters explains that they are live.',
      'Under them, the analytics dashboards (admin/analytics).',
    ],
    implementationNotes: [
      'The counters are one small view, not three lists counted on the '
          'client: an admin screen must not download every profile to show '
          'how many there are.',
    ],
  );

  @override
  Widget build(BuildContext context) {
    return AdminScaffold(
      title: context.l10n.adminDashboard,
      body: ListView(
        children: [
          const AdminCounters(),
          const Gap(AppSpace.s16),
          AppText.body(context.l10n.countersLiveHint),
          const Gap(AppSpace.s32),
          const AnalyticsDashboardsSection(),
        ],
      ),
    );
  }
}
