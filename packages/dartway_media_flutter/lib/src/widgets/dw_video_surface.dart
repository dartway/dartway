import 'package:flutter/widgets.dart';
import 'package:video_player/video_player.dart';

import '../session/dw_media_session_manager.dart';

/// The video of [session]'s current item at its own aspect ratio — no
/// chrome, no controls. Follows the queue, and draws [placeholder] while
/// there is nothing to draw: loading, an audio item, a session ended.
///
/// Sized by the video's own ratio rather than the parent's box — a fixed box
/// of another ratio is how a video comes out stretched — or by
/// `DwMediaConfig.fallbackAspectRatio` while the video reports none.
final class DwVideoSurface extends StatelessWidget {
  const DwVideoSurface({super.key, required this.session, this.placeholder});

  final DwMediaSession session;
  final Widget? placeholder;

  @override
  Widget build(BuildContext context) =>
      ValueListenableBuilder<VideoPlayerController?>(
        valueListenable: session.videoView,
        builder: (context, controller, _) {
          if (controller == null) {
            return placeholder ?? const SizedBox.shrink();
          }
          return ListenableBuilder(
            listenable: controller,
            builder: (context, _) {
              final ratio = controller.value.aspectRatio;
              return AspectRatio(
                aspectRatio: ratio > 0
                    ? ratio
                    : session.options.fallbackAspectRatio,
                child: VideoPlayer(controller),
              );
            },
          );
        },
      );
}
