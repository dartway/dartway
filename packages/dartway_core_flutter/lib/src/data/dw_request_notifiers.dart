import 'dart:async';

import 'package:dartway_client/dartway_client.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// What `dw.request(request)` returns.
typedef DwRequestProvider<R> =
    NotifierProvider<DwRequestNotifier<R>, AsyncValue<R>>;

/// What `dw.pages(request)` returns.
typedef DwPagesProvider<T extends DwDataObject> =
    NotifierProvider<DwPagesNotifier<T>, AsyncValue<DwPagedData<T>>>;

/// What `dw.table(request)` returns.
typedef DwTableProvider<T extends DwDataObject> =
    NotifierProvider<DwTableNotifier<T>, AsyncValue<DwTablePage<T>>>;

/// What `dw.window(request)` returns.
typedef DwWindowProvider<T extends DwDataObject> =
    NotifierProvider<DwWindowNotifier<T>, AsyncValue<DwWindowData<T>>>;

/// What `dw.accountId`, `dw.liveStatus` and `dw.incompatibility` return: a
/// value to watch, with nothing to call.
typedef DwValueProvider<T> = NotifierProvider<Notifier<T>, T>;

/// The Riverpod face of a client watch: one watch for as long as the provider
/// is listened to, its states as `AsyncValue`s.
///
/// Riverpod shares one notifier per provider per container, and the client
/// shares one entry per equal request across all of them — so two screens,
/// two containers or a rebuilt provider never cost a second fetch or
/// subscription. An account switch needs nothing here: the client moves the
/// watch to the next account's entry, and the value goes through loading
/// rather than ever showing the previous account's data.
abstract base class _DwWatchNotifier<S, W> extends Notifier<AsyncValue<S>> {
  _DwWatchNotifier(this._client, this._call, this._onDispose);

  final DwAppClient _client;
  final String _call;
  final void Function()? _onDispose;

  W? _watch;

  W _open();
  DwRequestState<S> _stateOf(W watch);
  Stream<DwRequestState<S>> _statesOf(W watch);
  void _close(W watch);

  @override
  AsyncValue<S> build() {
    final watch = _open();
    _watch = watch;
    final mapper = _DwAsyncMapper<S>(_call, _client.options.callTimeout);
    // The first event replays the current state; the mapper answers it with
    // the same AsyncValue, which Riverpod does not notify about.
    final subscription = _statesOf(
      watch,
    ).listen((next) => state = mapper.map(next));
    ref.onDispose(() {
      unawaited(subscription.cancel());
      _close(watch);
      _onDispose?.call();
    });
    return mapper.map(_stateOf(watch));
  }
}

/// The Riverpod face of a [DwRequestWatch]: a single, maybe or list request.
final class DwRequestNotifier<R>
    extends _DwWatchNotifier<R, DwRequestWatch<R>> {
  DwRequestNotifier(
    DwAppClient client,
    this.request, {
    void Function()? onDispose,
  }) : super(client, request.dwTypeName, onDispose);

  final DwDataRequest<R> request;

  @override
  DwRequestWatch<R> _open() => _client.watch(request);

  @override
  DwRequestState<R> _stateOf(DwRequestWatch<R> watch) => watch.state;

  @override
  Stream<DwRequestState<R>> _statesOf(DwRequestWatch<R> watch) => watch.states;

  @override
  void _close(DwRequestWatch<R> watch) => watch.close();

  /// Runs the request again (pull to refresh); completes when answered.
  Future<void> refetch() => _watch?.refetch() ?? Future.value();

  /// Whether the data shown follows the server live.
  bool get isLive => _watch?.isLive ?? false;
}

/// The Riverpod face of one numbered page of a table.
final class DwTableNotifier<T extends DwDataObject>
    extends _DwWatchNotifier<DwTablePage<T>, DwRequestWatch<DwTablePage<T>>> {
  DwTableNotifier(
    DwAppClient client,
    this.request, {
    void Function()? onDispose,
  }) : super(client, request.dwTypeName, onDispose);

  final DwTableRequest<T> request;

  @override
  DwRequestWatch<DwTablePage<T>> _open() => _client.watchTable(request);

  @override
  DwRequestState<DwTablePage<T>> _stateOf(
    DwRequestWatch<DwTablePage<T>> watch,
  ) => watch.state;

  @override
  Stream<DwRequestState<DwTablePage<T>>> _statesOf(
    DwRequestWatch<DwTablePage<T>> watch,
  ) => watch.states;

  @override
  void _close(DwRequestWatch<DwTablePage<T>> watch) => watch.close();

  /// Reads the page again.
  Future<void> refetch() => _watch?.refetch() ?? Future.value();

  bool get isLive => _watch?.isLive ?? false;
}

