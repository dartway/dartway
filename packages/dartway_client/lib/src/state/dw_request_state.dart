import 'package:dartway_core_shared/dartway_core_shared.dart';

/// The state of a watched request, as a screen renders it.
///
/// Sealed, so a `switch` over it cannot forget the refusal, the failure, the
/// signed-out case or an unreachable server — the ways a read ends that are
/// not data.
sealed class DwRequestState<R> {
  const DwRequestState();
}

/// No answer yet, and nothing to show meanwhile.
final class DwRequestLoading<R> extends DwRequestState<R> {
  const DwRequestLoading();

  @override
  bool operator ==(Object other) => other is DwRequestLoading;

  @override
  int get hashCode => (DwRequestLoading).hashCode;

  @override
  String toString() => 'DwRequestLoading()';
}

/// The request's data.
final class DwRequestData<R> extends DwRequestState<R> {
  const DwRequestData(this.value, {this.refreshing = false, this.live = false});

  final R value;

  /// The request is being run again (a pull to refresh, an update that asked
  /// for it, a reconnected socket) and [value] is what it answered last.
  /// Rendering it is correct; a quiet progress hint is the most a screen owes
  /// the user.
  final bool refreshing;

  /// Every channel the request declares has a confirmed subscription on the
  /// live socket, so [value] follows the server as it changes.
  ///
  /// False while the socket is down, while a subscription is being made,
  /// after the server refused or closed one, and always for a request that
  /// declares no channels — such a value is exactly as fresh as its last
  /// fetch.
  final bool live;

  /// Lists compare element-wise — generated DTOs compare by value, and a
  /// state holding an equal list is the same state.
  @override
  bool operator ==(Object other) =>
      other is DwRequestData &&
      other.refreshing == refreshing &&
      other.live == live &&
      (value is List && other.value is List
          ? dwListEquals(value as List, other.value as List)
          : other.value == value);

  @override
  int get hashCode => Object.hash(
    value is List ? Object.hashAll(value as List) : value,
    refreshing,
    live,
  );

  @override
  String toString() =>
      'DwRequestData($value${refreshing ? ', refreshing' : ''}${live ? ', live' : ''})';
}

/// The server refused the request: an answer for the user. Also the state of
/// a request that does not validate (nothing was sent), and of every request
/// once the client is incompatible with its server (`dw.updateRequired`,
/// `dw.protocolUnsupported`).
final class DwRequestRefused<R> extends DwRequestState<R> {
  const DwRequestRefused(this.refusal);

  final DwCallRefusal refusal;

  @override
  bool operator ==(Object other) =>
      other is DwRequestRefused && other.refusal == refusal;

  @override
  int get hashCode => refusal.hashCode;

  @override
  String toString() => 'DwRequestRefused($refusal)';
}

/// The request failed. [incidentId] is what the operator finds it by; a
/// failure the client detected itself (an answer it could not decode) carries
/// [dwClientIncidentId], and its cause went to the client's `onError`.
final class DwRequestFailed<R> extends DwRequestState<R> {
  const DwRequestFailed(this.incidentId);

  final String incidentId;

  @override
  bool operator ==(Object other) =>
      other is DwRequestFailed && other.incidentId == incidentId;

  @override
  int get hashCode => incidentId.hashCode;

  @override
  String toString() => 'DwRequestFailed($incidentId)';
}

/// The request needs a signed-in user and the caller has none.
final class DwRequestUnauthenticated<R> extends DwRequestState<R> {
  const DwRequestUnauthenticated();

  @override
  bool operator ==(Object other) => other is DwRequestUnauthenticated;

  @override
  int get hashCode => (DwRequestUnauthenticated).hashCode;

  @override
  String toString() => 'DwRequestUnauthenticated()';
}

/// The server has not answered for `DwClientOptions.callTimeout` and there is
/// no data to show. The client keeps retrying: the state becomes data as soon
/// as an answer arrives.
final class DwRequestUnreachable<R> extends DwRequestState<R> {
  const DwRequestUnreachable();

  @override
  bool operator ==(Object other) => other is DwRequestUnreachable;

  @override
  int get hashCode => (DwRequestUnreachable).hashCode;

  @override
  String toString() => 'DwRequestUnreachable()';
}

/// The incident id of a failure detected on the client rather than reported
/// by the server. The server never issues it.
const String dwClientIncidentId = 'client';

