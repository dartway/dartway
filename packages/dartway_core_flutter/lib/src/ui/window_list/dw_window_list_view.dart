import 'dart:async';

import 'package:dartway_client/dartway_client.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/dw_flutter_core.dart';
import '../../data/dw_request_notifiers.dart';
import '../../private/dw_singleton.dart';

part 'dw_window_list_controller.dart';
part 'dw_window_list_render.dart';

/// One row of a [DwWindowListView]: the item and its loaded neighbours, for
/// what depends on them — a date separator above the first message of a day,
/// a bubble grouped with the author's previous one.
final class DwWindowListItem<T extends DwDataObject> {
  const DwWindowListItem({
    required this.item,
    this.older,
    this.newer,
    this.isHighlighted = false,
  });

  final T item;

  /// The loaded item just older than [item] — shown above it. `null` for the
  /// oldest loaded item, whether or not older ones exist on the server.
  final T? older;

  /// The loaded item just newer than [item] — shown below it.
  final T? newer;

  /// Whether the list was just scrolled to [item]
  /// ([DwWindowListController.scrollToCursor]); true for
  /// [DwWindowListView.highlightDuration].
  final bool isHighlighted;
}

/// Which end of the loaded items an edge slot stands at.
enum DwWindowListEdge {
  /// Above the oldest loaded item.
  older,

  /// Below the newest loaded item.
  newer,
}

/// A list over `dw.window(request)`: newest at the bottom, older above, grown
/// in both directions as it is scrolled — the chat list.
///
/// **Not reversed.** It is a `CustomScrollView` centred on the split between
/// two slivers: the items up to the anchor grow upward from the split, the
/// items after it grow downward. Loading older items adds to the top of the
/// upper sliver and loading newer ones to the bottom of the lower one, so
/// neither moves what is on screen — no offset is compensated after the
/// fact, there is nothing to compensate. The viewport's zero is its bottom
/// edge (`anchor: 1`), so a keyboard or any other change of height keeps the
/// newest items where the eye is.
///
/// - Opens at [initialAnchor] (a window cursor, `request.cursorOf(item)` —
///   typically where the person stopped reading) with that item's bottom at
///   [anchorAlignment] of the height, or at the newest items when `null`.
///   Never leaves blank space under the newest item: when fewer items follow
///   the anchor than would fill the rest, the list stands at its end.
/// - Loads older and newer items when fewer than [loadTriggerExtent]
///   viewports remain beyond the loaded ones.
/// - Stays at the newest item when it is there and new items arrive live;
///   anywhere else nothing moves, and [DwWindowListController.newerCount]
///   counts what arrived below.
/// - [DwWindowListController.scrollToCursor] scrolls to an item — animated
///   when it is near, placed at once when it is loaded but far, and by
///   reopening the window around it when it is not loaded (a pinned message,
///   a search result, the quote of a reply).
/// - [DwWindowListController.jumpToNewest] goes to the newest items,
///   reopening the window at them when they are not loaded.
/// - [onVisibleItemsChanged] reports what is on screen, debounced — what
///   read tracking needs.
///
/// Reads the app core `dw` for the window: the provider is
/// `dw.window(request, anchor: …)`, shared with any other widget watching it.
/// Ships no design: every row is [itemBuilder]'s, and the slots default to a
/// plain progress indicator.
class DwWindowListView<T extends DwDataObject> extends ConsumerStatefulWidget {
  const DwWindowListView({
    super.key,
    required this.request,
    required this.itemBuilder,
    this.initialAnchor,
    this.anchorAlignment = 0.35,
    this.controller,
    this.padding = EdgeInsets.zero,
    this.loadingBuilder,
    this.errorBuilder,
    this.emptyBuilder,
    this.edgeBuilder,
    this.onVisibleItemsChanged,
    this.visibleItemsDebounce = const Duration(milliseconds: 300),
    this.loadTriggerExtent = 1.5,
    this.newestTolerance = 24,
    this.highlightDuration = const Duration(milliseconds: 1600),
    this.scrollDuration = const Duration(milliseconds: 280),
    this.scrollCacheExtent,
    this.physics,
  }) : assert(
         anchorAlignment >= 0 && anchorAlignment <= 1,
         'anchorAlignment is a fraction of the height',
       );

