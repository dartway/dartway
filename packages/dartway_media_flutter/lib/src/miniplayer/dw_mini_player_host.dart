import 'dart:async';

import 'package:flutter/widgets.dart';

import '../config/dw_media_config.dart';
import '../model/dw_media_item.dart';
import '../session/dw_media_session_manager.dart';

/// Builds the mini-player's chrome — look and content only, no mechanics.
///
/// [expand] and [close] are already wired to the session (restoring it and
/// calling `DwMiniPlayerHost.onExpand`, and to
/// `DwMediaSession.closeFromMiniPlayer`); the builder attaches them to
/// whatever gesture its own design wants (typically a tap on the thumbnail
/// and a close icon).
typedef DwMiniPlayerBuilder =
    Widget Function(
      BuildContext context,
      DwMediaSession session,
      VoidCallback expand,
      VoidCallback close,
    );

/// The mini-player — mounted once at the app root, above the navigator
/// (where there is no `Overlay`, so its chrome carries no tooltips). Mechanics only:
/// which session to show (`sessionManager.active`, while it is
/// `session.minimized`), drag, pinch-to-scale within
/// `DwMediaConfig.miniPlayerMinScale`/`maxScale`, snapping to the nearest
/// horizontal edge on release (`miniPlayerSnapToEdges`), and calling
/// [onExpand] with the current item — where that expands *to* is the app's
/// own route, this widget has no opinion.
///
/// ```dart
/// MaterialApp.router(
///   builder: (context, child) => Stack(
///     children: [
///       if (child != null) child,
///       DwMiniPlayerHost(
///         sessionManager: dw.plugins.media.sessionManager,
///         // The router object, not `context`: this sits above the router.
///         onExpand: (item) => router.goNamed('player'),
///         builder: (context, session, expand, close) => AppMiniPlayerChrome(...),
///       ),
///     ],
///   ),
/// )
/// ```
final class DwMiniPlayerHost extends StatefulWidget {
  const DwMiniPlayerHost({
    super.key,
    required this.sessionManager,
    required this.builder,
    required this.onExpand,
  });

  final DwMediaSessionManager sessionManager;
  final DwMiniPlayerBuilder builder;
  final void Function(DwMediaItem item) onExpand;

  @override
  State<DwMiniPlayerHost> createState() => _DwMiniPlayerHostState();
}

final class _DwMiniPlayerHostState extends State<DwMiniPlayerHost> {
  Offset? _position;
  double _scale = 1;
  Offset _dragStartPosition = Offset.zero;
  double _scaleAtGestureStart = 1;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.sessionManager.active,
    builder: (context, _) {
      final session = widget.sessionManager.active.value;
      if (session == null) return const SizedBox.shrink();
      return ListenableBuilder(
        listenable: session.minimized,
        builder: (context, _) {
          if (!session.minimized.value || !session.options.miniPlayer) {
            return const SizedBox.shrink();
          }
          return _buildMiniPlayer(context, session);
        },
      );
    },
  );

  Widget _buildMiniPlayer(BuildContext context, DwMediaSession session) {
    final options = session.options;
    final screenSize = MediaQuery.sizeOf(context);
    final size = Size(
      options.miniPlayerInitialSize.width * _scale,
      options.miniPlayerInitialSize.height * _scale,
    );
    _position ??= _initialOffset(options, screenSize, size);
    final offset = _clamp(_position!, screenSize, size);

    return Positioned(
      left: offset.dx,
      top: offset.dy,
      width: size.width,
      height: size.height,
      child: GestureDetector(
        onScaleStart: (_) {
          _dragStartPosition = offset;
          _scaleAtGestureStart = _scale;
        },
        onScaleUpdate: (details) {
          setState(() {
            _position =
                (_position ?? _dragStartPosition) + details.focalPointDelta;
            _scale = (_scaleAtGestureStart * details.scale).clamp(
              options.miniPlayerMinScale,
              options.miniPlayerMaxScale,
            );
          });
        },
        onScaleEnd: (_) => _snapToEdge(session, screenSize, size),
        child: widget.builder(context, session, () {
          session.restore();
          widget.onExpand(session.currentItem);
        }, () => unawaited(session.closeFromMiniPlayer())),
      ),
    );
  }

  void _snapToEdge(DwMediaSession session, Size screenSize, Size size) {
    if (!session.options.miniPlayerSnapToEdges || _position == null) return;
    final current = _clamp(_position!, screenSize, size);
    final maxX = (screenSize.width - size.width).clamp(0.0, double.infinity);
    final snappedX = current.dx <= maxX / 2 ? 0.0 : maxX;
    setState(() => _position = Offset(snappedX, current.dy));
  }

  Offset _initialOffset(DwMediaConfig options, Size screenSize, Size size) {
    final maxX = (screenSize.width - size.width).clamp(0.0, double.infinity);
    final maxY = (screenSize.height - size.height).clamp(0.0, double.infinity);
    return options.miniPlayerInitialAlignment.alongSize(Size(maxX, maxY));
  }

  Offset _clamp(Offset position, Size screenSize, Size size) {
    final maxX = (screenSize.width - size.width).clamp(0.0, double.infinity);
    final maxY = (screenSize.height - size.height).clamp(0.0, double.infinity);
    return Offset(position.dx.clamp(0.0, maxX), position.dy.clamp(0.0, maxY));
  }
}
