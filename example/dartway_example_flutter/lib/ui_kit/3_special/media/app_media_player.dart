part of '../../ui_kit.dart';

/// The player a page shows inline: the picture (or, for audio, a sign of
/// it), controls that hide themselves while it plays, the next-item card and
/// the error state — and fullscreen, pushed by the package's
/// `DwMediaFullscreenHost` whenever the session asks for it.
///
/// Everything the player *does* is `dartway_media_flutter`'s; everything it
/// looks like is here. Copied into a project's own `ui_kit/` and restyled —
/// see the `dartway-media` toolkit skill.
class AppMediaPlayer extends StatelessWidget {
  const AppMediaPlayer({super.key, required this.session});

  final DwMediaSession session;

  @override
  Widget build(BuildContext context) => DwMediaFullscreenHost(
    session: session,
    builder: (_) => AppMediaFullscreenPage(session: session),
    child: AspectRatio(
      aspectRatio: 16 / 9,
      child: _AppMediaStage(session: session),
    ),
  );
}

/// What stands in the package's fullscreen route.
class AppMediaFullscreenPage extends StatelessWidget {
  const AppMediaFullscreenPage({super.key, required this.session});

  final DwMediaSession session;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    body: SafeArea(child: _AppMediaStage(session: session)),
  );
}

/// The picture with everything over it. A tap toggles the controls; when
/// they hide is the session's (`session.controlsVisible`, after
/// `DwMediaConfig.controlsAutoHideDelay` of playback).
class _AppMediaStage extends StatelessWidget {
  const _AppMediaStage({required this.session});

  final DwMediaSession session;

  @override
  Widget build(BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTap: session.toggleControls,
    child: ColoredBox(
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ValueListenableBuilder<DwMediaQueueState>(
            valueListenable: session.queue,
            builder: (context, queue, _) => Center(
              child: queue.current.kind == DwMediaKind.video
                  ? DwVideoSurface(
                      session: session,
                      placeholder: const CircularProgressIndicator(),
                    )
                  : const Icon(Icons.graphic_eq, size: 64, color: Colors.white),
            ),
          ),
          ValueListenableBuilder<bool>(
            valueListenable: session.controlsVisible,
            builder: (context, visible, _) => visible
                ? ColoredBox(
                    color: Colors.black38,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        AppMediaTimeline(session: session),
                        AppMediaControlBar(session: session),
                      ],
                    ),
                  )
                : const SizedBox.shrink(),
          ),
          Positioned(
            right: 12,
            top: 12,
            child: AppMediaNextItemCard(session: session),
          ),
          AppMediaErrorView(session: session),
        ],
      ),
    ),
  );
}
