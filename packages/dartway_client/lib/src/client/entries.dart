part of 'dw_app_client.dart';

enum _OpKind {
  /// Load the entry from scratch (the first load, a refetch, a re-run).
  reload,

  /// The next offset page of a feed.
  more,

  /// Rows older than a window's last row.
  older,

  /// Rows newer than a window's first row.
  newer,
}

/// One operation of an entry: possibly several calls (a reload of many
/// loaded pages), one at a time.
final class _Op {
  _Op(this.kind);

  final _OpKind kind;

  /// Whether a call went out. An operation waits unsent while the entry's
  /// subscriptions are being made.
  bool sent = false;

  /// The live activation sequence when the operation was sent: data it
  /// produces may have missed updates published before any later
  /// activation.
  int seq = 0;

  final Completer<void> done = Completer<void>();
}

/// An object an entry accepted, with the action its request chose.
typedef _Accepted = (DwWireObject object, DwUpdateAction action);

/// The live state of one request for one account, shared by every watch of
/// an equal request.
///
/// An entry runs **one operation at a time**. A reload asked for while one is
/// in flight is remembered once and started when it ends, so any number of
/// refetch triggers cost at most one call in flight plus one after it.
///
/// Updates that arrive while an operation is in flight are applied to what
/// is shown *and* kept in [buffer], then applied again to the answer: the
/// server may have read the data before the update was committed, and an
/// answer must never erase an update that arrived before it. Every action is
/// idempotent (replace by id, remove by id, insert only when absent), so
/// applying an update the answer already contains changes nothing.
sealed class _Entry {
  _Entry(this.client, this.key) : request = key.$2 {
    DwCallRefusal? refusal;
    try {
      refusal = client._localRefusal(request);
    } catch (error, stackTrace) {
      // A throwing validate() is the DTO's bug: reported, and the entry shows
      // a failure instead of pretending the request is valid.
      client._report(error, stackTrace);
      invalid = true;
    }
    localRefusal = refusal;
    channels = localRefusal != null || invalid
        // Nothing will ever be fetched, so nothing is worth subscribing to.
        ? const []
        : List.unmodifiable({
            for (final channel in request.channels) channel.wireName,
          });
  }

  final DwAppClient client;
  final _EntryKey key;
  final DwDataRequest<Object?> request;

  /// The first refusal of a request that does not validate. A request is a
  /// value, so this is decided once: such an entry shows the refusal and
  /// never sends anything.
  late final DwCallRefusal? localRefusal;

  /// Whether validating the request threw.
  bool invalid = false;

  /// Wire names of the channels the request declares, without repeats.
  late final List<String> channels;

  final Set<_Watch<Object?>> watches = {};
  Timer? releaseTimer;
  bool disposed = false;

  /// The operation in flight or waiting to be sent.
  _Op? op;

  bool reloadPending = false;

  /// Waiters of the reload in flight, and of the one after it.
  List<Completer<void>> reloadWaiters = [];
  List<Completer<void>> nextReloadWaiters = [];

  /// Objects accepted while the sent operation is in flight.
  List<_Accepted>? buffer;

  /// Waiting for subscriptions before sending [op].
  Timer? settleTimer;

  /// The activation sequence of the oldest call behind the data shown;
  /// `null` while there is no data.
  int? dataSeq;

  /// The state as the entry holds it; watches retype it.
  DwRequestState<Object?> get state;

  bool get live => client._isLive(this);

  // --- lifecycle -------------------------------------------------------------

  void retain(_Watch<Object?> watch) {
    watches.add(watch);
    releaseTimer?.cancel();
    releaseTimer = null;
  }

  /// Starts the first load.
  void begin() => unawaited(reload());

  void dispose() {
    disposed = true;
    releaseTimer?.cancel();
    releaseTimer = null;
    settleTimer?.cancel();
    settleTimer = null;
    final pending = op;
    op = null;
    buffer = null;
    if (pending != null && !pending.done.isCompleted) pending.done.complete();
    for (final waiter in [...reloadWaiters, ...nextReloadWaiters]) {
      if (!waiter.isCompleted) waiter.complete();
    }
    reloadWaiters = [];
    nextReloadWaiters = [];
    for (final pendingAppend in pendingAppends()) {
      if (!pendingAppend.done.isCompleted) pendingAppend.done.complete();
    }
    watches.clear();
  }

  void notifyWatches() {
    for (final watch in watches.toList()) {
      watch._notify();
    }
  }

  // --- operations ----------------------------------------------------------

