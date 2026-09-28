import 'package:flutter/widgets.dart';
import 'package:video_player/video_player.dart';

import '../session/dw_media_session.dart';

/// The video texture for [session]'s current item, at the video's own aspect
/// ratio — mechanism only, no chrome, no controls. Rebuilds when the queue
/// advances to a new controller and when that controller's own value changes
/// (in particular the moment it finishes initializing, when the real aspect
/// ratio becomes known).
///
/// Sized by [AspectRatio] rather than left to the parent's constraints —
/// stretching a `VideoPlayer` inside a box of the wrong ratio is the
/// "stretched video" bug seen on Android when a fixed-size container is
/// assumed instead of read from the controller.
final class DwVideoSurface extends StatelessWidget {
  const DwVideoSurface({super.key, required this.session, this.placeholder});

  final DwMediaSession session;

  /// Shown before the video has an initialized controller to render — no
  /// current item, an audio item, or still loading.
  final Widget? placeholder;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: session.queue,
    builder: (context, _) {
      final controller = session.videoController;
      if (controller == null) return placeholder ?? const SizedBox.shrink();
      return ListenableBuilder(
        listenable: controller,
        builder: (context, _) {
          if (!controller.value.isInitialized) {
            return placeholder ?? const SizedBox.shrink();
          }
          return AspectRatio(
            aspectRatio: controller.value.aspectRatio,
            child: VideoPlayer(controller),
          );
        },
      );
    },
  );
}
