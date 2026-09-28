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

/// The picture with everything over it. A tap shows the controls; while the
/// item plays they hide again after `session.options.controlsAutoHideDelay`.
class _AppMediaStage extends StatefulWidget {
  const _AppMediaStage({required this.session});

  final DwMediaSession session;

  @override
  State<_AppMediaStage> createState() => _AppMediaStageState();
}

class _AppMediaStageState extends State<_AppMediaStage> {
  bool _controlsVisible = true;
  bool _wasPlaying = false;
  Timer? _hideTimer;

  DwMediaSession get _session => widget.session;

  @override
  void initState() {
    super.initState();
    _session.playback.addListener(_onPlayback);
    _onPlayback();
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _session.playback.removeListener(_onPlayback);
    super.dispose();
  }

  void _onPlayback() {
    final playing = _session.playback.value.isPlaying;
    if (playing == _wasPlaying) return;
    _wasPlaying = playing;
    playing ? _scheduleHide() : _show();
  }

  void _show() {
    _hideTimer?.cancel();
    if (!_controlsVisible) setState(() => _controlsVisible = true);
  }

  void _scheduleHide() {
    _hideTimer?.cancel();
    _hideTimer = Timer(_session.options.controlsAutoHideDelay, () {
      if (mounted && _session.playback.value.isPlaying) {
        setState(() => _controlsVisible = false);
      }
    });
  }

  void _onTap() {
    if (_controlsVisible) {
      _hideTimer?.cancel();
      setState(() => _controlsVisible = false);
    } else {
      setState(() => _controlsVisible = true);
      if (_session.playback.value.isPlaying) _scheduleHide();
    }
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTap: _onTap,
    child: ColoredBox(
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Center(
            child: _session.currentItem.kind == DwMediaKind.video
                ? DwVideoSurface(
                    session: _session,
                    placeholder: const CircularProgressIndicator(),
                  )
                : const Icon(Icons.graphic_eq, size: 64, color: Colors.white),
          ),
          if (_controlsVisible)
            ColoredBox(
              color: Colors.black38,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  AppMediaTimeline(session: _session),
                  AppMediaControlBar(session: _session),
                ],
              ),
            ),
          Positioned(
            right: 12,
            top: 12,
            child: AppMediaNextItemCard(session: _session),
          ),
          AppMediaErrorView(session: _session),
        ],
      ),
    ),
  );
}
