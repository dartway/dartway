part of 'dw_app_client.dart';

/// The entry of a window over a newest-first sequence, opened at an anchor
/// (or the newest rows) and grown in both directions by cursors.
final class _WindowEntry<T extends DwDataObject> extends _Entry {
  _WindowEntry(super.client, super.key);

  DwRequestState<DwWindowData<T>> _state = DwRequestLoading<DwWindowData<T>>();

  @override
  DwRequestState<Object?> get state => _state;

  DwWindowRequest<T> get _typed => request as DwWindowRequest<T>;

  /// The anchor the window opened at; `null` for the newest rows.
  String? get _anchor => key.$3;

  String? _olderCursor;
  String? _newerCursor;

  /// Ids of new rows that arrived while the window did not show the newest
  /// rows. A set, so a row updated twice is counted once.
  final Set<Object> _unseen = {};

  _Op? _pendingOlder;
  _Op? _pendingNewer;

  DwWindowData<T>? get data => switch (_state) {
    DwRequestData(:final value) => value,
    _ => null,
  };

  void _emit(DwRequestState<DwWindowData<T>> next) {
    if (next == _state) return;
    _state = next;
    notifyWatches();
  }

  void _emitData(DwWindowData<T> value, {bool refreshing = false}) =>
      _emit(DwRequestData(value, refreshing: refreshing, live: live));

  bool get _refreshing => switch (_state) {
    DwRequestData(:final refreshing) => refreshing,
    _ => false,
  };

  /// [current] with some fields changed and the cursors' flags recomputed.
  DwWindowData<T> _copy(
    DwWindowData<T> current, {
    List<T>? items,
    bool? loadingOlder,
    bool? loadingNewer,
    Exception? loadError,
    bool keepError = true,
    int prependedCount = 0,
  }) => DwWindowData<T>(
    items ?? current.items,
    hasOlder: _olderCursor != null,
    hasNewer: _newerCursor != null,
    loadingOlder: loadingOlder ?? current.loadingOlder,
    loadingNewer: loadingNewer ?? current.loadingNewer,
    loadError: keepError ? (loadError ?? current.loadError) : loadError,
    unseenNewerCount: _unseen.length,
    prependedCount: prependedCount,
  );

  int? _ask(int wanted) {
    final request = _typed;
    if (wanted <= request.pageSize) return null;
    return wanted < request.maxPageSize ? wanted : request.maxPageSize;
  }

  Future<void> loadOlder() => _load(_OpKind.older);

  Future<void> loadNewer() => _load(_OpKind.newer);

  Future<void> _load(_OpKind kind) {
    final current = data;
    final more = kind == _OpKind.older ? current?.hasOlder : current?.hasNewer;
    if (disposed || current == null || more != true) return Future.value();
    final running = op;
    if (running != null) {
      // Idempotent while that direction is on its way.
      if (running.kind == kind) return running.done.future;
      final pending = kind == _OpKind.older
          ? (_pendingOlder ??= _Op(kind))
          : (_pendingNewer ??= _Op(kind));
      return pending.done.future;
    }
    final next = _Op(kind);
    start(next);
    return next.done.future;
  }

  @override
  Iterable<_Op> pendingAppends() => [?_pendingNewer, ?_pendingOlder];

  @override
  _Op? takePendingAppend() {
    final newer = _pendingNewer;
    if (newer != null) {
      _pendingNewer = null;
      return newer;
    }
    final older = _pendingOlder;
    _pendingOlder = null;
    return older;
  }

  @override
  ({DwPageQuery? query})? queryFor(_Op target) {
    final current = data;
    switch (target.kind) {
      case _OpKind.reload:
        if (current == null) {
          final anchor = _anchor;
          return (
            query: anchor == null
                ? const DwWindowQuery.newest()
                : DwWindowQuery.around(anchor),
          );
        }
        // Reloaded where it stands: around the anchor, as many rows as are
        // shown — or at the newest rows when it shows them, which then
        // includes whatever arrived meanwhile.
        final ask = _ask(current.items.length);
        final anchor = _anchor;
        return (
          query: anchor == null || !current.hasNewer
              ? DwWindowQuery.newest(pageSize: ask)
              : DwWindowQuery.around(anchor, pageSize: ask),
        );
      case _OpKind.older:
        final cursor = _olderCursor;
        return current == null || cursor == null
            ? null
            : (query: DwWindowQuery.older(cursor));
      case _OpKind.newer:
        final cursor = _newerCursor;
        return current == null || cursor == null
            ? null
            : (query: DwWindowQuery.newer(cursor));
      case _OpKind.more:
        throw StateError('unreachable: a window has no offset pages');
    }
  }

