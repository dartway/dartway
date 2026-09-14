part of 'dw_window_list_view.dart';

/// Drives a [DwWindowListView] and tells what it shows: the "↓" button with
/// its counter, a floating date, a pinned bar that scrolls to a message.
///
/// Owned by the screen: created once (`useMemoized`, `initState`) and
/// [dispose]d with it. One list at a time; commands before a list is attached
/// do nothing.
class DwWindowListController<T extends DwDataObject> {
  DwWindowListController();

  final ValueNotifier<bool> _atNewest = ValueNotifier(true);
  final ValueNotifier<int> _newerCount = ValueNotifier(0);
  final ValueNotifier<T?> _topVisible = ValueNotifier(null);
  final ValueNotifier<T?> _bottomVisible = ValueNotifier(null);
  final ValueNotifier<bool> _scrolling = ValueNotifier(false);

  _DwWindowListViewState<T>? _view;

  /// Whether the list stands at the newest item of the sequence: the newest
  /// items are loaded and the end is on screen. The "↓" button shows while
  /// this is false.
  ValueListenable<bool> get isAtNewest => _atNewest;

  /// Items newer than any the list has shown: loaded ones below the screen
  /// plus the window's unseen ones that arrived past its loaded end. Zero at
  /// the newest item.
  ValueListenable<int> get newerCount => _newerCount;

  /// The topmost item on screen (below the list's top padding), for a
  /// floating date.
  ValueListenable<T?> get topVisibleItem => _topVisible;

  /// The lowest item on screen (above the list's bottom padding).
  ValueListenable<T?> get bottomVisibleItem => _bottomVisible;

  /// Whether the list is moving — a finger, a fling, an animation, or a mouse
  /// wheel within the last 200 ms.
  ValueListenable<bool> get isScrolling => _scrolling;

  bool get isAttached => _view != null;

  /// Scrolls to the item at [cursor] (`request.cursorOf(item)`, or a cursor
  /// built from a quote's time and id) and highlights it. A near item is
  /// scrolled to, a loaded far one is placed at once, and one that is not
  /// loaded reopens the window around it. [alignment] is where the item's
  /// top ends, as a fraction of the height.
  ///
  /// Completes with whether the item is in the list — `false` for one that
  /// no longer exists (the window still opens around where it was).
  Future<bool> scrollToCursor(String cursor, {double alignment = 0.3}) =>
      _view?._scrollTo(cursor, alignment) ?? Future.value(false);

  /// [scrollToCursor] for an item at hand.
  Future<bool> scrollToItem(T item, {double alignment = 0.3}) {
    final view = _view;
    if (view == null) return Future.value(false);
    return view._scrollTo(view.widget.request.cursorOf(item), alignment);
  }

  /// Goes to the newest item: scrolls when it is near, places the list at
  /// its end when it is far, and reopens the window at the newest items when
  /// they are not loaded.
  Future<void> jumpToNewest() => _view?._jumpToNewest() ?? Future.value();

  void _attach(_DwWindowListViewState<T> view) => _view = view;

  void _detach(_DwWindowListViewState<T> view) {
    if (identical(_view, view)) _view = null;
  }

  void dispose() {
    _view = null;
    _atNewest.dispose();
    _newerCount.dispose();
    _topVisible.dispose();
    _bottomVisible.dispose();
    _scrolling.dispose();
  }
}
