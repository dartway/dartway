import 'package:dartway_example_flutter/app/workouts/logic/workout_catalog.dart';
import 'package:dartway_example_flutter/core/app_l10n.dart';
import 'package:dartway_example_flutter/core/dw_core.dart';
import 'package:dartway_example_flutter/core/router/app_scaffold.dart';
import 'package:dartway_example_flutter/ui_kit/ui_kit.dart';
import 'package:dartway_media_flutter/dartway_media_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

/// The club's recorded workouts, played in one queue.
///
/// The session belongs to `dw.plugins.media`, not to this page: leaving the
/// page minimizes it into the mini-player (mounted in `AppRoot`), coming
/// back restores it here.
class WorkoutsPage extends HookWidget implements DwFeatureWidget {
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
  Widget build(BuildContext context) {
    final media = dw.plugins.media.sessionManager;
    // Coming back restores the session here; leaving minimizes it into the
    // mini-player.
    useEffect(() {
      media.active.value?.restore();
      return () => media.active.value?.minimize();
    }, const []);
    final session = useValueListenable(media.active);

    void play(int index) {
      if (media.active.value case final active?) {
        active.jumpTo(index);
      } else {
        dw.plugins.media.open(
          items: workoutCatalog,
          startIndex: index,
          options: const DwMediaOpenOptions(autoplayOnOpen: true),
        );
      }
    }

    return AppScaffold.main(
      appBar: AppBar(title: AppText.title(context.l10n.workoutsTitle)),
      body: Column(
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
                      onTap: () => play(index),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