/// The Riverpod face of a [DwPagesWatch].
final class DwPagesNotifier<T extends DwDataObject>
    extends _DwWatchNotifier<DwPagedData<T>, DwPagesWatch<T>> {
  DwPagesNotifier(
    DwAppClient client,
    this.request, {
    void Function()? onDispose,
  }) : super(client, request.dwTypeName, onDispose);

  final DwPageRequest<T> request;

  @override
  DwPagesWatch<T> _open() => _client.watchPages(request);

  @override
  DwRequestState<DwPagedData<T>> _stateOf(DwPagesWatch<T> watch) => watch.state;

  @override
  Stream<DwRequestState<DwPagedData<T>>> _statesOf(DwPagesWatch<T> watch) =>
      watch.states;

  @override
  void _close(DwPagesWatch<T> watch) => watch.close();

  /// Loads the next page. Safe to call from every scroll event: one request
  /// while one is in flight, none when there is no more.
  Future<void> loadMore() => _watch?.loadMore() ?? Future.value();

  /// Loads from the top again, as many rows as are loaded.
  Future<void> refetch() => _watch?.refetch() ?? Future.value();

  bool get hasMore => _watch?.hasMore ?? false;

  bool get isLive => _watch?.isLive ?? false;
}

/// The Riverpod face of a [DwWindowWatch].
///
/// [DwWindowData.prependedCount] says how many rows the last change put
/// above the first one — a list that keeps its scroll position compensates
/// by that many — and [DwWindowData.unseenNewerCount] how many new rows wait
/// past the newest one loaded.
final class DwWindowNotifier<T extends DwDataObject>
    extends _DwWatchNotifier<DwWindowData<T>, DwWindowWatch<T>> {
  DwWindowNotifier(
    DwAppClient client,
    this.request, {
    this.anchor,
    void Function()? onDispose,
  }) : super(client, request.dwTypeName, onDispose);

  final DwWindowRequest<T, Object, Object> request;

  /// Where the window opened; `null` for the newest rows.
  final String? anchor;

  @override
  DwWindowWatch<T> _open() => _client.watchWindow(request, anchor: anchor);

  @override
  DwRequestState<DwWindowData<T>> _stateOf(DwWindowWatch<T> watch) =>
      watch.state;

  @override
  Stream<DwRequestState<DwWindowData<T>>> _statesOf(DwWindowWatch<T> watch) =>
      watch.states;

  @override
  void _close(DwWindowWatch<T> watch) => watch.close();

  /// Loads older rows. Safe to call from every scroll event.
  Future<void> loadOlder() => _watch?.loadOlder() ?? Future.value();

  /// Loads newer rows. Safe to call from every scroll event.
  Future<void> loadNewer() => _watch?.loadNewer() ?? Future.value();

  /// Reloads the window where it stands.
  Future<void> refetch() => _watch?.refetch() ?? Future.value();

  bool get isLive => _watch?.isLive ?? false;
}

/// A value the client streams, as a provider.
final class DwStreamValueNotifier<T> extends Notifier<T> {
  DwStreamValueNotifier(this._current, this._changes);

  final T Function() _current;
  final Stream<T> Function() _changes;

  @override
  T build() {
    final subscription = _changes().listen((value) => state = value);
    ref.onDispose(() => unawaited(subscription.cancel()));
    return _current();
  }
}

/// Maps client states to `AsyncValue`s, keeping the previous `AsyncValue`
/// for the same state object so a replayed state notifies nobody.
///
/// Every way a read ends short of data is an error of a type an app sorts by:
/// [DwRefusalException], [DwFailedException], [DwNotAuthenticatedException],
/// and [DwTimeoutException] for a server that has not answered (the client
/// keeps trying; the value becomes data when it does).
final class _DwAsyncMapper<R> {
  _DwAsyncMapper(this.call, this.callTimeout);

  final String call;
  final Duration callTimeout;
  DwRequestState<R>? _lastState;
  AsyncValue<R>? _lastValue;

  AsyncValue<R> map(DwRequestState<R> state) {
    if (identical(state, _lastState)) return _lastValue!;
    final value = switch (state) {
      DwRequestLoading() => AsyncLoading<R>(),
      DwRequestData(:final value) => AsyncData<R>(value),
      DwRequestRefused(:final refusal) => AsyncError<R>(
        DwRefusalException(refusal),
        StackTrace.empty,
      ),
      DwRequestFailed(:final incidentId) => AsyncError<R>(
        DwFailedException(incidentId, call: call),
        StackTrace.empty,
      ),
      DwRequestUnauthenticated() => AsyncError<R>(
        DwNotAuthenticatedException(call: call),
        StackTrace.empty,
      ),
      DwRequestUnreachable() => AsyncError<R>(
        DwTimeoutException(call, callTimeout),
        StackTrace.empty,
      ),
    };
    _lastState = state;
    _lastValue = value;
    return value;
  }
}
