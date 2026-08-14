import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:dartway_example_flutter/app/schedule/widgets/schedule_app_bar.dart';
import 'package:dartway_example_flutter/app/schedule/widgets/schedule_session_list.dart';
import 'package:dartway_example_flutter/shared/widgets/app_scaffold.dart';
import 'package:dartway_example_flutter/ui_kit/ui_kit.dart';

class SchedulePage extends ConsumerWidget implements DwFeature {
  const SchedulePage({super.key});

  @override
  DwFeatureSpec get dwFeature => const DwFeatureSpec(
    id: 'schedule/page',
    title: 'Schedule screen',
    implementationNotes: [
      'This screen carries no feature of its own — schedule/session-list '
          'does, and that is the passport worth reading.',
    ],
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const AppScaffold.main(
      appBar: ScheduleAppBar(),
      body: ScheduleSessionList(),
    );
  }
}
