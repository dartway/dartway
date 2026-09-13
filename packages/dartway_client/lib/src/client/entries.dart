part of 'dw_client.dart';

/// The live state of one request, shared by every watch of an equal request.
///
/// An entry runs **one operation at a time**. A re-run asked for while one is
/// in flight is remembered once (`rerunPending`) and started when it ends, so
/// any number of refetch triggers cost at most one call in flight plus one
/// after it.
///
/// Updates that arrive while an operation is in flight are applied to what is
/// shown *and* kept in [buffer], then applied again to the answer: the server
/// may have computed the answer before the update was committed, and an
/// answer must never erase an update that arrived before it. Every rule is
/// idempotent (replace by id, remove by id, insert only when absent), so
/// applying an update the answer already contains changes nothing.
sealed class _Entry {
  _Entry(DwClient client, DwRequest<Object?> request)
    : this._(client, request, client._localRefusal(request));

  _Entry._(this.client, this.request, this.localRefusal)
    : channels = localRefusal != null
          // Nothing will ever be fetched, so nothing is worth subscribing to.
          ? const []
          : List.unmodifiable({
              for (final channel in request.channels) channel.wireName,
            });

  final DwClient client;
  final DwRequest<Object?> request;

  /// The first refusal of a request that does not validate. A request is a
  /// value, so this is decided once: such an entry shows the refusal and
  /// never sends anything, reconnects included.
  final DwRefusal? localRefusal;

  /// Wire names of the channels the request declares, without repeats.
  final List<String> channels;

  int watchers = 0;
  Timer? releaseTimer;
  bool disposed = false;

  _Call? inFlight;
  bool rerunPending = false;
  List<DwDto>? buffer;

  /// Whether an operation has completed, and under which account its calls
  /// went out.
  bool fetched = false;
  int? fetchedAs;

  List<Completer<void>> currentWaiters = [];
  List<Completer<void>> nextWaiters = [];

  /// Whether updates reach this entry right now.
  bool get live =>
      channels.isNotEmpty &&
      client._ready &&
      channels.every(
        (name) => client._channels[name]?.state == _SubState.active,
      );

  /// Starts the operation that loads the entry from scratch.
  void run();

  /// Ends an operation without a call when none can be made: the request does
  /// not validate, or the server speaks another wire version. Returns whether
  /// it did.
  bool settledWithoutCall() {
    final refusal = localRefusal;
    if (refusal != null) {
      fetched = true;
      fetchedAs = client._connectionAccount;
      showRefusal(refusal);
    } else if (client._incompatible != null) {
      // Reported once, when the client learned it.
      failWith(dwClientIncidentId);
    } else {
      return false;
    }
    buffer = null;
    finishOperation();
    return true;
  }

  void showRefusal(DwRefusal refusal);

  void applyItems(List<DwDto> items);

  /// Emits the current data again when [live] no longer matches it.
  void syncLive();

  void closeHandles();

  /// The connection is authenticated (again): re-send what is unanswered and
  /// re-run what may be stale.
  void onReady({required bool newConnection, required int? account});

  Future<void> refetch() {
    if (disposed) return Future.value();
    final waiter = Completer<void>();
    if (inFlight != null) {
      rerunPending = true;
      nextWaiters.add(waiter);
    } else {
      currentWaiters.add(waiter);
      run();
    }
    return waiter.future;
  }

  _Call? send(DwPageParams? page) {
    try {
      return inFlight = client._enqueue(
        (id) => DwRequestMessage(id: id, request: request, page: page),
        entry: this,
        onResult: onResult,
        onAbort: onAbort,
      );
    } catch (error, stackTrace) {
      // The request itself does not encode: nothing to wait for.
      client._report(error, stackTrace);
      inFlight = null;
      buffer = null;
      failWith(dwClientIncidentId);
      finishOperation();
      return null;
    }
  }

  void onResult(DwResultMessage message, _Call call);

  void failWith(String incidentId);

  void onAbort(Object error, StackTrace stackTrace, _Call call) {
    if (inFlight != call || disposed) return;
    inFlight = null;
    buffer = null;
    failWith(dwClientIncidentId);
    finishOperation();
  }

  void finishOperation() {
    final done = currentWaiters;
    currentWaiters = [];
    for (final waiter in done) {
      waiter.complete();
    }
    if (rerunPending && !disposed) {
      rerunPending = false;
      currentWaiters = nextWaiters;
      nextWaiters = [];
      run();
    }
  }

  /// Applies [item] through [apply], reporting a throwing `onUpdate` (or a
  /// misuse the rules detect) instead of letting one bad update stop the rest.
  _Outcome guarded(_Outcome Function() apply) {
    try {
      return apply();
    } catch (error, stackTrace) {
      client._report(error, stackTrace);
      return _unchanged;
    }
  }

