import 'package:dartway_media_flutter/dartway_media_flutter.dart';

/// The club's recorded workouts. A real club serves them from its own
/// storage — through `DwMediaSource.resolve`, so an expired signed link is
/// asked for again on retry; these public samples stand in for it.
const workoutCatalog = [
  DwMediaItem(
    id: 'workout-mobility',
    kind: DwMediaKind.video,
    title: 'Morning mobility',
    source: DwMediaSource.url(
      'https://flutter.github.io/assets-for-api-docs/assets/videos/butterfly.mp4',
    ),
  ),
  DwMediaItem(
    id: 'workout-core',
    kind: DwMediaKind.video,
    title: 'Core basics',
    source: DwMediaSource.url(
      'https://flutter.github.io/assets-for-api-docs/assets/videos/bee.mp4',
    ),
  ),
  DwMediaItem(
    id: 'workout-wake-up',
    kind: DwMediaKind.audio,
    title: 'Wake-up call',
    source: DwMediaSource.url(
      'https://flutter.github.io/assets-for-api-docs/assets/audio/rooster.mp3',
    ),
  ),
];
