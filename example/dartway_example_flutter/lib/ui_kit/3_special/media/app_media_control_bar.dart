part of '../../ui_kit.dart';

/// Play/pause, skip, speed, mute and fullscreen for a `DwMediaSession` — one
/// row. Mechanism (`session.play`/`pause`/`skipBack`/`skipForward`/`setSpeed`/
/// `setMuted`, `showDwMediaFullscreen`) comes from `dartway_media_flutter`;
/// the row, the icons and the speed menu are the project's own.
///
/// Copied from the framework's example into a project's own `ui_kit/` and
/// restyled — see the `dartway-media` toolkit skill. The speed button hides
/// itself when `session.options.speeds` is empty, and the fullscreen button
/// when `session.options.fullscreen` is off — a project that turns a
/// capability off in `DwMediaConfig` need not also edit this widget.
class AppMediaControlBar extends StatelessWidget {
  const AppMediaControlBar({super.key, required this.session});

  final DwMediaSession session;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: session.controller.state,
      builder: (context, _) {
        final state = session.controller.state.value;
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              icon: const Icon(Icons.replay_10),
              onPressed: () => session.skipBack(),
            ),
            IconButton(
              iconSize: 40,
              icon: Icon(state.isPlaying ? Icons.pause_circle : Icons.play_circle),
              onPressed: () =>
                  state.isPlaying ? session.pause() : session.play(),
            ),
            IconButton(
              icon: const Icon(Icons.forward_10),
              onPressed: () => session.skipForward(),
            ),
            IconButton(
              icon: Icon(state.muted ? Icons.volume_off : Icons.volume_up),
              onPressed: () => session.setMuted(!state.muted),
            ),
            if (session.options.speeds.isNotEmpty)
              PopupMenuButton<double>(
                initialValue: state.speed,
                onSelected: session.setSpeed,
                itemBuilder: (context) => [
                  for (final speed in session.options.speeds)
                    PopupMenuItem(value: speed, child: Text('${speed}x')),
                ],
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: AppText.caption('${state.speed}x'),
                ),
              ),
            if (session.options.fullscreen && session.currentItem.kind == DwMediaKind.video)
              IconButton(
                icon: const Icon(Icons.fullscreen),
                onPressed: () => showDwMediaFullscreen(
                  context,
                  session: session,
                  builder: (context) => AppMediaFullscreenPage(session: session),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// What plays inside the package's own fullscreen route — the video surface
/// plus the same control bar, on black.
class AppMediaFullscreenPage extends StatelessWidget {
  const AppMediaFullscreenPage({super.key, required this.session});

  final DwMediaSession session;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(child: Center(child: DwVideoSurface(session: session))),
            AppMediaControlBar(session: session),
            IconButton(
              icon: const Icon(Icons.fullscreen_exit, color: Colors.white),
              onPressed: session.exitFullscreen,
            ),
          ],
        ),
      ),
    );
  }
}
