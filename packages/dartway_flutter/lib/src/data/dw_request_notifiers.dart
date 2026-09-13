import 'dart:async';

import 'package:dartway_client/dartway_client.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// What `dw.request(request)` returns.
typedef DwRequestProvider<R> =
    NotifierProvider<DwRequestNotifier<R>, AsyncValue<R>>;

/// What `dw.pages(request)` returns.
typedef DwPagesProvider<T extends DwDataObject> =
    NotifierProvider<DwPagesNotifier<T>, AsyncValue<DwPagedData<T>>>;

/// What `dw.accountId` and `dw.connectionStatus` return: a value to watch,
/// with nothing to call.
typedef DwValueProvider<T> = NotifierProvider<Notifier<T>, T>;

/// The Riverpod face of a [DwWatch]: one watch for as long as the provider is
/// listened to, its states as `AsyncValue`s.
///
/// Riverpod shares one notifier per provider per container, and the client
/// shares one live entry per equal request across all of them — so two
/// screens, two containers or a rebuilt provider never cost a second fetch or
/// subscription.
final class DwRequestNotifier<R> extends Notifier<AsyncValue<R>> {
  DwRequestNotifier(this._client, this.request, {void Function()? onDispose})
    : _onDispose = onDispose;

  final DwClient _client;
  final DwRequest<R> request;
  final void Function()? _onDispose;
  DwWatch<R>? _watch;

  @override
  AsyncValue<R> build() {
    final watch = _client.watch(request);
    _watch = watch;
    final mapper = _AsyncMapper<R>(request.dwTypeName);
    // The first event replays the current state; the mapper answers it with
    // the same AsyncValue, which Riverpod does not notify about.
    final subscription = watch.states.listen(
      (next) => state = mapper.map(next),
    );
    ref.onDispose(() {
      unawaited(subscription.cancel());
      watch.close();
      _onDispose?.call();
    });
    return mapper.map(watch.state);
  }

  /// Runs the request again (pull to refresh); completes when answered.
  Future<void> refetch() => _watch?.refetch() ?? Future.value();

  /// Whether the data shown follows the server live.
  bool get isLive => _watch?.isLive ?? false;
}

/// The Riverpod face of a [DwPagedWatch].
final class DwPagesNotifier<T extends DwDataObject>
    extends Notifier<AsyncValue<DwPagedData<T>>> {
  DwPagesNotifier(this._client, this.request, {void Function()? onDispose})
    : _onDispose = onDispose;

  final DwClient _client;
  final DwRequest<DwPage<T>> request;
  final void Function()? _onDispose;
  DwPagedWatch<T>? _watch;

  @override
  AsyncValue<DwPagedData<T>> build() {
    final watch = _client.watchPages(request);
    _watch = watch;
    final mapper = _AsyncMapper<DwPagedData<T>>(request.dwTypeName);
    // The first event replays the current state; the mapper answers it with
    // the same AsyncValue, which Riverpod does not notify about.
    final subscription = watch.states.listen(
      (next) => state = mapper.map(next),
    );
    ref.onDispose(() {
      unawaited(subscription.cancel());
      watch.close();
      _onDispose?.call();
    });
    return mapper.map(watch.state);
  }

  /// Loads the next page. Safe to call from every scroll event: one request
  /// while one is in flight, none when there is no more.
  Future<void> loadMore() => _watch?.loadMore() ?? Future.value();

  /// Loads from the top again, as many items as are loaded.
  Future<void> refetch() => _watch?.refetch() ?? Future.value();

  bool get hasMore => _watch?.hasMore ?? false;

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
final class _AsyncMapper<R> {
  _AsyncMapper(this.call);

  final String call;
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
    };
    _lastState = state;
    _lastValue = value;
    return value;
  }
}
