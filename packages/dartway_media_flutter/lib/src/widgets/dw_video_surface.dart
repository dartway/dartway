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
          return _SizedVideoView(
            key: ObjectKey(controller),
            controller: controller,
            fallbackAspectRatio: session.options.fallbackAspectRatio,
          );
        },
      );
}

/// Selects size only. The texture widget stays mounted during position ticks.
final class _SizedVideoView extends StatefulWidget {
  const _SizedVideoView({
    super.key,
    required this.controller,
    required this.fallbackAspectRatio,
  });
  final VideoPlayerController controller;
  final double fallbackAspectRatio;

  @override
  State<_SizedVideoView> createState() => _SizedVideoViewState();
}

final class _SizedVideoViewState extends State<_SizedVideoView> {
  late Size _size;
  late Widget _video;

  @override
  void initState() {
    super.initState();
    _size = widget.controller.value.size;
    _video = VideoPlayer(widget.controller);
    widget.controller.addListener(_onValue);
  }

  void _onValue() {
    final size = widget.controller.value.size;
    if (_size == size) return;
    setState(() => _size = size);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onValue);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AspectRatio(
    aspectRatio: _size.isEmpty
        ? widget.fallbackAspectRatio
        : _size.width / _size.height,
    child: _video,
  );
}