/// Loaded pages of a `DwPageRequest`, merged into one list.
final class DwPagedData<T extends DwDataObject> {
  const DwPagedData(
    this.items, {
    required this.hasMore,
    this.loadingMore = false,
    this.loadMoreError,
  });

  /// Every loaded object, in the server's order, with live updates applied.
  final List<T> items;

  /// Whether the server has another page after [items].
  final bool hasMore;

  /// A next page is being loaded.
  final bool loadingMore;

  /// Why the last attempt to load the next page did not: a
  /// `DwRefusalException`, a `DwFailedException`, a
  /// `DwNotAuthenticatedException`, a `DwTimeoutException` or a
  /// `DwProtocolException`. Cleared by the next attempt. [items] are kept: a
  /// page that did not arrive does not unload the ones that did.
  final Exception? loadMoreError;

  @override
  bool operator ==(Object other) =>
      other is DwPagedData &&
      dwListEquals(other.items, items) &&
      other.hasMore == hasMore &&
      other.loadingMore == loadingMore &&
      other.loadMoreError == loadMoreError;

  @override
  int get hashCode =>
      Object.hash(Object.hashAll(items), hasMore, loadingMore, loadMoreError);

  @override
  String toString() =>
      'DwPagedData(${items.length} items${hasMore ? ', more' : ''}'
      '${loadingMore ? ', loading more' : ''}'
      '${loadMoreError == null ? '' : ', $loadMoreError'})';
}

/// The loaded rows of a `DwWindowRequest`: newest first, grown in both
/// directions.
final class DwWindowData<T extends DwDataObject> {
  const DwWindowData(
    this.items, {
    required this.hasOlder,
    required this.hasNewer,
    this.loadingOlder = false,
    this.loadingNewer = false,
    this.loadError,
    this.unseenNewerCount = 0,
    this.prependedCount = 0,
  });

  /// Newest first, with live updates applied.
  final List<T> items;

  /// Rows older than the last item exist on the server. While `false`, a new
  /// row older than the last item arriving live is appended; while `true` it
  /// is left for `loadOlder` to bring.
  final bool hasOlder;

  /// Rows newer than the first item exist on the server. While `false`, a new
  /// row newer than the first item arriving live is inserted at the head;
  /// while `true` it is counted in [unseenNewerCount] instead. A row between
  /// the first and the last goes where the request's `positionOf` puts it.
  final bool hasNewer;

  final bool loadingOlder;
  final bool loadingNewer;

  /// Why the last `loadOlder` or `loadNewer` did not load: the same exception
  /// types as `DwPagedData.loadMoreError`. Cleared by the next load.
  final Exception? loadError;

  /// New rows that arrived live while the window did not show the newest
  /// rows — each counted once, however often it was updated — for a
  /// "N new ↓" hint. Zero once the window reaches the newest rows.
  final int unseenNewerCount;

  /// How many rows the change that produced this value put before the
  /// previous first row: a `loadNewer` page, or new rows inserted live. A
  /// list that keeps its scroll position compensates by this many rows; `0`
  /// after a full load, which has no previous position to keep.
  final int prependedCount;

  @override
  bool operator ==(Object other) =>
      other is DwWindowData &&
      dwListEquals(other.items, items) &&
      other.hasOlder == hasOlder &&
      other.hasNewer == hasNewer &&
      other.loadingOlder == loadingOlder &&
      other.loadingNewer == loadingNewer &&
      other.loadError == loadError &&
      other.unseenNewerCount == unseenNewerCount &&
      other.prependedCount == prependedCount;

  @override
  int get hashCode => Object.hash(
    Object.hashAll(items),
    hasOlder,
    hasNewer,
    loadingOlder,
    loadingNewer,
    loadError,
    unseenNewerCount,
    prependedCount,
  );

  @override
  String toString() =>
      'DwWindowData(${items.length} items'
      '${hasOlder ? ', older' : ''}${hasNewer ? ', newer' : ''}'
      '${loadingOlder ? ', loading older' : ''}'
      '${loadingNewer ? ', loading newer' : ''}'
      '${unseenNewerCount > 0 ? ', $unseenNewerCount unseen' : ''}'
      '${prependedCount > 0 ? ', +$prependedCount at head' : ''}'
      '${loadError == null ? '' : ', $loadError'})';
}
