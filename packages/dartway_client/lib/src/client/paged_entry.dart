part of 'dw_client.dart';

enum _PageOp { none, first, more }

/// The entry of a paginated request: loaded pages merged into one list.
///
/// Its operations are "load from the top" ([run]) — which re-fetches as many
/// pages as were loaded, page by page, and swaps the list once all have
/// arrived — and "load the next page" ([loadMore]).
final class _PagedEntry<T extends DwDataObject> extends _Entry {
  _PagedEntry(super.client, DwRequest<DwPage<T>> super.request);

  DwRequestState<DwPagedData<T>> state = DwRequestLoading<DwPagedData<T>>();
  final Set<DwPagedWatch<DwDataObject>> handles = {};

  _PageOp op = _PageOp.none;

  /// Pages of a running [run], merged so far.
  List<T>? accumulated;

  /// How many items [run] loads before it stops: as many as were loaded.
  int target = 0;

  DwRequest<DwPage<T>> get _typed => request as DwRequest<DwPage<T>>;

  bool get _isCursor => request is DwCursorRequest;

  DwPagedData<T>? get data => switch (state) {
    DwRequestData(:final value) => value,
    _ => null,
  };

  /// The next page after [loaded]: an offset of the loaded count, or a cursor
  /// at the oldest loaded object.
  DwPageParams _after(List<T> loaded) => _isCursor
      ? DwCursorParams(loaded.isEmpty ? null : loaded.last.id)
      : DwOffsetParams(loaded.length);

  void _emit(DwRequestState<DwPagedData<T>> next) {
    if (next == state) return;
    state = next;
    for (final handle in handles.toList()) {
      handle._emit(next);
    }
  }

  void _emitData(DwPagedData<T> value, {bool refreshing = false}) =>
      _emit(DwRequestData(value, refreshing: refreshing, live: live));

  @override
  void run() {
    buffer = [];
    final current = data;
    target = current?.items.length ?? 0;
    if (current != null) {
      _emitData(
        DwPagedData(current.items, hasMore: current.hasMore),
        refreshing: true,
      );
    } else {
      _emit(DwRequestLoading<DwPagedData<T>>());
    }
    accumulated = null;
    op = _PageOp.first;
    send(_isCursor ? const DwCursorParams(null) : const DwOffsetParams(0));
  }

  Future<void> loadMore() {
    final current = data;
    if (disposed || current == null || !current.hasMore) return Future.value();
    final waiter = Completer<void>();
    currentWaiters.add(waiter);
    // Idempotent while anything is in flight: the caller waits for it.
    if (inFlight != null) return waiter.future;
    buffer = [];
    op = _PageOp.more;
    _emitData(DwPagedData(current.items, hasMore: true, loadingMore: true));
    send(_after(current.items));
    return waiter.future;
  }

  @override
  void onResult(DwResultMessage message, _Call call) {
    if (inFlight != call || disposed) return;
    inFlight = null;
    switch (op) {
      case _PageOp.first:
        _onFirst(message, call);
      case _PageOp.more:
        _onMore(message, call);
      case _PageOp.none:
        return;
    }
  }

  DwPage<T>? _decode(DwResultMessage message) {
    try {
      return _typed.decodeResult(message.value, client.protocol);
    } catch (error, stackTrace) {
      client._report(
        DwProtocolException(
          'Cannot decode a page of ${request.dwTypeName}',
          error,
        ),
        stackTrace,
      );
      return null;
    }
  }

  void _onFirst(DwResultMessage message, _Call call) {
    if (message.status == DwResultStatus.ok) {
      final page = _decode(message);
      if (page != null) {
        final merged = _merge(accumulated, page.items);
        if (page.hasMore && merged.length < target) {
          accumulated = merged;
          send(_after(merged));
          return;
        }
        accumulated = null;
        op = _PageOp.none;
        fetched = true;
        fetchedAs = call.sentAccount;
        final applied = _applyBuffer(merged, page.hasMore);
        final previous = data;
        final items = previous != null && dwListEquals(previous.items, applied)
            ? previous.items
            : applied;
        _emitData(DwPagedData(items, hasMore: page.hasMore));
        finishOperation();
        return;
      }
    }
    accumulated = null;
    op = _PageOp.none;
    buffer = null;
    fetched = true;
    fetchedAs = call.sentAccount;
    switch (message.status) {
      case DwResultStatus.ok:
        failWith(dwClientIncidentId);
      case DwResultStatus.refused:
        _emit(
          DwRequestRefused(
            message.refusal ?? DwRefusal(DwCoreRefusal.forbidden),
          ),
        );
      case DwResultStatus.unauthenticated:
        fetchedAs = null;
        _emit(DwRequestUnauthenticated<DwPagedData<T>>());
        client._onNotAuthenticated(call);
      case DwResultStatus.failed:
        failWith(message.incidentId ?? '');
    }
    finishOperation();
  }