  /// Loads the entry again; completes when a reload that started after this
  /// call has been answered. Coalesced with every other trigger.
  Future<void> reload() {
    if (disposed) return Future.value();
    final waiter = Completer<void>();
    final current = op;
    if (current == null) {
      reloadWaiters.add(waiter);
      start(_Op(_OpKind.reload));
    } else if (current.kind == _OpKind.reload && !current.sent) {
      // Not sent yet: its answer is as fresh as the one asked for.
      reloadWaiters.add(waiter);
    } else {
      reloadPending = true;
      nextReloadWaiters.add(waiter);
    }
    return waiter.future;
  }

  /// Starts [next] as the operation of the entry.
  void start(_Op next) {
    op = next;
    if (invalid) {
      finish(next, () => failWith(dwClientIncidentId));
      return;
    }
    if (localRefusal case final refusal?) {
      finish(next, () => refuse(next, refusal));
      return;
    }
    if (client._incompatibility.value case final refusal?) {
      finish(next, () => refuse(next, refusal));
      return;
    }
    if (next.kind == _OpKind.reload) {
      markReloading();
    } else {
      markAppending(next);
    }
    if (client._liveSettling(this)) {
      settleTimer = Timer(client.options.liveSettleTimeout, () {
        settleTimer = null;
        send(next);
      });
      return;
    }
    send(next);
  }

  /// Sends [target] if it is still the entry's operation and unsent.
  void send(_Op target) {
    settleTimer?.cancel();
    settleTimer = null;
    if (disposed || op != target || target.sent) return;
    final query = queryFor(target);
    if (query == null && target.kind != _OpKind.reload) {
      // Nothing left in that direction (the data changed while it waited).
      finish(target, () => markAppendDone(target));
      return;
    }
    target
      ..sent = true
      ..seq = client._live.activationSeq;
    buffer = [];
    sendCall(target, query?.query);
  }

  /// Sends one call of [target] with [query].
  void sendCall(_Op target, DwPageQuery? query) {
    final _Call call;
    try {
      call = client._newCall(
        request,
        query,
        timeout: target.kind == _OpKind.reload
            ? null
            : client.options.callTimeout,
      );
    } catch (error, stackTrace) {
      // The request does not encode: nothing to wait for.
      client._report(error, stackTrace);
      finish(target, () => fail(target, dwClientIncidentId));
      return;
    }
    client
        ._send(
          call,
          cancelled: () => disposed || op != target,
          onUnreachable: target.kind == _OpKind.reload
              ? () {
                  if (!disposed && op == target) showUnreachable();
                }
              : null,
        )
        .then((outcome) {
          if (disposed || op != target) return;
          switch (outcome) {
            case _Aborted():
              return;
            case _TimedOut(:final lastError):
              finish(
                target,
                () => appendFailed(
                  target,
                  DwTimeoutException(
                    call.wireName,
                    client.options.callTimeout,
                    lastError: lastError,
                  ),
                ),
              );
            case _Unreadable(:final exception, :final stackTrace):
              client._report(exception, stackTrace);
              finish(target, () {
                if (target.kind == _OpKind.reload) {
                  failWith(dwClientIncidentId);
                } else {
                  appendFailed(target, exception);
                }
              });
            case _Answered(:final response):
              onResponse(target, response);
          }
        });
  }

  /// Ends [target]: runs [effect] (the state it leaves), completes its
  /// waiters, and starts what waited behind it.
  void finish(_Op target, void Function() effect) {
    if (op == target) op = null;
    buffer = null;
    settleTimer?.cancel();
    settleTimer = null;
    effect();
    if (!target.done.isCompleted) target.done.complete();
    if (target.kind == _OpKind.reload) {
      final done = reloadWaiters;
      reloadWaiters = [];
      for (final waiter in done) {
        if (!waiter.isCompleted) waiter.complete();
      }
    }
    if (disposed || op != null) return;
    if (reloadPending) {
      reloadPending = false;
      reloadWaiters = nextReloadWaiters;
      nextReloadWaiters = [];
      start(_Op(_OpKind.reload));
      return;
    }
    final next = takePendingAppend();
    if (next != null) start(next);
  }

  /// Takes and returns the accepted objects buffered for the operation now
  /// being answered.
  List<_Accepted> takeBuffer() {
    final taken = buffer ?? const <_Accepted>[];
    buffer = null;
    return taken;
  }

  /// Ends [target] with a refusal: the state of a reload, the load error of
  /// an append.
  void refuse(_Op target, DwCallRefusal refusal) {
    if (target.kind == _OpKind.reload) {
      dataSeq = null;
      showRefusal(refusal);
    } else {
      appendFailed(target, DwRefusalException(refusal));
    }
  }

