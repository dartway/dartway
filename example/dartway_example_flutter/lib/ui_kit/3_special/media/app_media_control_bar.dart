part of '../../ui_kit.dart';

/// Skip back, play/pause, skip forward, mute, speed and fullscreen — one
/// row over the picture. Each control asks the session; none decides
/// anything itself.
///
/// A capability switched off in `DwMediaConfig` disappears here on its own:
/// no speed menu while `speeds` is empty, no fullscreen button while
/// `fullscreen` is off or the item is audio.
///
/// Copied into a project's own `ui_kit/` and restyled — see the
/// `dartway-media` toolkit skill.
class AppMediaControlBar extends StatelessWidget {
  const AppMediaControlBar({super.key, required this.session});

  final DwMediaSession session;

  @override
  Widget build(BuildContext context) {
    final options = session.options;
    return IconTheme(
      data: const IconThemeData(color: Colors.white),
      child: ListenableBuilder(
        listenable: Listenable.merge([session.playback, session.isFullscreen]),
        builder: (context, _) {
          final playback = session.playback.value;
          final fullscreen = session.isFullscreen.value;
          return Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                tooltip: context.l10n.mediaSkipBack,
                icon: const Icon(Icons.replay),
                onPressed: session.skipBack,
              ),
              IconButton(
                tooltip: playback.isPlaying
                    ? context.l10n.mediaPause
                    : context.l10n.mediaPlay,
                iconSize: 40,
                icon: Icon(
                  playback.isPlaying ? Icons.pause_circle : Icons.play_circle,
                ),
                onPressed: playback.isPlaying ? session.pause : session.play,
              ),
              IconButton(
                tooltip: context.l10n.mediaSkipForward,
                icon: const Icon(Icons.forward_10),
                onPressed: session.skipForward,
              ),
              IconButton(
                tooltip: context.l10n.mediaMute,
                icon: Icon(playback.muted ? Icons.volume_off : Icons.volume_up),
                onPressed: () => session.setMuted(!playback.muted),
              ),
              if (options.speeds.isNotEmpty)
                PopupMenuButton<double>(
                  tooltip: context.l10n.mediaSpeed,
                  initialValue: playback.speed,
                  onSelected: session.setSpeed,
                  itemBuilder: (context) => [
                    for (final speed in options.speeds)
                      PopupMenuItem(value: speed, child: Text('$speed×')),
                  ],
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      '${playback.speed}×',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              if (options.fullscreen &&
                  session.currentItem.kind == DwMediaKind.video)
                IconButton(
                  tooltip: context.l10n.mediaFullscreen,
                  icon: Icon(
                    fullscreen ? Icons.fullscreen_exit : Icons.fullscreen,
                  ),
                  onPressed: fullscreen
                      ? session.exitFullscreen
                      : session.enterFullscreen,
                ),
            ],
          );
        },
      ),
    );
  }
}
