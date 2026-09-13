import '../channels/dw_channel.dart';
import '../protocol/dw_protocol.dart';
import 'dw_dto.dart';

/// What a request's state does with an object that arrived on one of its
/// channels.
enum DwUpdate {
  /// The framework's default for the request kind (see each kind's docs).
  auto,

  /// Insert the object, or replace the one with the same id in place.
  upsert,

  /// Remove the object with this id.
  remove,

  /// Re-run the request: the update affects data the client cannot compute.
  refetch,

  /// Not this request's business.
  ignore,
}

/// A read. Its fields are its parameters — its complete filter — and its
/// result type is expressed by the kind it extends.
///
/// A request has no side effects: the client may retry it, cache its result
/// under the request itself (equality is generated from the fields) and keep it
/// live through [channels].
abstract class DwRequest<R> extends DwDto {
  const DwRequest();

  /// The channels whose updates this request's state absorbs while it is
  /// watched. Subscriptions are reference-counted across requests.
  List<DwChannel> get channels => const [];

  /// How an object that arrived on [channels] affects this request's state.
  /// [DwUpdate.auto] applies the default of the request kind.
  DwUpdate onUpdate(DwDto update) => DwUpdate.auto;

  /// Whether [item] is an instance of this request's item type — the object
  /// type of a single, maybe, list, page or cursor request. A request that
  /// extends no kind has no item type and accepts nothing.
  ///
  /// Only the kind knows its type argument, so the question is put here
  /// rather than probed from outside. An explicit `is` test is kept by every
  /// compiler mode, including dart2js with implicit checks omitted.
  bool acceptsItem(Object? item) => false;

  /// Encodes a result of this request for the wire (server side).
  Object? encodeResult(R result, DwProtocol protocol);

  /// Decodes a result of this request from the wire (client side).
  R decodeResult(Object? json, DwProtocol protocol);
}

/// A request for exactly one object; the server refuses with `dw.notFound`
/// when there is none.
///
/// Default update: an object with the same id replaces the state; a
/// [DwDeleted] for it makes the request refetch (and so answer not-found).
abstract class DwSingleRequest<T extends DwDataObject> extends DwRequest<T> {
  const DwSingleRequest();

  @override
  bool acceptsItem(Object? item) => item is T;

  @override
  Object? encodeResult(T result, DwProtocol protocol) => result.toJson();

  @override
  T decodeResult(Object? json, DwProtocol protocol) =>
      protocol.decodeAs<T>(json);
}

/// A request for one object that may be absent.
///
/// Default update: an object with the id in state replaces it; while the state
/// is empty, an object for which [matches] is true fills it (the lesson of
/// #242: a request that answered "none" must hear about the row once it
/// exists); a [DwDeleted] for the held object empties the state.
abstract class DwMaybeRequest<T extends DwDataObject> extends DwRequest<T?> {
  const DwMaybeRequest();

  @override
  bool acceptsItem(Object? item) => item is T;

  /// Whether a newly arrived object is the one this request asks for.
  bool matches(T object) => false;

  @override
  Object? encodeResult(T? result, DwProtocol protocol) => result?.toJson();

  @override
  T? decodeResult(Object? json, DwProtocol protocol) =>
      json == null ? null : protocol.decodeAs<T>(json);
}

/// A request for a whole, unpaginated list.
///
/// Default update: an object with an id in the list is replaced in place and
/// never moved; a new object for which [matches] is true is inserted by [sort]
/// when declared, otherwise at the head; a [DwDeleted] removes.
abstract class DwListRequest<T extends DwDataObject>
    extends DwRequest<List<T>> {
  const DwListRequest();

  @override
  bool acceptsItem(Object? item) => item is T;

  /// Whether a newly arrived object belongs to this list. By default every
  /// object of type [T] on the request's channels does.
  bool matches(T object) => true;

  /// Order for inserting new objects; `null` inserts at the head.
  int Function(T a, T b)? get sort => null;

  @override
  Object? encodeResult(List<T> result, DwProtocol protocol) => [
    for (final item in result) item.toJson(),
  ];

  @override
  List<T> decodeResult(Object? json, DwProtocol protocol) => [
    for (final item in json! as List<Object?>) protocol.decodeAs<T>(item),
  ];
}

/// One page of a paginated request.
final class DwPage<T extends DwDataObject> {
  const DwPage(this.items, {required this.hasMore});

  final List<T> items;

  /// Whether another page exists. The server learns it by reading one row past
  /// the page, never by counting.
  final bool hasMore;
}

/// A request read in pages by offset.
///
/// The server's order must be total (for example `createdAt, id`), otherwise
/// offset pages skip and repeat rows. Default update as [DwListRequest]; a new
/// object that sorts past the loaded pages is ignored and appears on scroll.
abstract class DwPageRequest<T extends DwDataObject>
    extends DwRequest<DwPage<T>> {
  const DwPageRequest();

  @override
  bool acceptsItem(Object? item) => item is T;

  /// Rows per page. Decided by the request, not by the caller: the server
  /// reads it from the same class.
  int get pageSize;

  bool matches(T object) => true;

  int Function(T a, T b)? get sort => null;

  @override
  Object? encodeResult(DwPage<T> result, DwProtocol protocol) => {
    'items': [for (final item in result.items) item.toJson()],
    'more': result.hasMore,
  };

  @override
  DwPage<T> decodeResult(Object? json, DwProtocol protocol) {
    final map = json! as Map<String, Object?>;
    return DwPage([
      for (final item in map['items']! as List<Object?>)
        protocol.decodeAs<T>(item),
    ], hasMore: map['more']! as bool);
  }
}

/// A request read in pages backwards from the newest: "load older".
///
/// The cursor is the id of the oldest loaded object; the server returns objects
/// with smaller ids, newest first. Default update: an object with an id in
/// state is replaced in place; a new one is inserted at the head.
abstract class DwCursorRequest<T extends DwDataObject>
    extends DwRequest<DwPage<T>> {
  const DwCursorRequest();

  @override
  bool acceptsItem(Object? item) => item is T;

  int get pageSize;

  bool matches(T object) => true;

  @override
  Object? encodeResult(DwPage<T> result, DwProtocol protocol) => {
    'items': [for (final item in result.items) item.toJson()],
    'more': result.hasMore,
  };

  @override
  DwPage<T> decodeResult(Object? json, DwProtocol protocol) {
    final map = json! as Map<String, Object?>;
    return DwPage([
      for (final item in map['items']! as List<Object?>)
        protocol.decodeAs<T>(item),
    ], hasMore: map['more']! as bool);
  }
}

/// Which page a paginated request asks for.
sealed class DwPageParams {
  const DwPageParams();

  Map<String, Object?> toJson();

  static DwPageParams? fromJson(Object? json) {
    if (json == null) return null;
    final map = json as Map<String, Object?>;
    if (map.containsKey('offset')) {
      return DwOffsetParams(map['offset']! as int);
    }
    return DwCursorParams(map['before']);
  }
}

/// Offset page parameters.
final class DwOffsetParams extends DwPageParams {
  const DwOffsetParams(this.offset);

  final int offset;

  @override
  Map<String, Object?> toJson() => {'offset': offset};
}

/// Cursor page parameters: objects older than [before]; `null` is the newest page.
final class DwCursorParams extends DwPageParams {
  const DwCursorParams(this.before);

  final Object? before;

  @override
  Map<String, Object?> toJson() => {'before': before};
}
