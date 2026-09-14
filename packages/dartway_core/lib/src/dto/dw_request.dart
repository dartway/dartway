part of 'dw_server_call.dart';

/// What a watched request's state does with an object that arrived on one of
/// its channels (or in the updates of a command's response).
///
/// There is no "default" value: every kind answers an explicit action, so
/// what happens to an update is readable from the request class alone.
enum DwUpdateAction {
  /// Replace the object with the same id where it stands; insert it when
  /// absent — by the request's `sort` when it declares one, otherwise at the
  /// head. Insertion is further bounded by the kind: a page request drops an
  /// object that sorts past its loaded pages while more pages exist, and a
  /// window inserts only while it shows the newest rows (`hasNewer` false).
  upsert,

  /// Replace the object with the same id where it stands; never insert.
  update,

  /// Remove the object with this id. For a single request, whose state cannot
  /// be empty, the client asks again and shows what the server now answers
  /// (`dw.notFound`).
  remove,

  /// Re-run the request: the update affects data the client cannot compute.
  refetch,

  /// Not this request's business.
  ignore,
}

/// How a request kind answers [DwRequest.onUpdate] by default. Chosen by the
/// kind's (named) super constructor, so a project request class stays `const`
/// and says its scenario in its declaration.
enum _DwUpdatePolicy {
  /// An object → [DwUpdateAction.update]; a deletion → remove.
  update,

  /// An object → `matches ? upsert : remove`; a deletion → remove.
  matching,

  /// An object or a deletion → refetch.
  refetch,

  /// An object → update; a deletion → refetch: numbered pages shift when a
  /// row disappears, so the page is read again.
  table,
}

/// A read. Its fields are its parameters — its complete filter — and its
/// result type is expressed by the kind it extends:
///
/// | Kind | Result | Default update |
/// |---|---|---|
/// | [DwSingleRequest] | `T` (absent ⇒ `dw.notFound`) | update |
/// | [DwMaybeRequest] | `T?` | `matches ? upsert : remove` |
/// | [DwListRequest] | `List<T>` | `matches ? upsert : remove`; `.updateOnly()`, `.refetchOnUpdate()` |
/// | [DwPageRequest] | [DwPage] | `matches ? upsert : remove`; `.updateOnly()` |
/// | [DwTableRequest] | [DwTablePage] | update; a deletion refetches |
/// | [DwWindowRequest] | [DwWindow] | `matches ? upsert : remove` |
///
/// A request has no side effects: the client may retry it, cache its result
/// under the request itself (equality is generated from the fields) and keep it
/// live through [channels].
///
/// [acceptsItem], [acceptsDeletion], `matches`, `sort` and [channels] must be
/// pure functions of the object and the request's fields: the client relies
/// on an equal request answering equally. `DateTime.now()` inside them is a
/// bug.
sealed class DwRequest<R> extends DwServerCall<R> {
  const DwRequest._(this._policy);

  final _DwUpdatePolicy _policy;

  /// The channels whose updates this request's state absorbs while it is
  /// watched. Subscriptions are reference-counted across requests.
  List<DwChannel> get channels => const [];

  /// Whether [item] is an instance of this request's item type.
  ///
  /// Only the kind knows its type argument, so the question is put here
  /// rather than probed from outside. An explicit `is` test is kept by every
  /// compiler mode, including dart2js with implicit checks omitted.
  bool acceptsItem(Object? item);

  /// Whether [deletion] removes an object of this request's item type.
  ///
  /// A deletion names its type by wire name, which only the protocol can
  /// relate to the kind's type argument.
  bool acceptsDeletion(DwDeleted deletion, DwProtocol protocol);

