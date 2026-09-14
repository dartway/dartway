part of 'dw_app_client.dart';

/// The entry of an accumulating feed: loaded offset pages merged into one
/// list.
///
/// A reload loads as many rows as were loaded — in one call when the
/// request's `maxPageSize` allows, page by page otherwise — and swaps the list
/// once all have arrived. `loadMore` appends the next page.
final class _PagesEntry<T extends DwDataObject> extends _Entry {
  _PagesEntry(super.client, super.key);

  DwRequestState<DwPagedData<T>> _state = DwRequestLoading<DwPagedData<T>>();

  @override
  DwRequestState<Object?> get state => _state;

  DwPageRequest<T> get _typed => request as DwPageRequest<T>;

  /// Rows of a running reload, merged so far.
  List<T>? _accumulated;

  /// How many rows the running reload loads before it stops.
  int _target = 0;

  /// A `loadMore` asked for while another operation ran.
  _Op? _pendingMore;

  DwPagedData<T>? get data => switch (_state) {
    DwRequestData(:final value) => value,
    _ => null,
  };

  void _emit(DwRequestState<DwPagedData<T>> next) {
    if (next == _state) return;
    _state = next;
    notifyWatches();
  }

  void _emitData(DwPagedData<T> value, {bool refreshing = false}) =>
      _emit(DwRequestData(value, refreshing: refreshing, live: live));

  /// The page size to ask for when [wanted] rows are needed in one call:
  /// `null` (the request's own size) unless more are wanted, at most
  /// `maxPageSize`.
  int? _ask(int wanted) {
    final request = _typed;
    if (wanted <= request.pageSize) return null;
    return wanted < request.maxPageSize ? wanted : request.maxPageSize;
  }

  Future<void> loadMore() {
    final current = data;
    if (disposed || current == null || !current.hasMore) return Future.value();
    final running = op;
    if (running != null) {
      // Idempotent while a page is on its way: a list calling this on every
      // scroll event sends one request.
      if (running.kind == _OpKind.more) return running.done.future;
      return (_pendingMore ??= _Op(_OpKind.more)).done.future;
    }
    final next = _Op(_OpKind.more);
    start(next);
    return next.done.future;
  }

  @override
  Iterable<_Op> pendingAppends() => [?_pendingMore];

  @override
  _Op? takePendingAppend() {
    final next = _pendingMore;
    _pendingMore = null;
    return next;
  }

  @override
  ({DwPageQuery? query})? queryFor(_Op target) {
    switch (target.kind) {
      case _OpKind.reload:
        _accumulated = null;
        _target = data?.items.length ?? 0;
        return (query: DwOffsetQuery(pageSize: _ask(_target)));
      case _OpKind.more:
        final current = data;
        if (current == null || !current.hasMore) return null;
        return (query: DwOffsetQuery(offset: current.items.length));
      case _OpKind.older || _OpKind.newer:
        throw StateError('unreachable: a feed has no window directions');
    }
  }

  @override
  void markReloading() {
    final current = data;
    if (current != null) {
      _emitData(
        DwPagedData(current.items, hasMore: current.hasMore),
        refreshing: true,
      );
    } else if (_state is! DwRequestUnreachable) {
      _emit(DwRequestLoading<DwPagedData<T>>());
    }
  }

  @override
  void markAppending(_Op target) {
    final current = data;
    if (current == null) return;
    _emitData(
      DwPagedData(current.items, hasMore: current.hasMore, loadingMore: true),
      refreshing: (_state as DwRequestData).refreshing,
    );
  }

  @override
  void markAppendDone(_Op target) {
    final current = data;
    if (current == null || !current.loadingMore) return;
    _emitData(DwPagedData(current.items, hasMore: current.hasMore));
  }

  @override
  void appendFailed(_Op target, Exception error) {
    final current = data;
    if (current == null) return;
    _emitData(
      DwPagedData(
        current.items,
        hasMore: current.hasMore,
        loadMoreError: error,
      ),
    );
  }