  @override
  void markReloading() {
    final current = data;
    if (current != null) {
      _emitData(
        _copy(current, loadingOlder: false, loadingNewer: false),
        refreshing: true,
      );
    } else if (_state is! DwRequestUnreachable) {
      _emit(DwRequestLoading<DwWindowData<T>>());
    }
  }

  @override
  void markAppending(_Op target) {
    final current = data;
    if (current == null) return;
    _emitData(
      _copy(
        current,
        loadingOlder: target.kind == _OpKind.older ? true : null,
        loadingNewer: target.kind == _OpKind.newer ? true : null,
        keepError: false,
      ),
      refreshing: _refreshing,
    );
  }

  @override
  void markAppendDone(_Op target) {
    final current = data;
    if (current == null) return;
    _emitData(
      _copy(current, loadingOlder: false, loadingNewer: false),
      refreshing: _refreshing,
    );
  }

  @override
  void appendFailed(_Op target, Exception error) {
    final current = data;
    if (current == null) return;
    _emitData(
      _copy(
        current,
        loadingOlder: false,
        loadingNewer: false,
        loadError: error,
        keepError: false,
      ),
      refreshing: _refreshing,
    );
  }

  @override
  void onResponse(_Op target, DwApiResponse response) {
    if (response is! DwApiOk) {
      finish(target, () => answerNotOk(target, response));
      return;
    }
    final DwWindowResult<T> window;
    try {
      window = _typed.decodeResult(response.result, client.protocol);
    } catch (error, stackTrace) {
      undecodable(target, error, stackTrace);
      return;
    }
    switch (target.kind) {
      case _OpKind.reload:
        _olderCursor = window.olderCursor;
        _newerCursor = window.newerCursor;
        _unseen.clear();
        final (items, _) = _applyBuffered(window.items);
        final previous = data;
        final kept = previous != null && dwListEquals(previous.items, items)
            ? previous.items
            : items;
        finish(target, () {
          dataSeq = target.seq;
          _emitData(
            DwWindowData<T>(
              kept,
              hasOlder: _olderCursor != null,
              hasNewer: _newerCursor != null,
              unseenNewerCount: _unseen.length,
            ),
          );
        });
      case _OpKind.older || _OpKind.newer:
        final current = data;
        if (current == null) {
          finish(target, () {});
          return;
        }
        final loaded = {for (final item in current.items) item.id};
        final fresh = window.items
            .where((item) => !loaded.contains(item.id))
            .toList();
        final List<T> merged;
        var prepended = 0;
        if (target.kind == _OpKind.older) {
          _olderCursor = window.olderCursor;
          merged = current.items.toList()..addAll(fresh);
        } else {
          _newerCursor = window.newerCursor;
          merged = current.items.toList()..insertAll(0, fresh);
          prepended = fresh.length;
          if (_newerCursor == null) {
            // The window now shows the newest rows: nothing is unseen.
            _unseen.clear();
          } else {
            _unseen.removeAll(fresh.map((item) => item.id));
          }
        }
        final (items, insertedAtHead) = _applyBuffered(merged);
        finish(target, () {
          final seq = dataSeq;
          dataSeq = seq == null || target.seq < seq ? target.seq : seq;
          _emitData(
            _copy(
              current,
              items: items,
              loadingOlder: false,
              loadingNewer: false,
              keepError: false,
              prependedCount: prepended + insertedAtHead,
            ),
            refreshing: _refreshing,
          );
        });
      case _OpKind.more:
        throw StateError('unreachable: a window has no offset pages');
    }
  }

