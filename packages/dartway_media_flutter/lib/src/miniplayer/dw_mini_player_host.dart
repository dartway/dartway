import 'dart:async';
import 'dart:math';

import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:video_player/video_player.dart';

import '../config/dw_media_config.dart';
import '../model/dw_media_item.dart';
import '../session/dw_media_session_manager.dart';

/// Builds the mini-player's chrome — look and content only, no mechanics.
///
/// [expand] and [close] are already wired to the session (restoring it and
/// calling `DwMiniPlayerHost.onExpand`, and to
/// `DwMediaSession.closeFromMiniPlayer`); the builder attaches them to
/// whatever gesture its own design wants (typically a tap on the thumbnail
/// and a close icon). `DwMiniPlayerHost.resizeCornerOf` says where the
/// resize handle sits, so the chrome can draw its mark there and keep its
/// own buttons off that corner.
typedef DwMiniPlayerBuilder =
    Widget Function(
      BuildContext context,
      DwMediaSession session,
      VoidCallback expand,
      VoidCallback close,
    );

/// The mini-player — mounted once at the app root, above the navigator
/// (where there is no `Overlay`, so its chrome carries no tooltips).
/// Mechanics only: which session to show (`sessionManager.active`, while it
/// is `session.minimized`), where it sits and how big it is, and calling
/// [onExpand] with the current item — where that expands *to* is the app's
/// own route, this widget has no opinion.
///
/// - **Placement.** Dragged, it stays where it is released, held inside the
///   visible area (the viewport less `MediaQuery.paddingOf`);
///   `DwMediaConfig.miniPlayerSnapToEdges` settles it on an edge instead.
///   The place it was put is kept while a shrinking window pushes it back
///   in, and it returns there when the window grows again.
/// - **Size.** A width within `miniPlayerMinWidth` and
///   `miniPlayerMaxWidthFraction` of the viewport; the height follows the
///   video's aspect ratio. Resized by a pinch and, while a mouse is connected
///   (`miniPlayerResize`), by dragging the corner opposite the one it is
///   anchored to — the corner nearest the viewport's own stays put.
/// - Both live in this widget's state, so they survive route changes and the
///   player hiding and showing again for as long as the host is mounted.
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

  /// The corner of the mini-player where its resize handle sits — the one
  /// opposite the corner it is anchored to — or `null` while no handle is
  /// shown. Called from the chrome's `builder`; the handle's square is
  /// `DwMediaConfig.miniPlayerResizeHandleExtent` on a side, and a press
  /// inside it resizes rather than reaching the chrome.
  static Alignment? resizeCornerOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<_DwMiniPlayerScope>()
      ?.resizeCorner;

  @override
  State<DwMiniPlayerHost> createState() => _DwMiniPlayerHostState();
}

enum _GestureKind { move, resize }

final class _DwMiniPlayerHostState extends State<DwMiniPlayerHost> {
  /// Where it was put and how wide — what the person last chose, kept while
  /// a small viewport clamps what is drawn. `null` until it first shows.
  Offset? _position;
  double? _width;

  _GestureKind? _gesture;
  Rect _gestureStartRect = Rect.zero;
  Offset _gestureStartFocal = Offset.zero;
  Alignment _gestureCorner = Alignment.topLeft;

  late final MouseTracker _mouseTracker;
  bool _mouseConnected = false;

  DwMediaSession? _watched;
  VideoPlayerController? _controller;

  /// The current video's own ratio; `null` while it reports none.
  double? _videoAspect;

  @override
  void initState() {
    super.initState();
    _mouseTracker = RendererBinding.instance.mouseTracker;
    _mouseConnected = _mouseTracker.mouseIsConnected;
    _mouseTracker.addListener(_onMouseTracker);
  }

  @override
  void dispose() {
    _mouseTracker.removeListener(_onMouseTracker);
    _watch(null, rebuild: false);
    super.dispose();
  }

  void _onMouseTracker() {
    final connected = _mouseTracker.mouseIsConnected;
    if (connected == _mouseConnected) return;
    _mouseConnected = connected;
    _rebuild();
  }

  // --- The video's aspect ratio, without rebuilding on every tick ----------

  void _watch(DwMediaSession? session, {bool rebuild = true}) {
    if (identical(session, _watched)) return;
    _watched?.videoView.removeListener(_onVideoView);
    _watched = session;
    session?.videoView.addListener(_onVideoView);
    _onVideoView(rebuild: rebuild);
  }

  void _onVideoView({bool rebuild = true}) {
    final controller = _watched?.videoView.value;
    if (!identical(controller, _controller)) {
      _controller?.removeListener(_onVideoValue);
      _controller = controller;
      controller?.addListener(_onVideoValue);
    }
    _onVideoValue(rebuild: rebuild);
  }

