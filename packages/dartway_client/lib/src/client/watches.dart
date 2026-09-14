part of 'dw_app_client.dart';

/// What every watch does: follow the entry of its request for the current
/// account, replay its state to listeners, and release its share on close.
///
/// [S] is the value type the watch shows. The entry was created by the first
/// watch of the request and carries that watch's type arguments; a later
/// watch that names the type differently gets the same state re-typed rather
/// than a cast error. The values themselves always have the request's real
/// types.
abstract class _Watch<S> {
  _Watch(this._client, this._request, this._anchor);

  final DwAppClient _client;
  final DwDataRequest<Object?> _request;
  final String? _anchor;

  /// The entry shown; `null` before the session is known, during an account
  /// switch, and once closed.
  _Entry? _entry;

  final Set<MultiStreamController<DwRequestState<S>>> _listeners = {};
  bool _closed = false;
  DwRequestState<S>? _lastState;
  DwRequestState<Object?>? _lastRaw;
  DwRequestState<S>? _lastView;

  _Entry _createEntry(_EntryKey key);

  DwRequestState<S> _retype(DwRequestState<Object?> raw);

  /// The state now.
  DwRequestState<S> get state {
    if (_closed) return _lastState ?? DwRequestLoading<S>();
    final entry = _entry;
    if (entry == null) return DwRequestLoading<S>();
    final raw = entry.state;
    if (raw is DwRequestState<S>) return raw;
    if (identical(raw, _lastRaw)) return _lastView!;
    final view = _retype(raw);
    _lastRaw = raw;
    _lastView = view;
    return view;
  }

  /// The state now, then every change. Each listener starts with the current
  /// state, whenever it subscribes. Done when the watch closes.
  Stream<DwRequestState<S>> get states => Stream.multi((controller) {
    final current = state;
    _lastState ??= current;
    controller.add(current);
    if (_closed) {
      controller.close();
      return;
    }
    _listeners.add(controller);
    controller.onCancel = () => _listeners.remove(controller);
  });

  /// Whether the data shown follows the server live — see
  /// [DwRequestData.live].
  bool get isLive => switch (state) {
    DwRequestData(:final live) => live,
    _ => false,
  };

  bool get isClosed => _closed;

  /// Runs the request again (pull to refresh). Coalesced with every other
  /// trigger: at most one run in flight and one after it. Completes when a
  /// run that started after this call has been answered.
  Future<void> refetch() {
    if (_closed) throw StateError('This watch is closed.');
    return _entry?.reload() ?? Future.value();
  }

  /// Releases this watch. The last watch's close releases the entry after
  /// `DwClientOptions.releaseDelay` — its subscriptions with it.
  void close() {
    if (_closed) return;
    _lastState = state;
    _closeListeners();
    final entry = _entry;
    _entry = null;
    _client._watches.remove(this);
    if (entry != null) {
      entry.watches.remove(this);
      _client._release(entry);
    }
  }

  void _closeFromClient() {
    if (_closed) return;
    _lastState = state;
    _entry = null;
    _closeListeners();
  }

  void _closeListeners() {
    _closed = true;
    for (final listener in _listeners.toList()) {
      listener.close();
    }
    _listeners.clear();
  }

  /// Tells listeners about the current state when it changed.
  void _notify() {
    if (_closed) return;
    final next = state;
    if (next == _lastState) return;
    _lastState = next;
    for (final listener in _listeners.toList()) {
      listener.add(next);
    }
  }
}

/// One watcher of a single, maybe or list request, or of a table page.
final class DwRequestWatch<R> extends _Watch<R> {
  DwRequestWatch._(
    DwAppClient client,
    DwDataRequest<R> request, [
    _Entry Function(_EntryKey key)? createEntry,
  ]) : _entryFactory = createEntry,
       super(client, request, null);

  /// How a table watch builds its entry, which needs the item type that `R`
  /// (`DwTablePage<T>`) cannot give back.
  final _Entry Function(_EntryKey key)? _entryFactory;

  DwDataRequest<R> get request => _request as DwDataRequest<R>;

  @override
  _Entry _createEntry(_EntryKey key) =>
      _entryFactory?.call(key) ?? _ValueEntry<R>(_client, key);

  @override
  DwRequestState<R> _retype(DwRequestState<Object?> raw) => switch (raw) {
    DwRequestData(:final value, :final refreshing, :final live) =>
      DwRequestData<R>(value as R, refreshing: refreshing, live: live),
    _ => _retypeEmpty<R>(raw),
  };
}

