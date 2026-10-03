part of '../../ui_kit.dart';

/// What `DwMiniPlayerHost` shows: the picture, play/pause and close. Where it
/// sits, how it is dragged, resized and snapped, and what expand and close do
/// are the package's; this is only the look — a scrim under each control so
/// it reads over a light frame, and the resize handle's mark in the corner
/// `DwMiniPlayerHost.resizeCornerOf` names, with the buttons kept off it.
///
/// It sits above the app's navigator, where there is no overlay for a
/// tooltip: the buttons are labelled for accessibility with `Semantics`
/// instead.
///
/// Copied into a project's own `ui_kit/` and restyled — see the
/// `dartway-media` toolkit skill.
class AppMiniPlayerChrome extends StatelessWidget {
  const AppMiniPlayerChrome({
    super.key,
    required this.session,
    required this.onExpand,
    required this.onClose,
  });

  final DwMediaSession session;
  final VoidCallback onExpand;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final handle = DwMiniPlayerHost.resizeCornerOf(context);
    // Close at the top, play/pause at the bottom — each on the side the
    // handle leaves free.
    final close = handle == Alignment.topRight
        ? Alignment.topLeft
        : Alignment.topRight;
    final play = handle == Alignment.bottomLeft
        ? Alignment.bottomRight
        : Alignment.bottomLeft;
    return GestureDetector(
      onTap: onExpand,
      child: Material(
        color: Colors.black,
        elevation: 6,
        borderRadius: BorderRadius.circular(8),
        clipBehavior: Clip.antiAlias,
        child: IconTheme(
          data: const IconThemeData(color: Colors.white),
          child: Stack(
            fit: StackFit.expand,
            children: [
              ValueListenableBuilder<DwMediaQueueState>(
                valueListenable: session.queue,
                builder: (context, queue, _) => Center(
                  child: queue.current.kind == DwMediaKind.video
                      ? DwVideoSurface(session: session)
                      : const Icon(Icons.graphic_eq),
                ),
              ),
              // The scrims: a white icon on a light frame is not there.
              const Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black45,
                          Colors.transparent,
                          Colors.transparent,
                          Colors.black54,
                        ],
                        stops: [0, 0.35, 0.6, 1],
                      ),
                    ),
                  ),
                ),
              ),
              Align(
                alignment: play,
                child: ValueListenableBuilder<DwMediaPlaybackState>(
                  valueListenable: session.playback,
                  builder: (context, playback, _) => Semantics(
                    label: playback.isPlaying
                        ? context.l10n.mediaPause
                        : context.l10n.mediaPlay,
                    child: IconButton(
                      iconSize: 22,
                      icon: Icon(
                        playback.isPlaying ? Icons.pause : Icons.play_arrow,
                      ),
                      onPressed: playback.isPlaying
                          ? session.pause
                          : session.play,
                    ),
                  ),
                ),
              ),
              Align(
                alignment: close,
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Semantics(
                    label: context.l10n.mediaClose,
                    child: Material(
                      color: Colors.black54,
                      shape: const CircleBorder(),
                      child: IconButton(
                        iconSize: 18,
                        constraints: const BoxConstraints(
                          minWidth: 32,
                          minHeight: 32,
                        ),
                        padding: EdgeInsets.zero,
                        icon: const Icon(Icons.close),
                        onPressed: onClose,
                      ),
                    ),
                  ),
                ),
              ),
              if (handle != null)
                Align(
                  alignment: handle,
                  child: IgnorePointer(
                    child: SizedBox.square(
                      dimension: session.options.miniPlayerResizeHandleExtent,
                      // The icon's arrows run bottom-left to top-right;
                      // turned a quarter for the other diagonal.
                      child: RotatedBox(
                        quarterTurns: handle.x == handle.y ? 1 : 0,
                        child: const Icon(
                          Icons.open_in_full,
                          size: 14,
                          color: Colors.white70,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