  void _onVideoValue({bool rebuild = true}) {
    final value = _controller?.value;
    // video_player answers 1.0 for a video with no size yet.
    final aspect = value == null || value.size.isEmpty
        ? null
        : value.aspectRatio;
    if (aspect == _videoAspect) return;
    _videoAspect = aspect;
    if (rebuild) _rebuild();
  }

  /// A notifier may fire while the tree builds (a session opened from a
  /// `build`); the rebuild then waits for the frame to end.
  void _rebuild() {
    if (!mounted) return;
    final scheduler = SchedulerBinding.instance;
    if (scheduler.schedulerPhase == SchedulerPhase.persistentCallbacks) {
      scheduler.addPostFrameCallback((_) {
        if (mounted) setState(() {});
      });
    } else {
      setState(() {});
    }
  }

  // --- Build ---------------------------------------------------------------

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.sessionManager.active,
    builder: (context, _) {
      final session = widget.sessionManager.active.value;
      _watch(session, rebuild: false);
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
    final area = _visibleArea(context);
    final rect = _rectIn(area, options);
    // Mid-resize the handle stays where the pointer took it.
    final corner = !_showHandle(options)
        ? null
        : _gesture == _GestureKind.resize
        ? _gestureCorner
        : _handleCorner(rect, area);
    final extent = options.miniPlayerResizeHandleExtent;

    return Positioned.fromRect(
      rect: rect,
      child: _DwMiniPlayerScope(
        resizeCorner: corner,
        child: GestureDetector(
          onScaleStart: (details) => _onStart(details, rect, corner, extent),
          onScaleUpdate: (details) => _onUpdate(details, area, options),
          onScaleEnd: (_) => _onEnd(area, options),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Its own context, under the scope: `resizeCornerOf` answers
              // from the builder's `context` as well as from the chrome's.
              Builder(
                builder: (context) => widget.builder(context, session, () {
                  session.restore();
                  widget.onExpand(session.currentItem);
                }, () => unawaited(session.closeFromMiniPlayer())),
              ),
              if (corner != null)
                Align(
                  alignment: corner,
                  // Opaque: a press here resizes and never reaches the
                  // chrome underneath — no expand at the end of a resize.
                  child: MouseRegion(
                    cursor: corner.x == corner.y
                        ? SystemMouseCursors.resizeUpLeftDownRight
                        : SystemMouseCursors.resizeUpRightDownLeft,
                    hitTestBehavior: HitTestBehavior.opaque,
                    child: SizedBox.square(dimension: extent),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // --- Gestures ------------------------------------------------------------

  void _onStart(
    ScaleStartDetails details,
    Rect rect,
    Alignment? corner,
    double extent,
  ) {
    // What is drawn becomes what is kept: the person moves what they see.
    _position = rect.topLeft;
    _width = rect.width;
    _gestureStartRect = rect;
    _gestureStartFocal = details.focalPoint;
    final onHandle =
        corner != null &&
        details.pointerCount == 1 &&
        corner
            .inscribe(Size.square(extent), Offset.zero & rect.size)
            .contains(details.localFocalPoint);
    _gesture = onHandle ? _GestureKind.resize : _GestureKind.move;
    if (onHandle) _gestureCorner = corner;
  }

  void _onUpdate(ScaleUpdateDetails details, Rect area, DwMediaConfig options) {
    switch (_gesture) {
      case null:
        return;
      case _GestureKind.move:
        setState(() {
          if (details.pointerCount > 1 &&
              options.miniPlayerResize != DwMiniPlayerResize.never) {
            _width = (_gestureStartRect.width * details.scale).clamp(
              options.miniPlayerMinWidth,
              _maxWidth(area, options),
            );
          }
          _position = _clamp(
            (_position ?? _gestureStartRect.topLeft) + details.focalPointDelta,
            area,
            _sizeIn(area, options),
          );
        });
      case _GestureKind.resize:
        setState(() => _resize(details.focalPoint, area, options));
    }
  }

  /// The handle follows the pointer along whichever axis it moved further;
  /// the opposite corner stays where it was.
  void _resize(Offset focal, Rect area, DwMediaConfig options) {
    final start = _gestureStartRect;
    final corner = _gestureCorner;
    final aspect = _aspect(options);
    final moved = focal - _gestureStartFocal;
    var width = moved.dx.abs() >= (moved.dy * aspect).abs()
        ? start.width + moved.dx * corner.x
        : (start.height + moved.dy * corner.y) * aspect;
    width = width.clamp(options.miniPlayerMinWidth, _maxWidth(area, options));
    final anchor = Offset(
      corner.x < 0 ? start.right : start.left,
      corner.y < 0 ? start.bottom : start.top,
    );
    final roomX = corner.x < 0 ? anchor.dx - area.left : area.right - anchor.dx;
    final roomY = corner.y < 0 ? anchor.dy - area.top : area.bottom - anchor.dy;
    width = min(width, min(roomX, roomY * aspect));
    final height = width / aspect;
    _width = width;
    _position = Offset(
      corner.x < 0 ? anchor.dx - width : anchor.dx,
      corner.y < 0 ? anchor.dy - height : anchor.dy,
    );
  }

  void _onEnd(Rect area, DwMediaConfig options) {
    final wasMove = _gesture == _GestureKind.move;
    _gesture = null;
    if (wasMove && options.miniPlayerSnapToEdges) _snapToEdge(area, options);
  }

  /// Settles a released mini-player on an edge: the nearer side, or the
  /// nearest of all four (`miniPlayerSnapEdges`), and only when it is within
  /// `miniPlayerSnapThreshold` of that edge.
  void _snapToEdge(Rect area, DwMediaConfig options) {
    final rect = _rectIn(area, options);
    final toLeft = rect.left - area.left;
    final toRight = area.right - rect.right;
    final toTop = rect.top - area.top;
    final toBottom = area.bottom - rect.bottom;
    final horizontalGap = min(toLeft, toRight);
    final verticalGap = min(toTop, toBottom);
    final threshold = options.miniPlayerSnapThreshold;
    var snapped = rect.topLeft;
    final useVertical =
        options.miniPlayerSnapEdges == DwMiniPlayerSnapEdges.all &&
        verticalGap < horizontalGap;
    if (useVertical) {
      if (verticalGap <= threshold) {
        snapped = Offset(
          rect.left,
          toTop <= toBottom ? area.top : area.bottom - rect.height,
        );
      }
    } else if (horizontalGap <= threshold) {
      snapped = Offset(
        toLeft <= toRight ? area.left : area.right - rect.width,
        rect.top,
      );
    }
    if (snapped != rect.topLeft) setState(() => _position = snapped);
  }

  // --- Geometry ------------------------------------------------------------

  Rect _visibleArea(BuildContext context) => MediaQuery.paddingOf(
    context,
  ).deflateRect(Offset.zero & MediaQuery.sizeOf(context));

  bool _showHandle(DwMediaConfig options) => switch (options.miniPlayerResize) {
    DwMiniPlayerResize.always => true,
    DwMiniPlayerResize.pointer => _mouseConnected,
    DwMiniPlayerResize.never => false,
  };

  double _aspect(DwMediaConfig options) =>
      _videoAspect ?? options.fallbackAspectRatio;

  double _maxWidth(Rect area, DwMediaConfig options) => max(
    options.miniPlayerMinWidth,
    area.width * options.miniPlayerMaxWidthFraction,
  );

  /// The size drawn: the kept width within its bounds, then within the
  /// visible area — which wins over the minimum.
  Size _sizeIn(Rect area, DwMediaConfig options) {
    final aspect = _aspect(options);
    final wanted = options.miniPlayerResize == DwMiniPlayerResize.never
        ? options.miniPlayerInitialWidth
        : _width ?? options.miniPlayerInitialWidth;
    var width = wanted.clamp(
      options.miniPlayerMinWidth,
      _maxWidth(area, options),
    );
    width = max(0.0, min(width, min(area.width, area.height * aspect)));
    return Size(width, width / aspect);
  }

  Rect _rectIn(Rect area, DwMediaConfig options) {
    final size = _sizeIn(area, options);
    _position ??= options.miniPlayerInitialAlignment
        .inscribe(size, area)
        .topLeft;
    return _clamp(_position!, area, size) & size;
  }

  Offset _clamp(Offset position, Rect area, Size size) {
    final maxX = max(area.left, area.right - size.width);
    final maxY = max(area.top, area.bottom - size.height);
    return Offset(
      position.dx.clamp(area.left, maxX),
      position.dy.clamp(area.top, maxY),
    );
  }

  /// Opposite the corner it is anchored to: in the right half of the area it
  /// is anchored right, so the handle is on its left; likewise vertically.
  Alignment _handleCorner(Rect rect, Rect area) => Alignment(
    rect.center.dx > area.center.dx ? -1 : 1,
    rect.center.dy > area.center.dy ? -1 : 1,
  );
}

final class _DwMiniPlayerScope extends InheritedWidget {
  const _DwMiniPlayerScope({required this.resizeCorner, required super.child});

  final Alignment? resizeCorner;

  @override
  bool updateShouldNotify(_DwMiniPlayerScope oldWidget) =>
      resizeCorner != oldWidget.resizeCorner;
}
