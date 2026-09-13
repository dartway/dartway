import 'package:dartway_core/dartway_core.dart';

/// The state of a watched request, as a screen renders it.
///
/// Sealed, so a `switch` over it cannot forget the refusal, the failure or the
/// signed-out case — the three ways a read ends that are not data.
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

  /// The request is being run again (after a reconnect, a sign-in, an update
  /// that asked for it) and [value] is what it answered last. Rendering it is
  /// correct; a quiet progress hint is the most a screen owes the user.
  final bool refreshing;

  /// Every channel the request declares has a confirmed subscription on the
  /// current connection, so [value] follows the server as it changes.
  ///
  /// False while disconnected, while a subscription is being made, after the
  /// server refused or closed one, and always for a request that declares no
  /// channels — such a value is exactly as fresh as its last fetch.
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

/// The server refused the request: an answer for the user.
final class DwRequestRefused<R> extends DwRequestState<R> {
  const DwRequestRefused(this.refusal);

  final DwRefusal refusal;

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

/// The request needs a signed-in user and the connection has none.
final class DwRequestUnauthenticated<R> extends DwRequestState<R> {
  const DwRequestUnauthenticated();

  @override
  bool operator ==(Object other) => other is DwRequestUnauthenticated;

  @override
  int get hashCode => (DwRequestUnauthenticated).hashCode;

  @override
  String toString() => 'DwRequestUnauthenticated()';
}

/// The incident id of a failure detected on the client rather than reported by
/// the server. The server never issues it.
const String dwClientIncidentId = 'client';

/// Loaded pages of a paginated request, merged into one list.
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
  /// `DwNotAuthenticatedException` or a `DwProtocolException`. Cleared by the
  /// next attempt. [items] are kept: a page that did not arrive does not
  /// unload the ones that did.
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