/// One watcher of an accumulating feed.
final class DwPagesWatch<T extends DwDataObject>
    extends _Watch<DwPagedData<T>> {
  DwPagesWatch._(DwAppClient client, DwPageRequest<T> request)
    : super(client, request, null);

  DwPageRequest<T> get request => _request as DwPageRequest<T>;

  @override
  _Entry _createEntry(_EntryKey key) => _PagesEntry<T>(_client, key);

  /// Whether the server has a page after the loaded ones. `false` until the
  /// first page arrives.
  bool get hasMore => switch (state) {
    DwRequestData(:final value) => value.hasMore,
    _ => false,
  };

  /// Loads the next page. A no-op without data or without more; while a page
  /// is loading it returns that load instead of asking again — a list that
  /// calls it on every scroll event sends one request. Asked while a reload
  /// runs, it loads once the reload has answered.
  Future<void> loadMore() {
    if (_closed) throw StateError('This watch is closed.');
    final entry = _entry;
    return entry is _PagesEntry ? entry.loadMore() : Future.value();
  }

  @override
  DwRequestState<DwPagedData<T>> _retype(DwRequestState<Object?> raw) =>
      switch (raw) {
        DwRequestData(:final value, :final refreshing, :final live) =>
          DwRequestData<DwPagedData<T>>(
            _retypePages<T>(value! as DwPagedData<DwDataObject>),
            refreshing: refreshing,
            live: live,
          ),
        _ => _retypeEmpty<DwPagedData<T>>(raw),
      };
}

/// One watcher of a window.
final class DwWindowWatch<T extends DwDataObject>
    extends _Watch<DwWindowData<T>> {
  DwWindowWatch._(super.client, DwWindowRequest<T> super.request, super.anchor);

  DwWindowRequest<T> get request => _request as DwWindowRequest<T>;

  /// The anchor the window opened at; `null` for the newest rows.
  String? get anchor => _anchor;

  @override
  _Entry _createEntry(_EntryKey key) => _WindowEntry<T>(_client, key);

  /// Loads the rows older than the last one. Idempotent while that load is
  /// on its way; a no-op without data or without older rows.
  Future<void> loadOlder() {
    if (_closed) throw StateError('This watch is closed.');
    final entry = _entry;
    return entry is _WindowEntry ? entry.loadOlder() : Future.value();
  }

  /// Loads the rows newer than the first one; see [loadOlder].
  Future<void> loadNewer() {
    if (_closed) throw StateError('This watch is closed.');
    final entry = _entry;
    return entry is _WindowEntry ? entry.loadNewer() : Future.value();
  }

  @override
  DwRequestState<DwWindowData<T>> _retype(DwRequestState<Object?> raw) =>
      switch (raw) {
        DwRequestData(:final value, :final refreshing, :final live) =>
          DwRequestData<DwWindowData<T>>(
            _retypeWindow<T>(value! as DwWindowData<DwDataObject>),
            refreshing: refreshing,
            live: live,
          ),
        _ => _retypeEmpty<DwWindowData<T>>(raw),
      };
}

DwRequestState<S> _retypeEmpty<S>(DwRequestState<Object?> raw) => switch (raw) {
  DwRequestLoading() => DwRequestLoading<S>(),
  DwRequestRefused(:final refusal) => DwRequestRefused<S>(refusal),
  DwRequestFailed(:final incidentId) => DwRequestFailed<S>(incidentId),
  DwRequestUnauthenticated() => DwRequestUnauthenticated<S>(),
  DwRequestUnreachable() => DwRequestUnreachable<S>(),
  DwRequestData() => throw StateError('unreachable: data is retyped by kind'),
};

List<T> _retypeItems<T>(List<Object?> items) =>
    items is List<T> ? items : List<T>.from(items);

DwPagedData<T> _retypePages<T extends DwDataObject>(
  DwPagedData<DwDataObject> data,
) => DwPagedData<T>(
  _retypeItems<T>(data.items),
  hasMore: data.hasMore,
  loadingMore: data.loadingMore,
  loadMoreError: data.loadMoreError,
);

DwWindowData<T> _retypeWindow<T extends DwDataObject>(
  DwWindowData<DwDataObject> data,
) => DwWindowData<T>(
  _retypeItems<T>(data.items),
  hasOlder: data.hasOlder,
  hasNewer: data.hasNewer,
  loadingOlder: data.loadingOlder,
  loadingNewer: data.loadingNewer,
  loadError: data.loadError,
  unseenNewerCount: data.unseenNewerCount,
  prependedCount: data.prependedCount,
);
