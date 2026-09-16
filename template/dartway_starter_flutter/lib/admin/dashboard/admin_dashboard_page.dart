import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

import 'package:dartway_starter_flutter/core/app_l10n.dart';
import 'package:dartway_starter_flutter/ui_kit/ui_kit.dart';
import 'package:dartway_starter_flutter/shared/widgets/admin_scaffold.dart';
import 'widgets/admin_counter_tiles.dart';

/// Admin home: headline counters the server counts and keeps live. Event
/// analytics (visits, conversion, retention) arrives with the analytics
/// milestone — this screen is its future home.
class AdminDashboardPage extends StatelessWidget implements DwFeatureWidget {
  const AdminDashboardPage({super.key});

  @override
  DwFeatureSpec get dwFeature => const DwFeatureSpec(
    id: 'admin/dashboard',
    title: 'Admin dashboard',
    purpose: 'The landing screen of the panel: how big the app is right now.',
    behaviors: [
      'Members, admins and news subscribers, counted by the server.',
      'A member signing up or a role changed anywhere changes the numbers '
          'live.',
      'A line under the counters explains that they are live.',
    ],
    implementationNotes: [
      'The counters are one small view, not three lists counted on the '
          'client: an admin screen must not download every profile to show '
          'how many there are.',
      'Event analytics — visits, conversion, retention — belongs here and is '
          'deliberately absent: it needs an analytics milestone.',
    ],
  );

  @override
  Widget build(BuildContext context) {
    return AdminScaffold(
      title: context.l10n.adminDashboard,
      body: ListView(
        children: [
          const AdminCounterTiles(),
          const Gap(16),
          AppText.body(context.l10n.countersLiveHint),
        ],
      ),
    );
  }
}
