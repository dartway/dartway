part of 'dw_client.dart';

/// One watcher of a request. Watches of equal requests share one live entry;
/// [close] releases this one's share.
final class DwWatch<R> {
  DwWatch._(this._entry);

  final _RequestEntry<Object?> _entry;
  final Set<MultiStreamController<DwRequestState<R>>> _listeners = {};
  bool _closed = false;
  DwRequestState<Object?>? _lastRaw;
  DwRequestState<R>? _lastView;

  DwRequest<R> get request => _entry.request as DwRequest<R>;

  /// The state now.
  DwRequestState<R> get state => _view(_entry.state);

  /// The state now, then every change. Each listener starts with the current
  /// state, whenever it subscribes. Done when the watch closes.
  Stream<DwRequestState<R>> get states => Stream.multi((controller) {
    controller.add(state);
    if (_closed) {
      controller.close();
      return;
    }
    _listeners.add(controller);
    controller.onCancel = () => _listeners.remove(controller);
  });

  /// Whether the data shown follows the server live — see [DwRequestData.live].
  bool get isLive => switch (state) {
    DwRequestData(:final live) => live,
    _ => false,
  };

  bool get isClosed => _closed;

  /// Runs the request again (pull to refresh). Coalesced with every other
  /// trigger: at most one run in flight and one after it. Completes when a run
  /// that started after this call has been answered.
  Future<void> refetch() {
    if (_closed) throw StateError('This watch is closed.');
    return _entry.refetch();
  }

  /// Releases this watcher. The last watcher's close releases the entry after
  /// `DwClientOptions.releaseDelay` — its subscriptions with it.
  void close() {
    if (_closed) return;
    _closeFromEntry();
    _entry.handles.remove(this);
    _entry.client._release(_entry);
  }

  void _closeFromEntry() {
    _closed = true;
    for (final listener in _listeners.toList()) {
      listener.close();
    }
    _listeners.clear();
  }

  void _emit(DwRequestState<Object?> raw) {
    final view = _view(raw);
    for (final listener in _listeners.toList()) {
      listener.add(view);
    }
  }

  /// [raw] as a state of [R]. The entry was created by the first watcher of
  /// the request and carries that watcher's type argument; a later watcher
  /// that names the result type differently (an erased `DwRequest<Object?>`,
  /// say) gets the same state re-typed rather than a cast error. The value
  /// itself always has the request's real type.
  DwRequestState<R> _view(DwRequestState<Object?> raw) {
    if (raw is DwRequestState<R>) return raw;
    if (identical(raw, _lastRaw)) return _lastView!;
    final view = _retype<R>(raw);
    _lastRaw = raw;
    _lastView = view;
    return view;
  }
}

/// One watcher of a paginated request.
final class DwPagedWatch<T extends DwDataObject> {
  DwPagedWatch._(this._entry);

  final _PagedEntry<DwDataObject> _entry;
  final Set<MultiStreamController<DwRequestState<DwPagedData<T>>>> _listeners =
      {};
  bool _closed = false;
  DwRequestState<Object?>? _lastRaw;
  DwRequestState<DwPagedData<T>>? _lastView;

  DwRequest<DwPage<T>> get request => _entry.request as DwRequest<DwPage<T>>;

  DwRequestState<DwPagedData<T>> get state => _view(_entry.state);

  /// The state now, then every change; done when the watch closes.
  Stream<DwRequestState<DwPagedData<T>>> get states =>
      Stream.multi((controller) {
        controller.add(state);
        if (_closed) {
          controller.close();
          return;
        }
        _listeners.add(controller);
        controller.onCancel = () => _listeners.remove(controller);
      });

  /// Whether the server has a page after the loaded ones. `false` until the
  /// first page arrives.
  bool get hasMore => switch (state) {
    DwRequestData(:final value) => value.hasMore,
    _ => false,
  };

  bool get isLive => switch (state) {
    DwRequestData(:final live) => live,
    _ => false,
  };

  bool get isClosed => _closed;

  /// Loads the next page. A no-op without data or without more; while
  /// anything is loading, it waits for that instead of asking again — a list
  /// that calls it on every scroll event sends one request.
  Future<void> loadMore() {
    if (_closed) throw StateError('This watch is closed.');
    return _entry.loadMore();
  }

  /// Loads from the top again, as many items as are loaded (coalesced).
  Future<void> refetch() {
    if (_closed) throw StateError('This watch is closed.');
    return _entry.refetch();
  }

  void close() {
    if (_closed) return;
    _closeFromEntry();
    _entry.handles.remove(this);
    _entry.client._release(_entry);
  }

  void _closeFromEntry() {
    _closed = true;
    for (final listener in _listeners.toList()) {
      listener.close();
    }
    _listeners.clear();
  }

  void _emit(DwRequestState<Object?> raw) {
    final view = _view(raw);
    for (final listener in _listeners.toList()) {
      listener.add(view);
    }
  }

  DwRequestState<DwPagedData<T>> _view(DwRequestState<Object?> raw) {
    if (raw is DwRequestState<DwPagedData<T>>) return raw;
    if (identical(raw, _lastRaw)) return _lastView!;
    final view = switch (raw) {
      DwRequestData(:final value, :final refreshing, :final live) =>
        DwRequestData<DwPagedData<T>>(
          _retypePages<T>(value! as DwPagedData<DwDataObject>),
          refreshing: refreshing,
          live: live,
        ),
      _ => _retype<DwPagedData<T>>(raw),
    };
    _lastRaw = raw;
    _lastView = view;
    return view;
  }
}

DwRequestState<S> _retype<S>(DwRequestState<Object?> raw) => switch (raw) {
  DwRequestLoading() => DwRequestLoading<S>(),
  DwRequestData(:final value, :final refreshing, :final live) =>
    DwRequestData<S>(value as S, refreshing: refreshing, live: live),
  DwRequestRefused(:final refusal) => DwRequestRefused<S>(refusal),
  DwRequestFailed(:final incidentId) => DwRequestFailed<S>(incidentId),
  DwRequestUnauthenticated() => DwRequestUnauthenticated<S>(),
};

DwPagedData<T> _retypePages<T extends DwDataObject>(
  DwPagedData<DwDataObject> data,
) => DwPagedData<T>(
  data.items is List<T> ? data.items as List<T> : List<T>.from(data.items),
  hasMore: data.hasMore,
  loadingMore: data.loadingMore,
  loadMoreError: data.loadMoreError,
);