  /// What an arrived object does to this request's state.
  ///
  /// The client offers only what concerns the request: objects [acceptsItem]
  /// is true for and deletions [acceptsDeletion] is true for. The kind's
  /// answer is explicit (see the table on [DwRequest]); override for a
  /// special case, keeping it a pure function of [item] and the fields.
  DwUpdateAction onUpdate(Object item) {
    if (item is DwDeleted) {
      return switch (_policy) {
        _DwUpdatePolicy.refetch ||
        _DwUpdatePolicy.table => DwUpdateAction.refetch,
        _DwUpdatePolicy.update ||
        _DwUpdatePolicy.matching => DwUpdateAction.remove,
      };
    }
    if (!acceptsItem(item)) return DwUpdateAction.ignore;
    return switch (_policy) {
      _DwUpdatePolicy.update || _DwUpdatePolicy.table => DwUpdateAction.update,
      _DwUpdatePolicy.matching =>
        _matchesItem(item) ? DwUpdateAction.upsert : DwUpdateAction.remove,
      _DwUpdatePolicy.refetch => DwUpdateAction.refetch,
    };
  }

  /// `matches` of the kinds that declare it, reached without the type
  /// argument; called only with an item [acceptsItem] is true for.
  bool _matchesItem(Object item) => true;
}

/// A request for exactly one object; the server refuses with `dw.notFound`
/// when there is none.
///
/// Default update: an object with the held id replaces the state
/// ([DwUpdateAction.update]); a deletion removes it, and the client asks again
/// to show what the server now answers.
abstract class DwSingleRequest<T extends DwDataObject> extends DwRequest<T> {
  const DwSingleRequest() : super._(_DwUpdatePolicy.update);

  @override
  bool acceptsItem(Object? item) => item is T;

  @override
  bool acceptsDeletion(DwDeleted deletion, DwProtocol protocol) =>
      deletion.isOf<T>(protocol);

  @override
  Object? encodeResult(T result, DwProtocol protocol) => result.toJson();

  @override
  T decodeResult(Object? json, DwProtocol protocol) =>
      protocol.decodeAs<T>(json);
}

/// A request for one object that may be absent.
///
/// Default update: `matches ? upsert : remove` — while the state is empty, an
/// object for which [matches] is true fills it (#242: a request that answered
/// "none" must hear about the row once it exists); an object that stops
/// matching, or a deletion of the held one, empties it.
abstract class DwMaybeRequest<T extends DwDataObject> extends DwRequest<T?> {
  const DwMaybeRequest() : super._(_DwUpdatePolicy.matching);

  @override
  bool acceptsItem(Object? item) => item is T;

  @override
  bool acceptsDeletion(DwDeleted deletion, DwProtocol protocol) =>
      deletion.isOf<T>(protocol);

  /// Whether [item] is the one this request asks for.
  ///
  /// Required, unlike the list kinds' `matches`: a maybe request asks for one
  /// particular object, and no default can say which — "every object" would
  /// fill the state with the first stranger on the channel, "none" would
  /// empty it on every update of the held one.
  bool matches(T item);

  @override
  bool _matchesItem(Object item) => matches(item as T);

  @override
  Object? encodeResult(T? result, DwProtocol protocol) => result?.toJson();

  @override
  T? decodeResult(Object? json, DwProtocol protocol) =>
      json == null ? null : protocol.decodeAs<T>(json);
}

/// A request for a whole, unpaginated list.
///
/// Default update (`DwListRequest()`): `matches ? upsert : remove` — an object
/// already in the list is replaced in place and never moved, a new matching
/// one is inserted by [sort] (at the head without one), one that stops
/// matching is removed, a deletion removes.
///
/// `DwListRequest.updateOnly()`: objects in the list are replaced, nothing is
/// inserted, a deletion removes — for lists whose membership only the server
/// decides.
///
/// `DwListRequest.refetchOnUpdate()`: every update re-runs the request — for
/// derived lists the client cannot compute.
abstract class DwListRequest<T extends DwDataObject>
    extends DwRequest<List<T>> {
  const DwListRequest() : super._(_DwUpdatePolicy.matching);

  const DwListRequest.updateOnly() : super._(_DwUpdatePolicy.update);

  const DwListRequest.refetchOnUpdate() : super._(_DwUpdatePolicy.refetch);

  @override
  bool acceptsItem(Object? item) => item is T;

  @override
  bool acceptsDeletion(DwDeleted deletion, DwProtocol protocol) =>
      deletion.isOf<T>(protocol);

  /// Whether [item] belongs to this list. By default every object of type [T]
  /// on the request's channels does.
  bool matches(T item) => true;

  @override
  bool _matchesItem(Object item) => matches(item as T);

  /// Order for inserting new objects; `null` inserts at the head.
  int Function(T a, T b)? get sort => null;

  @override
  Object? encodeResult(List<T> result, DwProtocol protocol) => [
    for (final item in result) item.toJson(),
  ];

  @override
  List<T> decodeResult(Object? json, DwProtocol protocol) => [
    for (final item in dwReadList(json, 'A list result'))
      protocol.decodeAs<T>(item),
  ];
}