  /// Applies the buffered objects to [items]; returns the result and how many
  /// rows were inserted at the head.
  (List<T>, int) _applyBuffered(List<T> items) {
    var result = items;
    var inserted = 0;
    for (final (object, action) in takeBuffer()) {
      switch (_apply(result, object, action)) {
        case (_Changed(value: final changed), final atHead):
          result = changed! as List<T>;
          inserted += atHead;
        case (_Refetch(), _):
          reloadPending = true;
        case (_Unchanged(), _):
      }
    }
    return (result, inserted);
  }

  /// One action on the window's rows; also counts unseen rows. Returns the
  /// outcome and how many rows it inserted at the head (0 or 1).
  ///
  /// A new row is inserted at the head only while the window shows the
  /// newest rows: otherwise the rows between would be missing above it.
  (_Outcome, int) _apply(
    List<DwDataObject> items,
    DwWireObject object,
    DwUpdateAction action,
  ) {
    final id = _UpdateRules._idOf(object);
    final index = items.indexWhere((item) => item.id == id);
    switch (action) {
      case DwUpdateAction.ignore:
        return (_unchanged, 0);
      case DwUpdateAction.refetch:
        return (_refetch, 0);
      case DwUpdateAction.remove:
        final wasUnseen = _unseen.remove(id);
        if (index >= 0) return (_Changed(items.toList()..removeAt(index)), 0);
        // Only the count changed: the same list, re-emitted by the caller.
        return (wasUnseen ? _Changed(items) : _unchanged, 0);
      case DwUpdateAction.update || DwUpdateAction.upsert:
        if (object is! DwDataObject) {
          misuse(object, action, 'a deletion cannot be inserted');
          return (_unchanged, 0);
        }
        if (index >= 0) {
          return items[index] == object
              ? (_unchanged, 0)
              : (_Changed(items.toList()..[index] = object), 0);
        }
        if (action == DwUpdateAction.update) return (_unchanged, 0);
        if (_newerCursor != null) {
          return (_unseen.add(id) ? _Changed(items) : _unchanged, 0);
        }
        return (_Changed(items.toList()..insert(0, object)), 1);
    }
  }

  @override
  bool applyLive(List<_Accepted> accepted) {
    final current = data;
    if (current == null) {
      return accepted.any((a) => a.$2 == DwUpdateAction.refetch);
    }
    List<DwDataObject> result = current.items;
    final unseenBefore = _unseen.length;
    var inserted = 0;
    var refetch = false;
    var changed = false;
    for (final (object, action) in accepted) {
      final (outcome, atHead) = _guarded(result, object, action);
      switch (outcome) {
        case _Changed(value: final value):
          result = value! as List<DwDataObject>;
          inserted += atHead;
          changed = true;
        case _Refetch():
          refetch = true;
        case _Unchanged():
      }
    }
    if (changed &&
        (!identical(result, current.items) || _unseen.length != unseenBefore)) {
      _emitData(
        _copy(current, items: result as List<T>, prependedCount: inserted),
        refreshing: _refreshing,
      );
    }
    return refetch;
  }

  (_Outcome, int) _guarded(
    List<DwDataObject> items,
    DwWireObject object,
    DwUpdateAction action,
  ) {
    try {
      return _apply(items, object, action);
    } catch (error, stackTrace) {
      client._report(error, stackTrace);
      return (_unchanged, 0);
    }
  }

  @override
  void syncLive() {
    final current = _state;
    final now = live;
    if (current is DwRequestData<DwWindowData<T>> && current.live != now) {
      _emit(
        DwRequestData(current.value, refreshing: current.refreshing, live: now),
      );
    }
  }

  @override
  void showRefusal(DwCallRefusal refusal) => _emit(DwRequestRefused(refusal));

  @override
  void showUnauthenticated() =>
      _emit(DwRequestUnauthenticated<DwWindowData<T>>());

  @override
  void showUnreachable() {
    if (data == null) _emit(DwRequestUnreachable<DwWindowData<T>>());
  }

  @override
  void failWith(String incidentId) => _emit(DwRequestFailed(incidentId));
}
