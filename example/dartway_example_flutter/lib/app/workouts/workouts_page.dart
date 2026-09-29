import 'package:dartway_example_flutter/app/workouts/logic/workout_catalog.dart';
import 'package:dartway_example_flutter/core/app_l10n.dart';
import 'package:dartway_example_flutter/core/dw_core.dart';
import 'package:dartway_example_flutter/core/router/app_scaffold.dart';
import 'package:dartway_example_flutter/ui_kit/ui_kit.dart';
import 'package:dartway_media_flutter/dartway_media_flutter.dart';
import 'package:flutter/material.dart';

/// The club's recorded workouts, played in one queue.
///
/// The session belongs to `dw.plugins.media`, not to this page: leaving the
/// page minimizes it into the mini-player (mounted in `AppRoot`), coming
/// back restores it here.
class WorkoutsPage extends StatefulWidget implements DwFeatureWidget {
  const WorkoutsPage({super.key});

  @override
  DwFeatureSpec get dwFeature => const DwFeatureSpec(
    id: 'workouts/player',
    title: 'Workouts',
    purpose: 'Members follow the club\'s recorded workouts.',
    behaviors: [
      'Tapping a workout plays it at the top of the page; the others follow '
          'in the same queue.',
      'Near the end the next workout is announced, and it starts after a '
          'countdown the member can cancel.',
      'Leaving the page keeps the workout playing in a mini-player; tapping '
          'the mini-player comes back here.',
    ],
  );

  @override
  State<WorkoutsPage> createState() => _WorkoutsPageState();
}

class _WorkoutsPageState extends State<WorkoutsPage> {
  DwMediaSessionManager get _media => dw.plugins.media.sessionManager;

  @override
  void initState() {
    super.initState();
    _media.active.value?.restore();
  }

  @override
  void dispose() {
    _media.active.value?.minimize();
    super.dispose();
  }

  void _play(int index) {
    final session = _media.active.value;
    if (session == null) {
      dw.plugins.media.open(
        items: workoutCatalog,
        startIndex: index,
        options: const DwMediaOpenOptions(autoplayOnOpen: true),
      );
    } else {
      session.jumpTo(index);
    }
  }

  @override
  Widget build(BuildContext context) => AppScaffold.main(
    appBar: AppBar(title: AppText.title(context.l10n.workoutsTitle)),
    body: ValueListenableBuilder<DwMediaSession?>(
      valueListenable: _media.active,
      builder: (context, session, _) => Column(
        children: [
          if (session != null) AppMediaPlayer(session: session),
          Expanded(
            child: ListenableBuilder(
              listenable: Listenable.merge([session?.queue]),
              builder: (context, _) => ListView(
                children: [
                  for (final (index, workout) in workoutCatalog.indexed)
                    ListTile(
                      leading: Icon(
                        workout.kind == DwMediaKind.video
                            ? Icons.ondemand_video
                            : Icons.headphones,
                      ),
                      title: AppText.body(workout.title ?? ''),
                      subtitle: AppText.caption(
                        workout.kind == DwMediaKind.video
                            ? context.l10n.workoutVideo
                            : context.l10n.workoutAudio,
                      ),
                      selected: session?.currentItem == workout,
                      onTap: () => _play(index),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
