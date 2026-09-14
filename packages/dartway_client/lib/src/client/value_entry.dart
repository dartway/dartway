part of 'dw_app_client.dart';

/// The entry of a whole-value request: single, maybe, list, and one page of
/// a table.
final class _ValueEntry<R> extends _Entry {
  _ValueEntry(super.client, super.key);

  DwRequestState<R> _state = DwRequestLoading<R>();

  @override
  DwRequestState<Object?> get state => _state;

  DwDataRequest<R> get _typed => request as DwDataRequest<R>;

  void _emit(DwRequestState<R> next) {
    if (next == _state) return;
    _state = next;
    notifyWatches();
  }

  @override
  ({DwPageQuery? query})? queryFor(_Op target) => (query: null);

  @override
  void markReloading() {
    final current = _state;
    if (current is DwRequestData<R>) {
      _emit(DwRequestData<R>(current.value, refreshing: true, live: live));
    } else if (current is! DwRequestUnreachable<R>) {
      _emit(DwRequestLoading<R>());
    }
  }

  @override
  void onResponse(_Op target, DwApiResponse response) {
    if (response is! DwApiOk) {
      finish(target, () => answerNotOk(target, response));
      return;
    }
    R value;
    try {
      value = _typed.decodeResult(response.result, client.protocol);
    } catch (error, stackTrace) {
      undecodable(target, error, stackTrace);
      return;
    }
    for (final (object, action) in takeBuffer()) {
      switch (_applyToValue(value, object, action)) {
        case _Changed(value: final changed):
          value = changed as R;
        case _Refetch():
          reloadPending = true;
        case _Unchanged():
      }
    }
    final previous = _state;
    if (previous is DwRequestData<R> && _sameValue(previous.value, value)) {
      // Nobody watching is told about a change that is not one.
      value = previous.value;
    }
    finish(target, () {
      dataSeq = target.seq;
      _emit(DwRequestData<R>(value, live: live));
    });
  }

  @override
  bool applyLive(List<_Accepted> accepted) {
    final current = _state;
    if (current is! DwRequestData<R>) {
      // Nothing to merge into: only a request that asks to be run again acts;
      // an answer in flight absorbs the rest from the buffer.
      return accepted.any((a) => a.$2 == DwUpdateAction.refetch);
    }
    Object? value = current.value;
    var refetch = false;
    for (final (object, action) in accepted) {
      switch (_applyToValue(value, object, action)) {
        case _Changed(value: final changed):
          value = changed;
        case _Refetch():
          refetch = true;
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
    return refetch;
  }

  _Outcome _applyToValue(
    Object? value,
    DwWireObject object,
    DwUpdateAction action,
  ) {
    try {
      return _UpdateRules.applyToValue(this, value, object, action);
    } catch (error, stackTrace) {
      client._report(error, stackTrace);
      return _unchanged;
    }
  }

  @override
  void syncLive() {
    final current = _state;
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
  void showRefusal(DwCallRefusal refusal) =>
      _emit(DwRequestRefused<R>(refusal));

  @override
  void showUnauthenticated() => _emit(DwRequestUnauthenticated<R>());

  @override
  void showUnreachable() {
    if (_state is! DwRequestData<R>) _emit(DwRequestUnreachable<R>());
  }

  @override
  void failWith(String incidentId) => _emit(DwRequestFailed<R>(incidentId));
}

/// Whether two values of one request are equal in content, so the older
/// instance can be kept. Lists compare element-wise: generated DTOs compare
/// by value, lists by identity.
bool _sameValue(Object? a, Object? b) {
  if (identical(a, b)) return true;
  if (a is List && b is List) return dwListEquals(a, b);
  return a == b;
}

/// The entry of one numbered page of a table: a whole value, whose item type
/// it knows so a changed page keeps it.
final class _TableEntry<T extends DwDataObject>
    extends _ValueEntry<DwTablePage<T>> {
  _TableEntry(super.client, super.key);

  /// [page] with [items] — `DwTablePage<T>`, not `DwTablePage<DwDataObject>`.
  DwTablePage<T> withItems(DwTablePage page, List<DwDataObject> items) =>
      DwTablePage<T>(
        items is List<T> ? items : List<T>.from(items),
        total: page.total,
        page: page.page,
        pageSize: page.pageSize,
      );
}
