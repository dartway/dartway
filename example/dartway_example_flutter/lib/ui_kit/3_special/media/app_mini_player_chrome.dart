part of '../../ui_kit.dart';

/// What `DwMiniPlayerHost` shows: the picture, play/pause and close. Where it
/// sits, how it is dragged, pinched and snapped, and what expand and close do
/// are the package's; this is only the look.
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
  Widget build(BuildContext context) => GestureDetector(
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
            Center(
              child: session.currentItem.kind == DwMediaKind.video
                  ? DwVideoSurface(session: session)
                  : const Icon(Icons.graphic_eq),
            ),
            Align(
              alignment: Alignment.bottomLeft,
              child: ValueListenableBuilder<DwMediaPlaybackState>(
                valueListenable: session.playback,
                builder: (context, playback, _) => Semantics(
                  label: playback.isPlaying
                      ? context.l10n.mediaPause
                      : context.l10n.mediaPlay,
                  child: IconButton(
                    iconSize: 20,
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
              alignment: Alignment.topRight,
              child: Semantics(
                label: context.l10n.mediaClose,
                child: IconButton(
                  iconSize: 16,
                  icon: const Icon(Icons.close),
                  onPressed: onClose,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
