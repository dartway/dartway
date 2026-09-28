import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../session/dw_media_session_manager.dart';

/// Wraps the inline player of a page and puts [session] fullscreen whenever
/// it asks to be: pushes a [DwMediaFullscreenRoute] onto the root navigator
/// when `session.isFullscreen` turns `true` — by `enterFullscreen()`, by
/// `autoEnterFullscreenOnPlay`, already `true` when the page is built — and
/// the route leaves when it turns `false`. One way in, whoever asks.
///
/// [builder] draws the fullscreen page (the project's surface and controls);
/// [child] is what the page shows inline.
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
  DwMediaFullscreenRoute? _route;

  @override
  void initState() {
    super.initState();
    widget.session.isFullscreen.addListener(_sync);
    WidgetsBinding.instance.addPostFrameCallback((_) => _sync());
  }

  @override
  void didUpdateWidget(DwMediaFullscreenHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (identical(oldWidget.session, widget.session)) return;
    oldWidget.session.isFullscreen.removeListener(_sync);
    widget.session.isFullscreen.addListener(_sync);
    _sync();
  }

  void _sync() {
    final session = widget.session;
    if (!mounted || _route != null || !session.isFullscreen.value) return;
    final route = DwMediaFullscreenRoute(
      session: session,
      builder: widget.builder,
    );
    _route = route;
    unawaited(
      Navigator.of(context, rootNavigator: true).push(route).whenComplete(() {
        if (identical(_route, route)) _route = null;
      }),
    );
  }

  @override
  void dispose() {
    widget.session.isFullscreen.removeListener(_sync);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// The fullscreen route: sets `DwMediaConfig.fullscreenOrientations` while it
/// stands and `exitOrientations` when it goes, and keeps
/// `session.isFullscreen` true to its presence — a back gesture ends
/// fullscreen, `session.exitFullscreen()` pops the route. Pushed by
/// [DwMediaFullscreenHost].
final class DwMediaFullscreenRoute extends PageRoute<void> {
  DwMediaFullscreenRoute({required this.session, required this.builder});

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
  Duration get transitionDuration => const Duration(milliseconds: 200);

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
  ) => FadeTransition(opacity: animation, child: child);
}

final class _FullscreenPresence extends StatefulWidget {
  const _FullscreenPresence({required this.session, required this.child});

  final DwMediaSession session;
  final Widget child;

  @override
  State<_FullscreenPresence> createState() => _FullscreenPresenceState();
}

final class _FullscreenPresenceState extends State<_FullscreenPresence> {
  bool _popping = false;

  @override
  void initState() {
    super.initState();
    widget.session.isFullscreen.addListener(_onFullscreen);
    final orientations = widget.session.options.fullscreenOrientations;
    if (orientations.isNotEmpty) {
      unawaited(SystemChrome.setPreferredOrientations(orientations));
    }
  }

  void _onFullscreen() {
    if (widget.session.isFullscreen.value || _popping || !mounted) return;
    final route = ModalRoute.of(context);
    if (route == null || !route.isActive) return;
    _popping = true;
    final navigator = Navigator.of(context);
    if (route.isCurrent) {
      navigator.pop();
    } else {
      navigator.removeRoute(route);
    }
  }

  @override
  void dispose() {
    widget.session.isFullscreen.removeListener(_onFullscreen);
    widget.session.exitFullscreen();
    unawaited(
      SystemChrome.setPreferredOrientations(
        widget.session.options.exitOrientations,
      ),
    );
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