  bool wantsRefetch(DwDto item) =>
      guarded(
            () => request.onUpdate(item) == DwUpdate.refetch
                ? _refetch
                : _unchanged,
          )
          is _Refetch;

  void dispose() {
    disposed = true;
    releaseTimer?.cancel();
    releaseTimer = null;
    final call = inFlight;
    inFlight = null;
    if (call != null) client._pending.remove(call.id);
    closeHandles();
    for (final waiter in [...currentWaiters, ...nextWaiters]) {
      waiter.complete();
    }
    currentWaiters = [];
    nextWaiters = [];
  }
}

/// The entry of a whole-value request: single, maybe, list.
final class _RequestEntry<R> extends _Entry {
  _RequestEntry(super.client, DwRequest<R> super.request);

  DwRequestState<R> state = DwRequestLoading<R>();
  final Set<DwWatch<Object?>> handles = {};

  DwRequest<R> get _typed => request as DwRequest<R>;

  void _emit(DwRequestState<R> next) {
    if (next == state) return;
    state = next;
    for (final handle in handles.toList()) {
      handle._emit(next);
    }
  }

  @override
  void run() {
    if (settledWithoutCall()) return;
    buffer = [];
    final current = state;
    if (current is DwRequestData<R>) {
      _emit(
        DwRequestData<R>(current.value, refreshing: true, live: current.live),
      );
    } else {
      _emit(DwRequestLoading<R>());
    }
    send(null);
  }

  @override
  void onResult(DwResultMessage message, _Call call) {
    if (inFlight != call || disposed) return;
    inFlight = null;
    final buffered = buffer ?? const <DwDto>[];
    buffer = null;
    fetched = true;
    fetchedAs = call.sentAccount;

    switch (message.status) {
      case DwResultStatus.ok:
        R value;
        try {
          value = _typed.decodeResult(message.value, client.protocol);
        } catch (error, stackTrace) {
          client._report(
            DwProtocolException(
              'Cannot decode the result of ${request.dwTypeName}',
              error,
            ),
            stackTrace,
          );
          failWith(dwClientIncidentId);
          break;
        }
        for (final item in buffered) {
          switch (guarded(
            () => client._rules.applyToValue(request, value, item),
          )) {
            case _Changed(value: final changed):
              value = changed as R;
            case _Refetch():
              rerunPending = true;
            case _Unchanged():
          }
        }
        final previous = state;
        if (previous is DwRequestData<R> && _sameValue(previous.value, value)) {
          value = previous.value;
        }
        _emit(DwRequestData<R>(value, live: live));
      case DwResultStatus.refused:
        _emit(
          DwRequestRefused<R>(
            message.refusal ?? DwRefusal(DwCoreRefusal.forbidden),
          ),
        );
      case DwResultStatus.unauthenticated:
        // The server served it anonymously; nothing is stale when the account
        // becomes null.
        fetchedAs = null;
        _emit(DwRequestUnauthenticated<R>());
      case DwResultStatus.failed:
        failWith(message.incidentId ?? '');
    }
    if (message.status == DwResultStatus.unauthenticated) {
      client._onNotAuthenticated(call);
    }
    finishOperation();
  }

  @override
  void failWith(String incidentId) => _emit(DwRequestFailed<R>(incidentId));

  @override
  void showRefusal(DwRefusal refusal) => _emit(DwRequestRefused<R>(refusal));

  @override
  void applyItems(List<DwDto> items) {
    if (disposed) return;
    buffer?.addAll(items);
    final current = state;
    if (current is! DwRequestData<R>) {
      // Nothing to merge into. Only a request that asks to be re-run acts;
      // an answer in flight will absorb the rest from the buffer.
      if (inFlight == null && items.any(wantsRefetch)) unawaited(refetch());
      return;
    }
    Object? value = current.value;
    var refetchWanted = false;
    for (final item in items) {
      switch (guarded(() => client._rules.applyToValue(request, value, item))) {
        case _Changed(value: final changed):
          value = changed;
        case _Refetch():
          refetchWanted = true;
        case _Unchanged():
      }
    }
    if (!identical(value, current.value)) {
      _emit(
        DwRequestData<R>(
          value as R,
          refreshing: current.refreshing,
          live: current.live,
        ),
      );
    }
    if (refetchWanted) unawaited(refetch());
  }

  @override
  void syncLive() {
    final current = state;
    final now = live;
    if (current is DwRequestData<R> && current.live != now) {
      _emit(
        DwRequestData<R>(
          current.value,
          refreshing: current.refreshing,
          live: now,
        ),
      );
    }
  }

  @override
  void onReady({required bool newConnection, required int? account}) {
    final call = inFlight;
    if (call != null) {
      if (call.generation != client._generation) {
        // Queued, or lost with the previous connection: send it now, under the
        // current account. Its answer is as fresh as a re-run.
        client._write(call);
      } else if (call.sentAccount != account) {
        // Sent on this connection for the previous account.
        rerunPending = true;
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