/// An accumulating feed read by offset: "load more" appends the next page.
///
/// [pageSize] and [maxPageSize] are constants of the class, passed to the
/// super constructor and never serialised: the client cannot ask the server
/// for everything. A call may ask for up to [maxPageSize] rows at once (the
/// `pageSize` query parameter — reloading the pages already loaded in one
/// call); the server serves [servedPageSize].
///
/// The server's order must be total (for example `createdAt, id`), otherwise
/// offset pages skip and repeat rows.
///
/// Default update (`DwPageRequest(pageSize: …)`): as [DwListRequest]; a new
/// object that sorts past the loaded pages is dropped while more pages exist
/// and appears on scroll. `DwPageRequest.updateOnly(pageSize: …)`: replace,
/// never insert, a deletion removes.
abstract class DwPageRequest<T extends DwDataObject>
    extends DwRequest<DwPage<T>> {
  const DwPageRequest({required this.pageSize, int? maxPageSize})
    : assert(pageSize > 0, 'pageSize must be positive'),
      assert(
        maxPageSize == null || maxPageSize >= pageSize,
        'maxPageSize must not be below pageSize',
      ),
      _maxPageSize = maxPageSize,
      super._(_DwUpdatePolicy.matching);

  const DwPageRequest.updateOnly({required this.pageSize, int? maxPageSize})
    : assert(pageSize > 0, 'pageSize must be positive'),
      assert(
        maxPageSize == null || maxPageSize >= pageSize,
        'maxPageSize must not be below pageSize',
      ),
      _maxPageSize = maxPageSize,
      super._(_DwUpdatePolicy.update);

  /// Rows per page when the call does not ask for another size.
  final int pageSize;

  final int? _maxPageSize;

  /// The most rows one call is served; [pageSize] unless the class allows
  /// more.
  int get maxPageSize => _maxPageSize ?? pageSize;

  /// The rows a call asking for [asked] (`null`: not asking) is served.
  int servedPageSize(int? asked) => _serve(asked, pageSize, maxPageSize);

  @override
  bool acceptsItem(Object? item) => item is T;

  @override
  bool acceptsDeletion(DwDeleted deletion, DwProtocol protocol) =>
      deletion.isOf<T>(protocol);

  /// Whether [item] belongs to this feed. By default every object of type [T]
  /// on the request's channels does.
  bool matches(T item) => true;

  @override
  bool _matchesItem(Object item) => matches(item as T);

  /// Order for inserting new objects; `null` inserts at the head.
  int Function(T a, T b)? get sort => null;

  @override
  Object? encodeResult(DwPage<T> result, DwProtocol protocol) =>
      result.toJson();

  @override
  DwPage<T> decodeResult(Object? json, DwProtocol protocol) =>
      DwPage.fromJson(json, protocol.decodeAs<T>);
}