  @override
  void onResponse(_Op target, DwApiResponse response) {
    if (response is! DwApiOk) {
      _accumulated = null;
      finish(target, () => answerNotOk(target, response));
      return;
    }
    final DwPageResult<T> page;
    try {
      page = _typed.decodeResult(response.result, client.protocol);
    } catch (error, stackTrace) {
      _accumulated = null;
      undecodable(target, error, stackTrace);
      return;
    }
    switch (target.kind) {
      case _OpKind.reload:
        final merged = _merge(_accumulated, page.items);
        if (page.hasMore && merged.length < _target) {
          _accumulated = merged;
          sendCall(
            target,
            DwOffsetQuery(
              offset: merged.length,
              pageSize: _ask(_target - merged.length),
            ),
          );
          return;
        }
        _accumulated = null;
        final applied = _applyBuffered(merged, page.hasMore);
        final previous = data;
        final items = previous != null && dwListEquals(previous.items, applied)
            ? previous.items
            : applied;
        finish(target, () {
          dataSeq = target.seq;
          _emitData(DwPagedData(items, hasMore: page.hasMore));
        });
      case _OpKind.more:
        final current = data;
        if (current == null) {
          finish(target, () {});
          return;
        }
        final applied = _applyBuffered(
          _merge(current.items, page.items),
          page.hasMore,
        );
        finish(target, () {
          final seq = dataSeq;
          dataSeq = seq == null || target.seq < seq ? target.seq : seq;
          _emitData(DwPagedData(applied, hasMore: page.hasMore));
        });
      case _OpKind.older || _OpKind.newer:
        throw StateError('unreachable: a feed has no window directions');
    }
  }

  /// [page] appended to [loaded], skipping rows already loaded: an insert on
  /// the server shifts offset pages by one, and the shifted row must not
  /// appear twice.
  List<T> _merge(List<T>? loaded, List<T> page) {
    if (loaded == null) return page.toList();
    final ids = {for (final item in loaded) item.id};
    return loaded.toList()
      ..addAll(page.where((item) => !ids.contains(item.id)));
  }

  List<T> _applyBuffered(List<T> items, bool hasMore) {
    var result = items;
    for (final (object, action) in takeBuffer()) {
      switch (_apply(result, object, action, hasMore)) {
        case _Changed(value: final changed):
          result = changed! as List<T>;
        case _Refetch():
          reloadPending = true;
        case _Unchanged():
      }
    }
    return result;
  }

  _Outcome _apply(
    List<DwDataObject> items,
    DwWireObject object,
    DwUpdateAction action,
    bool hasMore,
  ) {
    if (action == DwUpdateAction.ignore) return _unchanged;
    if (action == DwUpdateAction.refetch) return _refetch;
    try {
      return _UpdateRules.items(
        this,
        items,
        object,
        action,
        sort: _UpdateRules._sortOf(request),
        dropPastEnd: hasMore,
      );
    } catch (error, stackTrace) {
      client._report(error, stackTrace);
      return _unchanged;
    }
  }

  @override
  bool applyLive(List<_Accepted> accepted) {
    final current = data;
    if (current == null) {
      return accepted.any((a) => a.$2 == DwUpdateAction.refetch);
    }
    List<DwDataObject> result = current.items;
    var refetch = false;
    for (final (object, action) in accepted) {
      switch (_apply(result, object, action, current.hasMore)) {
        case _Changed(value: final changed):
          result = changed! as List<DwDataObject>;
        case _Refetch():
          refetch = true;
        case _Unchanged():
      }
    }
    if (!identical(result, current.items)) {
      _emitData(
        DwPagedData(
          result as List<T>,
          hasMore: current.hasMore,
          loadingMore: current.loadingMore,
          loadMoreError: current.loadMoreError,
        ),
        refreshing: (_state as DwRequestData).refreshing,
      );
    }
    return refetch;
  }

  @override
  void syncLive() {
    final current = _state;
    final now = live;
    if (current is DwRequestData<DwPagedData<T>> && current.live != now) {
      _emit(
        DwRequestData(current.value, refreshing: current.refreshing, live: now),
      );
    }
  }

  @override
  void showRefusal(DwCallRefusal refusal) => _emit(DwRequestRefused(refusal));

  @override
  void showUnauthenticated() =>
      _emit(DwRequestUnauthenticated<DwPagedData<T>>());

  @override
  void showUnreachable() {
    if (data == null) _emit(DwRequestUnreachable<DwPagedData<T>>());
  }

  @override
  void failWith(String incidentId) => _emit(DwRequestFailed(incidentId));
}