  final DwWindowRequest<T, Object, Object> request;

  final Widget Function(BuildContext context, DwWindowListItem<T> row)
  itemBuilder;

  /// Where the list opens: a cursor of the window's sequence, or `null` for
  /// the newest items. Read when the list first opens; a later value is not
  /// followed (the person has scrolled since) — give the list another key to
  /// open it elsewhere.
  final String? initialAnchor;

  /// Where the bottom of the [initialAnchor] item stands, as a fraction of
  /// the list's height from its top.
  final double anchorAlignment;

  final DwWindowListController<T>? controller;

  /// Space inside the scrollable around the items. Its top and bottom are
  /// also what overlays cover (a pinned bar, a composer): an item hidden
  /// under them is not visible.
  final EdgeInsets padding;

  /// Before the first answer. Default: a centred progress indicator.
  final WidgetBuilder? loadingBuilder;

  /// When the first answer is not data: the error is a `DwRefusalException`,
  /// `DwFailedException`, `DwNotAuthenticatedException` or
  /// `DwTimeoutException`. Default: the error's text.
  final Widget Function(BuildContext context, Object error, VoidCallback retry)?
  errorBuilder;

  /// While the window has no items. New items arriving live replace it with
  /// the list, at its newest end.
  final WidgetBuilder? emptyBuilder;

  /// The slot past the loaded items at an end that has more: loading, idle
  /// (a load starts as it comes near), or [error] with [retry] when the last
  /// load failed. Default: 48 pixels holding a small progress indicator while
  /// loading, or a retry button. Keep its height constant: it stands between
  /// the rows on screen and the rows a load brings.
  final Widget Function(
    BuildContext context,
    DwWindowListEdge edge,
    Object? error,
    VoidCallback retry,
  )?
  edgeBuilder;

  /// The items on screen, newest first — reported [visibleItemsDebounce]
  /// after the list stops changing, and once more when it goes. An item
  /// under [padding] is not on screen.
  final void Function(List<T> visible)? onVisibleItemsChanged;

  final Duration visibleItemsDebounce;

  /// How many heights of the list may remain beyond the loaded items before
  /// more are loaded.
  final double loadTriggerExtent;

  /// How close to the end, in logical pixels, still counts as at the newest
  /// item.
  final double newestTolerance;

  final Duration highlightDuration;

  /// The duration of an animated scroll to a near item or the newest one.
  final Duration scrollDuration;

  /// How far past the screen rows are built ahead; the scroll view's
  /// default when `null`.
  final ScrollCacheExtent? scrollCacheExtent;

  /// The platform's physics by default. The list adds to it what keeps it at
  /// the newest item.
  final ScrollPhysics? physics;

  @override
  ConsumerState<DwWindowListView<T>> createState() =>
      _DwWindowListViewState<T>();
}

/// Which items stand above the split: those before [position], and the one
/// at it when [includes]. `null` position: none — every item is below.
typedef _Split = ({DwWindowPosition<Object, Object>? position, bool includes});

/// What the list does with the next data of its window.
final class _Opening {
  _Opening.newest() : split = null, alignment = 1, highlightId = null;

  _Opening.at(_Split this.split, this.alignment, {this.highlightId});

  /// `null`: at the newest loaded item, placed at the end.
  final _Split? split;
  final double alignment;
  final Object? highlightId;
  final Completer<bool> done = Completer<bool>();

  bool get toNewest => split == null;
}