/// Numbered pages: page 3 of 12, with a total.
///
/// [page] (from 1) and [pageSize] are **fields** of the project class — they
/// are the request's key, page 2 and page 3 are different states:
///
/// ```dart
/// final class ListClients extends DwTableRequest<ClientCard> with _$ListClients {
///   const ListClients({this.page = 1, this.pageSize = 20}) : super(maxPageSize: 100);
///   @override final int page;
///   @override final int pageSize;
/// }
/// ```
///
/// [maxPageSize] is a constant of the class; the server serves
/// [servedPageSize] and answers the size it served in [DwTablePage.pageSize].
///
/// Default update: an object on the page is replaced, nothing is inserted (a
/// numbered page never grows by an update); a deletion re-reads the page,
/// since every later row moves up.
abstract class DwTableRequest<T extends DwDataObject>
    extends DwRequest<DwTablePage<T>> {
  const DwTableRequest({required this.maxPageSize})
    : assert(maxPageSize > 0, 'maxPageSize must be positive'),
      super._(_DwUpdatePolicy.table);

  /// The page asked for, from 1.
  int get page;

  /// Rows per page asked for; the server serves at most [maxPageSize].
  int get pageSize;

  /// The most rows a page is served.
  final int maxPageSize;

  /// The rows per page the server serves for this request.
  int get servedPageSize => pageSize < maxPageSize ? pageSize : maxPageSize;

  /// The offset of the first row of the page, at [servedPageSize].
  int get offset => (page - 1) * servedPageSize;

  /// The refusal for a page or page size below 1, which no clamping can turn
  /// into the page the caller meant; `null` when both are valid. The framework
  /// runs it with `validate()`, on both sides.
  DwRefusal? checkPage() {
    if (page < 1) {
      return DwRefusal(
        DwCoreRefusal.invalid,
        field: 'page',
        params: {'min': 1},
      );
    }
    if (pageSize < 1) {
      return DwRefusal(
        DwCoreRefusal.invalid,
        field: 'pageSize',
        params: {'min': 1},
      );
    }
    return null;
  }

  @override
  bool acceptsItem(Object? item) => item is T;

  @override
  bool acceptsDeletion(DwDeleted deletion, DwProtocol protocol) =>
      deletion.isOf<T>(protocol);

  @override
  Object? encodeResult(DwTablePage<T> result, DwProtocol protocol) =>
      result.toJson();

  @override
  DwTablePage<T> decodeResult(Object? json, DwProtocol protocol) =>
      DwTablePage.fromJson(json, protocol.decodeAs<T>);
}

/// A window over a long, newest-first sequence (a chat, a log), read in both
/// directions from an anchor.
///
/// Without an anchor the window opens at the newest rows. Loading older or
/// newer rows goes by the cursors of [DwWindow], which the server builds from
/// the sort value and the id (`DwWindowCursor`), so rows sharing a timestamp
/// are neither lost nor repeated.
///
/// [pageSize] and [maxPageSize] are constants of the class, as in
/// [DwPageRequest].
///
/// Default update: `matches ? upsert : remove` — an object in the window is
/// replaced; a new matching one is inserted at the head **only while the
/// window shows the newest rows** (`hasNewer` false), otherwise the window
/// counts it as unseen; one that stops matching, or a deletion, is removed.
abstract class DwWindowRequest<T extends DwDataObject>
    extends DwRequest<DwWindow<T>> {
  const DwWindowRequest({required this.pageSize, int? maxPageSize})
    : assert(pageSize > 0, 'pageSize must be positive'),
      assert(
        maxPageSize == null || maxPageSize >= pageSize,
        'maxPageSize must not be below pageSize',
      ),
      _maxPageSize = maxPageSize,
      super._(_DwUpdatePolicy.matching);

  /// Rows per load when the call does not ask for another size.
  final int pageSize;

  final int? _maxPageSize;

  /// The most rows one call is served; [pageSize] unless the class allows
  /// more.
  int get maxPageSize => _maxPageSize ?? pageSize;

  /// The rows a call asking for [asked] (`null`: not asking) is served.
  int servedPageSize(int? asked) => _serve(asked, pageSize, maxPageSize);

  @override
  bool acceptsItem(Object? item) => item is T;

  @override
  bool acceptsDeletion(DwDeleted deletion, DwProtocol protocol) =>
      deletion.isOf<T>(protocol);

  /// Whether [item] belongs to this window's sequence. By default every
  /// object of type [T] on the request's channels does.
  bool matches(T item) => true;

  @override
  bool _matchesItem(Object item) => matches(item as T);

  @override
  Object? encodeResult(DwWindow<T> result, DwProtocol protocol) =>
      result.toJson();

  @override
  DwWindow<T> decodeResult(Object? json, DwProtocol protocol) =>
      DwWindow.fromJson(json, protocol.decodeAs<T>);
}

/// One clamping rule for the kinds with a constant page size. An asked size
/// below 1 never reaches here: the page query refuses it as malformed.
int _serve(int? asked, int pageSize, int maxPageSize) {
  if (asked == null) return pageSize;
  return asked < maxPageSize ? asked : maxPageSize;
}