  void _onMore(DwResultMessage message, _Call call) {
    op = _PageOp.none;
    final current = data;
    if (current == null) {
      buffer = null;
      finishOperation();
      return;
    }
    Exception? error;
    switch (message.status) {
      case DwResultStatus.ok:
        final page = _decode(message);
        if (page != null) {
          final applied = _applyBuffer(
            _merge(current.items, page.items),
            page.hasMore,
          );
          _emitData(DwPagedData(applied, hasMore: page.hasMore));
          finishOperation();
          return;
        }
        error = DwProtocolException(
          'Cannot decode a page of ${request.dwTypeName}',
        );
      case DwResultStatus.refused:
        error = DwRefusalException(
          message.refusal ?? DwRefusal(DwCoreRefusal.forbidden),
        );
      case DwResultStatus.unauthenticated:
        error = DwNotAuthenticatedException(call: request.dwTypeName);
      case DwResultStatus.failed:
        error = DwFailedException(
          message.incidentId ?? '',
          call: request.dwTypeName,
        );
    }
    buffer = null;
    _emitData(
      DwPagedData(
        current.items,
        hasMore: current.hasMore,
        loadMoreError: error,
      ),
    );
    if (message.status == DwResultStatus.unauthenticated) {
      client._onNotAuthenticated(call);
    }
    finishOperation();
  }

  /// [page] appended to [loaded], skipping objects already loaded: an insert
  /// on the server shifts offset pages by one, and the shifted object must
  /// not appear twice.
  List<T> _merge(List<T>? loaded, List<T> page) {
    if (loaded == null) return page.toList();
    final ids = {for (final item in loaded) item.id};
    return loaded.toList()
      ..addAll(page.where((item) => !ids.contains(item.id)));
  }

  List<T> _applyBuffer(List<T> items, bool hasMore) {
    final buffered = buffer ?? const <DwDto>[];
    buffer = null;
    var result = items;
    for (final item in buffered) {
      switch (guarded(
        () => client._rules.applyToPages(request, result, hasMore, item),
      )) {
        case _Changed(value: final changed):
          result = changed! as List<T>;
        case _Refetch():
          rerunPending = true;
        case _Unchanged():
      }
    }
    return result;
  }

  @override
  void failWith(String incidentId) => _emit(DwRequestFailed(incidentId));

  @override
  void onAbort(Object error, StackTrace stackTrace, _Call call) {
    if (inFlight != call || disposed) return;
    if (op == _PageOp.more) {
      inFlight = null;
      buffer = null;
      op = _PageOp.none;
      final current = data;
      if (current != null) {
        _emitData(
          DwPagedData(
            current.items,
            hasMore: current.hasMore,
            loadMoreError: error is Exception
                ? error
                : DwProtocolException('$error'),
          ),
        );
      }
      finishOperation();
      return;
    }
    accumulated = null;
    op = _PageOp.none;
    super.onAbort(error, stackTrace, call);
  }

  @override
  void applyItems(List<DwDto> items) {
    if (disposed) return;
    buffer?.addAll(items);
    final current = data;
    if (current == null) {
      if (inFlight == null && items.any(wantsRefetch)) unawaited(refetch());
      return;
    }
    List<DwDataObject> result = current.items;
    var refetchWanted = false;
    for (final item in items) {
      switch (guarded(
        () =>
            client._rules.applyToPages(request, result, current.hasMore, item),
      )) {
        case _Changed(value: final changed):
          result = changed! as List<DwDataObject>;
        case _Refetch():
          refetchWanted = true;
        case _Unchanged():
      }
    }
    if (!identical(result, current.items)) {
      final refreshing = (state as DwRequestData).refreshing;
      _emitData(
        DwPagedData(
          result as List<T>,
          hasMore: current.hasMore,
          loadingMore: current.loadingMore,
          loadMoreError: current.loadMoreError,
        ),
        refreshing: refreshing,
      );
    }
    if (refetchWanted) unawaited(refetch());
  }

  @override
  void syncLive() {
    final current = state;
    final now = live;
    if (current is DwRequestData<DwPagedData<T>> && current.live != now) {
      _emit(
        DwRequestData(current.value, refreshing: current.refreshing, live: now),
      );
    }
  }

  @override
  void onReady({required bool newConnection, required int? account}) {
    final call = inFlight;
    if (call != null) {
      if (call.generation == client._generation) {
        if (call.sentAccount != account) rerunPending = true;
      } else if (op == _PageOp.first && accumulated == null) {
        // The first page, never answered: sending it now is the re-run.
        client._write(call);
      } else {
        // Part of the list was loaded before the connection dropped and may
        // have missed updates since: abandon the call and load from the top.
        client._pending.remove(call.id);
        inFlight = null;
        accumulated = null;
        op = _PageOp.none;
        buffer = null;
        run();
      }
    } else if (newConnection || !fetched || fetchedAs != account) {
      run();
    }
    syncLive();
  }

  @override
  void closeHandles() {
    for (final handle in handles.toList()) {
      handle._closeFromEntry();
    }
    handles.clear();
  }
}