class _DwWindowListViewState<T extends DwDataObject>
    extends ConsumerState<DwWindowListView<T>>
    implements _DwWindowScrollGate {
  static const _centerKey = ValueKey<String>('dw-window-list-split');
  static const _farOffset = 1e6;

  final _listKey = GlobalKey();

  /// The anchor of the watched window.
  late String? _anchor = widget.initialAnchor;

  /// Applied to the first data of the watched window; set while switching.
  _Opening? _opening;

  /// What is rendered: the watched window's data, or the previous window's
  /// while the next one loads.
  DwWindowData<T>? _data;
  _Split _split = (position: null, includes: false);

  /// Bumped by every opening: a fresh scrollable with its own controller.
  int _generation = 0;
  double _openAlignment = 1;
  bool _openAtEnd = true;
  int _controllerGeneration = -1;
  ScrollController? _controller;
  final List<ScrollController> _retired = [];

  late _DwWindowScrollPhysics _physics = _DwWindowScrollPhysics(
    this,
    parent: widget.physics,
  );

  /// The mounted rows by item id.
  final Map<Object, _DwWindowItemFrameState<T>> _frames = {};

  DwWindowPosition<Object, Object>? _newestSeen;
  bool _hasNewerAtLastFrame = true;
  bool _computeScheduled = false;

  Object? _highlightedId;
  Timer? _highlightTimer;

  Timer? _reportTimer;
  List<T>? _pendingReport;
  List<Object> _reportedIds = const [];

  ValueListenable<bool>? _scrollingSource;

  /// A scroll update came within the last moments: a mouse wheel moves the
  /// list without ever holding the position's scrolling flag up.
  bool _recentlyMoved = false;
  Timer? _movedTimer;

  DwFlutterCore get _core => dw as DwFlutterCore;

  DwWindowProvider<T> get _provider =>
      _core.window(widget.request, anchor: _anchor);

  // ---------------------------------------------------------------- gate --

  @override
  bool get followsNewest => !_hasNewerAtLastFrame && _opening == null;

  @override
  bool get clampsEnd {
    final controller = _controller;
    if (controller == null || !controller.hasClients) return true;
    return !controller.position.isScrollingNotifier.value;
  }

  // ----------------------------------------------------------- lifecycle --

  @override
  void initState() {
    super.initState();
    widget.controller?._attach(this);
  }

  @override
  void didUpdateWidget(covariant DwWindowListView<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?._detach(this);
      widget.controller?._attach(this);
    }
    if (oldWidget.physics != widget.physics) {
      _physics = _DwWindowScrollPhysics(this, parent: widget.physics);
    }
    if (oldWidget.request != widget.request) {
      _flushReport();
      _anchor = widget.initialAnchor;
      _opening = null;
      _data = null;
      _newestSeen = null;
      _reportedIds = const [];
    }
  }

  @override
  void dispose() {
    widget.controller?._detach(this);
    _flushReport();
    _reportTimer?.cancel();
    _highlightTimer?.cancel();
    _movedTimer?.cancel();
    _scrollingSource?.removeListener(_onScrollingChanged);
    _opening?.done.complete(false);
    _controller?.dispose();
    for (final controller in _retired) {
      controller.dispose();
    }
    super.dispose();
  }

  // ------------------------------------------------------------- opening --

  /// Takes [next] from the watched window; decides where the list stands
  /// when it is the first data of an opening.
  void _accept(DwWindowData<T> next) {
    final opening = _opening;
    final previous = _data;
    if (opening != null) {
      _opening = null;
      _open(opening.split, opening.alignment, next);
      final id = opening.highlightId;
      final found = id == null || next.items.any((item) => item.id == id);
      if (id != null && found) _highlight(id);
      if (!opening.done.isCompleted) opening.done.complete(found);
    } else if (previous == null) {
      final anchor = _anchor;
      _open(
        anchor == null
            ? null
            : (
                position: DwWindowCursor.decode(anchor).position,
                includes: true,
              ),
        widget.anchorAlignment,
        next,
      );
    } else if (previous.items.isEmpty && next.items.isNotEmpty) {
      // The first items of an empty window: nothing was on screen to keep.
      _open(null, 1, next);
    }
    _data = next;
  }

  /// Starts a generation: [split] at [alignment] of the height, or the
  /// newest items at the end.
  void _open(_Split? split, double alignment, DwWindowData<T> data) {
    _generation++;
    if (split == null) {
      final newest = data.items.firstOrNull;
      _split = (
        position: newest == null ? null : widget.request.positionOf(newest),
        includes: true,
      );
      _openAtEnd = true;
    } else {
      _split = split;
      _openAtEnd = false;
      _openAlignment = alignment;
    }
  }

  /// How many of [items] (newest first) stand below the split.
  int _newerCount(List<T> items) {
    final split = _split.position;
    if (split == null) return items.length;
    var count = 0;
    for (final item in items) {
      final order = DwWindowCursor.comparePositions(
        widget.request.positionOf(item),
        split,
      );
      if (order < 0 || (order == 0 && _split.includes)) break;
      count++;
    }
    return count;
  }

  ScrollController _controllerFor(double height) {
    final current = _controller;
    if (current != null && _controllerGeneration == _generation) {
      return current;
    }
    if (current != null) {
      _retired.add(current);
      SchedulerBinding.instance.addPostFrameCallback((_) => _disposeRetired());
    }
    _controllerGeneration = _generation;
    final offset = _openAtEnd ? _farOffset : (1 - _openAlignment) * height;
    final controller = ScrollController(
      initialScrollOffset: offset,
      keepScrollOffset: false,
    );
    _controller = controller;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !identical(_controller, controller)) return;
      _listenScrolling(controller);
    });
    return controller;
  }

  void _disposeRetired() {
    for (final controller in _retired.toList()) {
      if (controller.hasClients) continue;
      controller.dispose();
      _retired.remove(controller);
    }
    if (_retired.isNotEmpty) {
      SchedulerBinding.instance.addPostFrameCallback((_) => _disposeRetired());
    }
  }

  void _listenScrolling(ScrollController controller) {
    _scrollingSource?.removeListener(_onScrollingChanged);
    _scrollingSource = null;
    if (!controller.hasClients) return;
    final source = controller.position.isScrollingNotifier;
    source.addListener(_onScrollingChanged);
    _scrollingSource = source;
  }

  void _onScrollingChanged() {
    _publishScrolling();
    _scheduleCompute();
  }

  void _publishScrolling() {
    widget.controller?._scrolling.value =
        (_scrollingSource?.value ?? false) || _recentlyMoved;
  }

  void _onMoved() {
    _movedTimer?.cancel();
    _movedTimer = Timer(const Duration(milliseconds: 200), () {
      _recentlyMoved = false;
      if (mounted) _publishScrolling();
    });
    if (!_recentlyMoved) {
      _recentlyMoved = true;
      _publishScrolling();
    }
  }

  // ------------------------------------------------------------ commands --

  /// Runs [command] now, or after the frame when called while widgets
  /// build — a screen may well ask for a scroll from its own build.
  Future<R> _whenIdle<R>(Future<R> Function() command) {
    final phase = SchedulerBinding.instance.schedulerPhase;
    if (phase != SchedulerPhase.persistentCallbacks &&
        phase != SchedulerPhase.midFrameMicrotasks) {
      return command();
    }
    final done = Completer<R>();
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      done.complete(command());
    });
    return done.future;
  }

  Future<bool> _scrollTo(String cursor, double alignment) =>
      _whenIdle(() => _scrollToNow(cursor, alignment));

  Future<bool> _scrollToNow(String cursor, double alignment) async {
    final position = DwWindowCursor.decode(cursor).position;
    final data = _data;
    final loaded =
        _opening == null &&
        data != null &&
        data.items.any((item) => item.id == position.id);
    if (loaded) {
      final frame = _frames[position.id];
      final box = frame?.context.findRenderObject();
      final listBox = _listKey.currentContext?.findRenderObject();
      final controller = _controller;
      if (box is RenderBox &&
          box.hasSize &&
          box.attached &&
          listBox is RenderBox &&
          controller != null &&
          controller.hasClients) {
        // Measured, not asked of the viewport: above the split rows grow
        // upward, and a reveal offset counts its alignment the other way
        // there.
        final scroll = controller.position;
        final y = box.localToGlobal(Offset.zero, ancestor: listBox).dy;
        final target = (scroll.pixels + y - alignment * listBox.size.height)
            .clamp(scroll.minScrollExtent, scroll.maxScrollExtent);
        if ((target - scroll.pixels).abs() > 0.5) {
          await scroll.animateTo(
            target,
            duration: widget.scrollDuration,
            curve: Curves.easeOutCubic,
          );
        }
      } else {
        setState(() {
          _open((position: position, includes: false), alignment, data);
        });
      }
      if (mounted) _highlight(position.id);
      return true;
    }
    final opening = _Opening.at(
      (position: position, includes: false),
      alignment,
      highlightId: position.id,
    );
    _switchTo(cursor, opening);
    return opening.done.future;
  }

  Future<void> _jumpToNewest() => _whenIdle(_jumpToNewestNow);

  Future<void> _jumpToNewestNow() async {
    final data = _data;
    final controller = _controller;
    if (data == null) return;
    if (data.hasNewer || _opening != null) {
      final opening = _Opening.newest();
      _switchTo(null, opening);
      await opening.done.future;
      return;
    }
    if (controller == null || !controller.hasClients) return;
    final position = controller.position;
    if (position.extentAfter > position.viewportDimension * 2) {
      setState(() => _open(null, 1, data));
      return;
    }
    await position.animateTo(
      position.maxScrollExtent,
      duration: widget.scrollDuration,
      curve: Curves.easeOutCubic,
    );
    // The end is an estimate until the last rows are laid out.
    for (var i = 0; i < 3 && mounted && controller.hasClients; i++) {
      final end = controller.position.maxScrollExtent;
      if (controller.position.pixels >= end - 0.5) break;
      controller.position.jumpTo(end);
      await SchedulerBinding.instance.endOfFrame;
    }
  }

  /// Watches the window at [anchor] and opens it by [opening] once it
  /// answers. The current window keeps rendering meanwhile.
  void _switchTo(String? anchor, _Opening opening) {
    final previous = _opening;
    if (previous != null && !previous.done.isCompleted) {
      previous.done.complete(false);
    }
    if (anchor == _anchor) {
      // The same window: its data is here already.
      final data = _data;
      setState(() {
        if (data != null) {
          _open(opening.split, opening.alignment, data);
          final id = opening.highlightId;
          final found = id == null || data.items.any((item) => item.id == id);
          if (id != null && found) _highlight(id);
          opening.done.complete(found);
        } else {
          _opening = opening;
        }
      });
      if (data == null) return;
      if (opening.toNewest) {
        unawaited(ref.read(_provider.notifier).refetch());
      }
      return;
    }
    setState(() {
      _anchor = anchor;
      _opening = opening;
    });
  }

  void _highlight(Object id) {
    _highlightTimer?.cancel();
    if (_highlightedId != id) {
      if (mounted) setState(() => _highlightedId = id);
    }
    _highlightTimer = Timer(widget.highlightDuration, () {
      if (mounted) setState(() => _highlightedId = null);
    });
  }

  // -------------------------------------------------------- measurement --

  void _scheduleCompute() {
    if (_computeScheduled) return;
    _computeScheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _computeScheduled = false;
      _compute();
    });
    SchedulerBinding.instance.ensureVisualUpdate();
  }

  /// After a frame: what is on screen, whether the list stands at the
  /// newest item, what waits below, and whether an end needs loading.
  void _compute() {
    if (!mounted) return;
    final data = _data;
    final controller = _controller;
    final listBox = _listKey.currentContext?.findRenderObject();
    _hasNewerAtLastFrame = data?.hasNewer ?? true;
    if (data == null ||
        controller == null ||
        !controller.hasClients ||
        listBox is! RenderBox ||
        !listBox.hasSize) {
      return;
    }
    final position = controller.position;
    if (!position.hasContentDimensions) return;
    final height = listBox.size.height;
    final top = widget.padding.top;
    final bottom = height - widget.padding.bottom;

    final visible = <(double, T)>[];
    for (final frame in _frames.values) {
      final box = frame.context.findRenderObject();
      if (box is! RenderBox || !box.hasSize || !box.attached) continue;
      final y = box.localToGlobal(Offset.zero, ancestor: listBox).dy;
      if (y + box.size.height > top && y < bottom) {
        visible.add((y, frame.widget.row.item));
      }
    }
    visible.sort((a, b) => a.$1.compareTo(b.$1));
    final request = widget.request;

    for (final (_, item) in visible) {
      final at = request.positionOf(item);
      final seen = _newestSeen;
      if (seen == null || DwWindowCursor.comparePositions(at, seen) > 0) {
        _newestSeen = at;
      }
    }
    final atNewest =
        !data.hasNewer && position.extentAfter <= widget.newestTolerance;
    var below = 0;
    final seen = _newestSeen;
    if (!atNewest) {
      for (final item in data.items) {
        if (seen != null &&
            DwWindowCursor.comparePositions(request.positionOf(item), seen) <=
                0) {
          break;
        }
        below++;
      }
    }
    final controllerOut = widget.controller;
    if (controllerOut != null) {
      controllerOut._atNewest.value = atNewest;
      controllerOut._newerCount.value = below + data.unseenNewerCount;
      controllerOut._topVisible.value = visible.firstOrNull?.$2;
      controllerOut._bottomVisible.value = visible.lastOrNull?.$2;
    }

    if (_opening == null && data.loadError == null) {
      final trigger = height * widget.loadTriggerExtent;
      final notifier = ref.read(_provider.notifier);
      if (data.hasOlder &&
          !data.loadingOlder &&
          position.extentBefore < trigger) {
        unawaited(notifier.loadOlder());
      }
      if (data.hasNewer &&
          !data.loadingNewer &&
          position.extentAfter < trigger) {
        unawaited(notifier.loadNewer());
      }
    }

    if (widget.onVisibleItemsChanged != null) {
      final newestFirst = [for (final (_, item) in visible.reversed) item];
      final ids = [for (final item in newestFirst) item.id];
      if (!listEquals(ids, _reportedIds)) {
        _reportedIds = ids;
        _pendingReport = newestFirst;
        _reportTimer?.cancel();
        _reportTimer = Timer(widget.visibleItemsDebounce, _flushReport);
      }
    }
  }

  void _flushReport() {
    _reportTimer?.cancel();
    _reportTimer = null;
    final pending = _pendingReport;
    _pendingReport = null;
    if (pending != null) widget.onVisibleItemsChanged?.call(pending);
  }

  // --------------------------------------------------------------- build --

  @override
  Widget build(BuildContext context) {
    final value = ref.watch(_provider);
    switch (value) {
      case AsyncData(:final value):
        _accept(value);
      case AsyncError(:final error) when _data == null:
        return widget.errorBuilder?.call(
              context,
              error,
              () => unawaited(ref.read(_provider.notifier).refetch()),
            ) ??
            Center(child: Text('$error'));
      default:
        if (_data == null) {
          return widget.loadingBuilder?.call(context) ??
              const Center(child: CircularProgressIndicator());
        }
    }
    final data = _data!;
    _scheduleCompute();
    if (data.items.isEmpty && _opening == null) {
      return widget.emptyBuilder?.call(context) ?? const SizedBox.expand();
    }
    return LayoutBuilder(
      key: _listKey,
      builder: (context, constraints) => NotificationListener<Notification>(
        onNotification: (notification) {
          if (notification is ScrollUpdateNotification &&
              notification.depth == 0) {
            _onMoved();
          }
          if (notification is ScrollUpdateNotification ||
              notification is ScrollMetricsNotification ||
              notification is ScrollEndNotification) {
            _scheduleCompute();
          }
          return false;
        },
        child: _buildList(context, data, constraints.maxHeight),
      ),
    );
  }

  Widget _buildList(BuildContext context, DwWindowData<T> data, double height) {
    final items = data.items;
    final newer = _newerCount(items);
    final older = items.length - newer;
    final indexById = <Object, int>{
      for (var i = 0; i < items.length; i++) items[i].id: i,
    };
    final padding = widget.padding;

    Widget row(int index) {
      final item = items[index];
      return _DwWindowItemFrame<T>(
        key: ValueKey<Object>(item.id),
        view: this,
        row: DwWindowListItem<T>(
          item: item,
          older: index + 1 < items.length ? items[index + 1] : null,
          newer: index > 0 ? items[index - 1] : null,
          isHighlighted: _highlightedId == item.id,
        ),
        padding: EdgeInsets.only(left: padding.left, right: padding.right),
        builder: widget.itemBuilder,
      );
    }

    Widget edge(DwWindowListEdge side) {
      final notifier = ref.read(_provider.notifier);
      final retry = side == DwWindowListEdge.older
          ? () => unawaited(notifier.loadOlder())
          : () => unawaited(notifier.loadNewer());
      final error = data.loadError;
      final loading = side == DwWindowListEdge.older
          ? data.loadingOlder
          : data.loadingNewer;
      final custom = widget.edgeBuilder;
      if (custom != null) return custom(context, side, error, retry);
      // One height whatever it shows, so the slot changing moves nothing;
      // no indicator while nothing loads, so nothing animates off screen.
      return SizedBox(
        height: 48,
        child: Center(
          child: error != null
              ? IconButton(onPressed: retry, icon: const Icon(Icons.refresh))
              : loading
              ? const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : null,
        ),
      );
    }

    return CustomScrollView(
      key: ValueKey<int>(_generation),
      controller: _controllerFor(height),
      physics: _physics,
      anchor: 1,
      center: _centerKey,
      scrollCacheExtent: widget.scrollCacheExtent,
      slivers: [
        if (padding.top > 0)
          SliverToBoxAdapter(child: SizedBox(height: padding.top)),
        if (data.hasOlder)
          SliverToBoxAdapter(child: edge(DwWindowListEdge.older)),
        // Above the split, growing upward: index 0 is the newest of them.
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) => row(newer + index),
            childCount: older,
            findChildIndexCallback: (key) {
              final at = indexById[(key as ValueKey<Object>).value];
              return at == null || at < newer ? null : at - newer;
            },
          ),
        ),
        // Below the split, growing downward: index 0 is the oldest of them.
        SliverList(
          key: _centerKey,
          delegate: SliverChildBuilderDelegate(
            (context, index) => row(newer - 1 - index),
            childCount: newer,
            findChildIndexCallback: (key) {
              final at = indexById[(key as ValueKey<Object>).value];
              return at == null || at >= newer ? null : newer - 1 - at;
            },
          ),
        ),
        if (data.hasNewer)
          SliverToBoxAdapter(child: edge(DwWindowListEdge.newer)),
        if (padding.bottom > 0)
          SliverToBoxAdapter(child: SizedBox(height: padding.bottom)),
        _DwEndClamp(gate: this),
      ],
    );
  }
}

