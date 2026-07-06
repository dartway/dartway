import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:dartway_example_flutter/app/schedule/widgets/schedule_app_bar.dart';
import 'package:dartway_example_flutter/app/schedule/widgets/schedule_session_list.dart';
import 'package:dartway_example_flutter/common/app_scaffold.dart';

class SchedulePage extends ConsumerWidget {
  const SchedulePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const AppScaffold.main(
      appBar: ScheduleAppBar(),
      body: ScheduleSessionList(),
    );
  }
}