  void fail(_Op target, String incidentId) {
    if (target.kind == _OpKind.reload) {
      dataSeq = null;
      failWith(incidentId);
    } else {
      appendFailed(
        target,
        DwFailedException(incidentId, call: request.dwTypeName),
      );
    }
  }

  /// The state a non-ok response to [target] leaves.
  void answerNotOk(_Op target, DwApiResponse response) {
    switch (response) {
      case DwApiRefused(:final refusal) || DwApiIncompatible(:final refusal):
        refuse(target, refusal);
      case DwApiUnauthenticated():
        if (target.kind == _OpKind.reload) {
          dataSeq = null;
          showUnauthenticated();
        } else {
          appendFailed(
            target,
            DwNotAuthenticatedException(call: request.dwTypeName),
          );
        }
      case DwApiFailed(:final incidentId):
        fail(target, incidentId);
      case DwApiOk():
        throw StateError('unreachable: ok is answered by the entry');
    }
  }

  /// Reports a DTO that does not decode and ends [target] with the failure.
  void undecodable(_Op target, Object error, StackTrace stackTrace) {
    final exception = DwProtocolException(
      'Cannot decode the result of ${request.dwTypeName}',
      error,
    );
    client._report(exception, stackTrace);
    finish(target, () {
      if (target.kind == _OpKind.reload) {
        dataSeq = null;
        failWith(dwClientIncidentId);
      } else {
        appendFailed(target, exception);
      }
    });
  }

  // --- updates -------------------------------------------------------------

  /// Offers the objects of one transport: takes those the request accepts,
  /// asks the request what each does, and applies them.
  void absorb(List<DwWireObject> objects) {
    if (disposed) return;
    final protocol = client.protocol;
    final accepted = <_Accepted>[];
    for (final object in objects) {
      final concerns = switch (object) {
        DwDeletedObject() => request.acceptsDeletion(object, protocol),
        _ => request.acceptsItem(object),
      };
      if (!concerns) continue;
      final DwUpdateAction action;
      try {
        action = request.onUpdate(object);
      } catch (error, stackTrace) {
        // One bad update must not stop the rest.
        client._report(error, stackTrace);
        continue;
      }
      if (action != DwUpdateAction.ignore) accepted.add((object, action));
    }
    if (accepted.isEmpty) return;
    if (op?.sent ?? false) buffer?.addAll(accepted);
    if (applyLive(accepted)) unawaited(reload());
  }

  /// Applies [accepted] to the data shown; returns whether the request asks
  /// to be run again.
  bool applyLive(List<_Accepted> accepted);

  /// A misused action (inserting a deletion) is reported, not applied.
  void misuse(DwWireObject object, DwUpdateAction action, String why) {
    client._report(
      StateError(
        '${request.dwTypeName}.onUpdate answered ${action.name} for '
        '$object, and $why. The update was not applied.',
      ),
      StackTrace.current,
    );
  }

  // --- live ----------------------------------------------------------------

  /// A channel of this entry became active with activation [seq]. Data asked
  /// for before may have missed what was published until then.
  void onChannelActivated(int seq) {
    final current = op;
    final staleData = dataSeq != null && dataSeq! < seq;
    final staleCall = current != null && current.sent && current.seq < seq;
    if (staleData || staleCall) unawaited(reload());
    onLiveChanged();
  }

  /// The socket or a subscription changed: show whether the data is live,
  /// and send an operation that waited for subscriptions once they settled.
  void onLiveChanged() {
    if (disposed) return;
    syncLive();
    final current = op;
    if (current != null &&
        !current.sent &&
        settleTimer != null &&
        !client._liveSettling(this)) {
      send(current);
    }
  }

  // --- the kind's part -----------------------------------------------------

  /// The page query of [target]; `null` for a reload of a kind without one.
  /// For an append, `null` means there is nothing to load.
  ({DwPageQuery? query})? queryFor(_Op target);

  void onResponse(_Op target, DwApiResponse response);

  void markReloading();
  void markAppending(_Op target) {}
  void markAppendDone(_Op target) {}
  void appendFailed(_Op target, Exception error) {}
  Iterable<_Op> pendingAppends() => const [];
  _Op? takePendingAppend() => null;

  void showRefusal(DwCallRefusal refusal);
  void showUnauthenticated();
  void showUnreachable();
  void failWith(String incidentId);
  void syncLive();
}
