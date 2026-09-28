import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../session/dw_media_session.dart';

/// Pushes [session] into its own fullscreen route — own route, no chewie,
/// per `dartway/dartway#372`. [builder] is the app's own fullscreen player
/// widget (video surface + controls); it renders whichever item [session] is
/// currently on, so the queue advancing while fullscreen
/// (`DwMediaConfig.keepFullscreenAcrossItems`) needs no action here — the
/// route stays mounted and `builder` re-renders through `session`'s own
/// listenables.
///
/// Does nothing when `session.options.fullscreen` is off.
Future<void> showDwMediaFullscreen(
  BuildContext context, {
  required DwMediaSession session,
  required WidgetBuilder builder,
}) async {
  if (!session.options.fullscreen) return;
  final navigator = Navigator.of(context, rootNavigator: true);
  session.isFullscreen.value = true;
  final orientations = session.options.fullscreenOrientations;
  if (orientations.isNotEmpty) {
    await SystemChrome.setPreferredOrientations(orientations);
  }
  await navigator.push<void>(
    DwMediaFullscreenRoute(session: session, builder: builder),
  );
}

/// The route [showDwMediaFullscreen] pushes. Exposed for a project that wants
/// to push it itself (a custom transition, a nested navigator) rather than
/// through the helper function.
final class DwMediaFullscreenRoute extends PageRoute<void> {
  DwMediaFullscreenRoute({required this.session, required this.builder});

  final DwMediaSession session;
  final WidgetBuilder builder;

  @override
  bool get opaque => true;

  @override
  bool get barrierDismissible => false;

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
  ) => _DwMediaFullscreenWatcher(
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

/// Restores orientation and flips `session.isFullscreen` back to `false`
/// exactly once, on `dispose` — reached the same way whether fullscreen ends
/// by a system back gesture, `Navigator.pop`, or the app calling
/// `session.exitFullscreen()` while this route is still current (the
/// listener below then pops it).
final class _DwMediaFullscreenWatcher extends StatefulWidget {
  const _DwMediaFullscreenWatcher({required this.session, required this.child});

  final DwMediaSession session;
  final Widget child;

  @override
  State<_DwMediaFullscreenWatcher> createState() =>
      _DwMediaFullscreenWatcherState();
}

final class _DwMediaFullscreenWatcherState
    extends State<_DwMediaFullscreenWatcher> {
  @override
  void initState() {
    super.initState();
    widget.session.isFullscreen.addListener(_onFullscreenChanged);
  }

  void _onFullscreenChanged() {
    if (widget.session.isFullscreen.value) return;
    final route = ModalRoute.of(context);
    if (route != null && route.isCurrent) Navigator.of(context).pop();
  }

  @override
  void dispose() {
    widget.session.isFullscreen.removeListener(_onFullscreenChanged);
    if (!widget.session.isDisposed) widget.session.isFullscreen.value = false;
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
