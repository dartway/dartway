part of '../session/dw_media_session_manager.dart';

/// Wraps the inline player of a page and puts [session] fullscreen whenever
/// it asks to be: pushes the package's fullscreen route onto the root
/// navigator when `session.isFullscreen` turns true — `enterFullscreen()`,
/// `autoEnterFullscreenOnPlay`, already true when the page builds — and the
/// route leaves when it turns false. One way in, whoever asks.
///
/// A session goes fullscreen only while a host for it is mounted: from the
/// mini-player, with the page gone, `enterFullscreen()` does nothing.
///
/// [builder] draws the fullscreen page (the project's surface and controls);
/// [child] is what the page shows inline. The route's transition is
/// `DwMediaConfig.fullscreenTransitionDuration` and
/// `fullscreenTransitionBuilder`.
final class DwMediaFullscreenHost extends StatefulWidget {
  const DwMediaFullscreenHost({
    super.key,
    required this.session,
    required this.builder,
    required this.child,
  });

  final DwMediaSession session;
  final WidgetBuilder builder;
  final Widget child;

  @override
  State<DwMediaFullscreenHost> createState() => _DwMediaFullscreenHostState();
}

final class _DwMediaFullscreenHostState extends State<DwMediaFullscreenHost> {
  _FullscreenRoute? _route;

  @override
  void initState() {
    super.initState();
    _attach(widget.session);
    WidgetsBinding.instance.addPostFrameCallback((_) => _sync());
  }

  @override
  void didUpdateWidget(DwMediaFullscreenHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (identical(oldWidget.session, widget.session)) return;
    _detach(oldWidget.session);
    _attach(widget.session);
    WidgetsBinding.instance.addPostFrameCallback((_) => _sync());
  }

  void _attach(DwMediaSession session) {
    session._fullscreenHosts++;
    session._fullscreen.addListener(_sync);
  }

  void _detach(DwMediaSession session) {
    session._fullscreenHosts--;
    session._fullscreen.removeListener(_sync);
  }

  void _sync() {
    final session = widget.session;
    if (!mounted || _route != null || !session._fullscreen.value) return;
    final route = _FullscreenRoute(session: session, builder: widget.builder);
    _route = route;
    unawaited(
      Navigator.of(context, rootNavigator: true).push(route).whenComplete(() {
        if (identical(_route, route)) _route = null;
      }),
    );
  }

  @override
  void dispose() {
    _detach(widget.session);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// The fullscreen route. Not exported: `DwMediaFullscreenHost` is the one
/// way in, so the flag and the route cannot disagree.
final class _FullscreenRoute extends PageRoute<void> {
  _FullscreenRoute({required this.session, required this.builder});

  final DwMediaSession session;
  final WidgetBuilder builder;

  @override
  bool get opaque => true;

  @override
  Color? get barrierColor => null;

  @override
  String? get barrierLabel => null;

  @override
  bool get maintainState => true;

  @override
  Duration get transitionDuration =>
      session.options.fullscreenTransitionDuration;

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) => _FullscreenPresence(
    session: session,
    child: Builder(builder: builder),
  );

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final custom = session.options.fullscreenTransitionBuilder;
    if (custom != null) {
      return custom(context, animation, secondaryAnimation, child);
    }
    return FadeTransition(opacity: animation, child: child);
  }
}

/// Keeps `session.isFullscreen` true to the route's presence and owns the
/// orientations: sets `fullscreenOrientations` when it comes, and — only if
/// it set any — `exitOrientations` when it goes.
final class _FullscreenPresence extends StatefulWidget {
  const _FullscreenPresence({required this.session, required this.child});

  final DwMediaSession session;
  final Widget child;

  @override
  State<_FullscreenPresence> createState() => _FullscreenPresenceState();
}

final class _FullscreenPresenceState extends State<_FullscreenPresence> {
  bool _leaving = false;
  bool _orientationsSet = false;

  @override
  void initState() {
    super.initState();
    widget.session._fullscreen.addListener(_onFullscreen);
    final orientations = widget.session.options.fullscreenOrientations;
    if (orientations.isNotEmpty) {
      _orientationsSet = true;
      unawaited(SystemChrome.setPreferredOrientations(orientations));
    }
  }

  void _onFullscreen() {
    if (widget.session._fullscreen.value || _leaving || !mounted) return;
    final route = ModalRoute.of(context);
    if (route == null || !route.isActive) return;
    _leaving = true;
    final navigator = Navigator.of(context);
    if (route.isCurrent) {
      navigator.pop();
    } else {
      navigator.removeRoute(route);
    }
  }

  @override
  void dispose() {
    final session = widget.session;
    session._fullscreen.removeListener(_onFullscreen);
    session.exitFullscreen();
    if (_orientationsSet) {
      unawaited(
        SystemChrome.setPreferredOrientations(session.options.exitOrientations),
      );
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