/// One row, registered with the list while it is mounted so the list can
/// measure what is on screen and scroll to it.
class _DwWindowItemFrame<T extends DwDataObject> extends StatefulWidget {
  const _DwWindowItemFrame({
    super.key,
    required this.view,
    required this.row,
    required this.padding,
    required this.builder,
  });

  final _DwWindowListViewState<T> view;
  final DwWindowListItem<T> row;
  final EdgeInsets padding;
  final Widget Function(BuildContext context, DwWindowListItem<T> row) builder;

  @override
  State<_DwWindowItemFrame<T>> createState() => _DwWindowItemFrameState<T>();
}

class _DwWindowItemFrameState<T extends DwDataObject>
    extends State<_DwWindowItemFrame<T>> {
  @override
  void initState() {
    super.initState();
    widget.view._frames[widget.row.item.id] = this;
  }

  @override
  void didUpdateWidget(covariant _DwWindowItemFrame<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldId = oldWidget.row.item.id;
    if (oldId != widget.row.item.id || oldWidget.view != widget.view) {
      if (identical(oldWidget.view._frames[oldId], this)) {
        oldWidget.view._frames.remove(oldId);
      }
      widget.view._frames[widget.row.item.id] = this;
    }
  }

  @override
  void dispose() {
    final id = widget.row.item.id;
    if (identical(widget.view._frames[id], this)) {
      widget.view._frames.remove(id);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: widget.padding,
    child: widget.builder(context, widget.row),
  );
}
