import 'package:dartway_core_shared/dartway_core_shared.dart';
import 'package:meta/meta.dart';

import '../context/dw_call_context.dart';

/// Who may make a call. Required on every handler: there is no default, so a
/// handler cannot be open by omission.
sealed class DwAccessRule {
  const DwAccessRule._();

  /// Anyone, including a caller without a session.
  static const DwAccessRule anonymous = DwAnonymousAccess._();

  /// Any signed-in account.
  static const DwAccessRule signedIn = DwSignedInAccess._();

  /// A signed-in account for which [check] is true; otherwise `dw.forbidden`.
  ///
  /// [check] receives the call, for rules on its real parameters (staff
  /// viewing a client's bookings); [C] is the call class the rule is written
  /// for, and a handler of another class fails the server's startup. The
  /// check runs after validation, in the handler's context — inside the
  /// transaction of a transactional command.
  static DwAccessRule check<C extends DwServerCall<Object?>>(
    Future<bool> Function(DwCallContext ctx, C call) check,
  ) => DwCheckAccess<C>._(check);
}

final class DwAnonymousAccess extends DwAccessRule {
  const DwAnonymousAccess._() : super._();
}

final class DwSignedInAccess extends DwAccessRule {
  const DwSignedInAccess._() : super._();
}

final class DwCheckAccess<C extends DwServerCall<Object?>>
    extends DwAccessRule {
  const DwCheckAccess._(this._check) : super._();

  final Future<bool> Function(DwCallContext ctx, C call) _check;

  /// The call class the rule is written for.
  Type get callType => C;

  bool _fits<Q>() => <Q>[] is List<C>;

  Future<bool> allows(DwCallContext ctx, DwServerCall<Object?> call) =>
      _check(ctx, call as C);
}

/// The rows a page handler reads: [fetchLimit] rows after [offset], in the
/// request's total order.
final class DwPageInput {
  const DwPageInput._(this.offset, this.pageSize);

  /// Rows already loaded.
  final int offset;

  /// Rows the page holds: the request's page size, or the size the call asked
  /// for, clamped to the request's maximum.
  final int pageSize;

  /// One past the page, so the framework learns whether another page exists
  /// without counting. Reading more is a handler bug and fails the call.
  int get fetchLimit => pageSize + 1;
}

/// The rows a table handler reads: [fetchLimit] rows after [offset].
final class DwTableInput {
  const DwTableInput._(this.page, this.pageSize);

  /// The page asked for, from 1.
  final int page;

  /// Rows per page, clamped to the request's `maxPageSize`.
  final int pageSize;

  int get offset => (page - 1) * pageSize;

  /// One past the page: a short read is the last page, and its total is known
  /// without asking the count.
  int get fetchLimit => pageSize + 1;
}

/// The rows a window handler reads — one direction at a time; the framework
/// composes "around an anchor" from both.
///
/// With `(sortValue, id)` compared as a pair:
///
/// - [DwWindowDirection.older]: rows below [position] (or at it, when
///   [includesPosition]), **newest first**, at most [fetchLimit]. Without a
///   position: the newest rows.
/// - [DwWindowDirection.newer]: rows above [position], **oldest first**, at
///   most [fetchLimit]. Always with a position.
///
/// ```sql
/// WHERE (sent_at, id) < (@sort, @id) ORDER BY sent_at DESC, id DESC LIMIT @limit
/// ```
final class DwWindowInput<S extends Object, I extends Object> {
  const DwWindowInput._(
    this.direction,
    this.position,
    this.fetchLimit, {
    this.includesPosition = false,
  });

  /// [DwWindowDirection.older] or [DwWindowDirection.newer]; never `around`.
  final DwWindowDirection direction;

  /// Where the read starts; `null` only for the newest rows.
  final DwWindowPosition<S, I>? position;

  /// Whether the row at [position] itself is read (the anchor of a window
  /// opened around it).
  final bool includesPosition;

  final int fetchLimit;

  @override
  String toString() =>
      'DwWindowInput(${direction.name}, $position'
      '${includesPosition ? ' inclusive' : ''}, limit $fetchLimit)';
}

/// A server handler for one request or command class.
///
/// Built only through the factories, one per request kind and one for
/// commands; the registry passed to `DwAppServer` must hold exactly one
/// handler per request and command class of the protocol.
///
/// Every factory takes [DwAccessRule] (required) and an optional
/// `maxBodyBytes` overriding `DwServerSettings.maxBodyBytes` for this call —
/// an upload of a few megabytes, or a tiny command that has no business
/// receiving one.
sealed class DwCallHandler {
  DwCallHandler._(this.access, this.maxBodyBytes) {
    if (maxBodyBytes case final limit? when limit < 1) {
      throw ArgumentError.value(limit, 'maxBodyBytes', 'must be positive');
    }
  }

  final DwAccessRule access;

  /// The body limit of this call; `null` uses the server's.
  final int? maxBodyBytes;

  /// The request or command class this handler answers.
  Type get callType;

  /// Why [access] cannot guard this handler's class, or `null`.
  @internal
  String? get accessProblem => switch (access) {
    DwCheckAccess(:final callType) when !_accessFits() =>
      'the access check of the $this handler is written for $callType',
    _ => null,
  };

  bool _accessFits();

  /// A single request. [handle] answers `null` when the object does not exist
  /// (or the caller may not know it does): the framework refuses
  /// `dw.notFound`, so no handler can forget to.
  static DwCallHandler
  single<Q extends DwSingleRequest<T>, T extends DwDataObject>({
    required DwAccessRule access,
    int? maxBodyBytes,
    required Future<T?> Function(DwCallContext ctx, Q request) handle,
  }) => DwSingleHandler<Q, T>._(access, maxBodyBytes, handle);

  /// A maybe request: `null` is an answer.
  static DwCallHandler
  maybe<Q extends DwMaybeRequest<T>, T extends DwDataObject>({
    required DwAccessRule access,
    int? maxBodyBytes,
    required Future<T?> Function(DwCallContext ctx, Q request) handle,
  }) => DwMaybeHandler<Q, T>._(access, maxBodyBytes, handle);

  /// A list request: the whole list.
  static DwCallHandler
  list<Q extends DwListRequest<T>, T extends DwDataObject>({
    required DwAccessRule access,
    int? maxBodyBytes,
    required Future<List<T>> Function(DwCallContext ctx, Q request) handle,
  }) => DwListHandler<Q, T>._(access, maxBodyBytes, handle);

  /// A page request. [handle] reads up to `page.fetchLimit` rows after
  /// `page.offset` in the request's total order; the framework trims the
  /// extra row and sets `hasMore`.
  static DwCallHandler
  page<Q extends DwPageRequest<T>, T extends DwDataObject>({
    required DwAccessRule access,
    int? maxBodyBytes,
    required Future<List<T>> Function(
      DwCallContext ctx,
      Q request,
      DwPageInput page,
    )
    handle,
  }) => DwPageHandler<Q, T>._(access, maxBodyBytes, handle);

  /// A table request: numbered pages with a total.
  ///
  /// [rows] reads up to `table.fetchLimit` rows after `table.offset`; [count]
  /// counts every row the request matches. The framework asks [count] only
  /// when the rows cannot tell the total: when the page is full (more may
  /// follow), or empty past the first page. A short page is the last one, and
  /// its total is `offset + rows` — so the common small table costs one
  /// query, and a handler cannot return a total that disagrees with its rows.
  static DwCallHandler
  table<Q extends DwTableRequest<T>, T extends DwDataObject>({
    required DwAccessRule access,
    int? maxBodyBytes,
    required Future<List<T>> Function(
      DwCallContext ctx,
      Q request,
      DwTableInput table,
    )
    rows,
    required Future<int> Function(DwCallContext ctx, Q request) count,
  }) => DwTableHandler<Q, T>._(access, maxBodyBytes, rows, count);

  /// A window request, newest first.
  ///
  /// The request class names a row's place in the sequence
  /// (`DwWindowRequest.positionOf`): its sort value [S] (`int`, `String` or
  /// `DateTime`) and its id [I] (`int` or `String`) — what cursors are built
  /// from, and what a cursor from the client must decode to, or the call is
  /// malformed. The client orders live inserts by the same definition, so it
  /// is written once, on the shared class. [handle] reads one direction (see
  /// [DwWindowInput]); the framework composes the window and sets the
  /// cursors. Around an anchor it reads newer rows for half the page, then
  /// the anchor and older rows for the rest — the whole rest when newer rows
  /// run short, since an anchor is usually the first unread row near the
  /// newest; only when older rows run short does a third read let newer rows
  /// fill the page.
  static DwCallHandler window<
    Q extends DwWindowRequest<T, S, I>,
    T extends DwDataObject,
    S extends Object,
    I extends Object
  >({
    required DwAccessRule access,
    int? maxBodyBytes,
    required Future<List<T>> Function(
      DwCallContext ctx,
      Q request,
      DwWindowInput<S, I> window,
    )
    handle,
  }) => DwWindowHandler<Q, T, S, I>._(access, maxBodyBytes, handle);

  /// A command. [transactional] (the default) runs the handler, its access
  /// check and its idempotency record in one database transaction; set it to
  /// `false` for handlers that call external services, which then open their
  /// own `ctx.transaction` where they write.
  static DwCallHandler command<C extends DwActionCommand<R>, R>({
    required DwAccessRule access,
    bool transactional = true,
    int? maxBodyBytes,
    required Future<R> Function(DwCallContext ctx, C command) handle,
  }) => DwCommandHandler<C, R>._(
    access,
    maxBodyBytes,
    transactional,
    handle,
    recordsSuccess: true,
  );
}

/// A handler of a request kind: runs with the page query of its kind and
/// answers the encoded result.
@internal
sealed class DwRequestHandler extends DwCallHandler {
  DwRequestHandler._(super.access, super.maxBodyBytes) : super._();

  /// Turns the page query `DwPageQuery.parse` read for [request] into this
  /// kind's input, before anything runs. Throws [FormatException] for a query
  /// the request cannot mean — a cursor of another sequence: the call is
  /// malformed.
  Object? prepare(DwDataRequest<Object?> request, DwPageQuery? query) => null;

  /// Runs the handler with what [prepare] returned and answers the result
  /// encoded by the request class.
  Future<Object?> run(
    DwCallContext ctx,
    DwDataRequest<Object?> request,
    Object? prepared,
  );
}

@internal
final class DwSingleHandler<
  Q extends DwSingleRequest<T>,
  T extends DwDataObject
>
    extends DwRequestHandler {
  DwSingleHandler._(super.access, super.maxBodyBytes, this._handle) : super._();

  final Future<T?> Function(DwCallContext ctx, Q request) _handle;

  @override
  Type get callType => Q;

  @override
  bool _accessFits() => (access as DwCheckAccess)._fits<Q>();

  @override
  Future<Object?> run(ctx, request, prepared) async {
    final typed = request as Q;
    final result = await _handle(ctx, typed);
    if (result == null) ctx.refuse(DwCoreRefusal.notFound);
    return typed.encodeResult(result, ctx.protocol);
  }

  @override
  String toString() => 'single($Q)';
}

@internal
final class DwMaybeHandler<Q extends DwMaybeRequest<T>, T extends DwDataObject>
    extends DwRequestHandler {
  DwMaybeHandler._(super.access, super.maxBodyBytes, this._handle) : super._();

  final Future<T?> Function(DwCallContext ctx, Q request) _handle;

  @override
  Type get callType => Q;

  @override
  bool _accessFits() => (access as DwCheckAccess)._fits<Q>();

  @override
  Future<Object?> run(ctx, request, prepared) async {
    final typed = request as Q;
    return typed.encodeResult(await _handle(ctx, typed), ctx.protocol);
  }

  @override
  String toString() => 'maybe($Q)';
}

@internal
final class DwListHandler<Q extends DwListRequest<T>, T extends DwDataObject>
    extends DwRequestHandler {
  DwListHandler._(super.access, super.maxBodyBytes, this._handle) : super._();

  final Future<List<T>> Function(DwCallContext ctx, Q request) _handle;

  @override
  Type get callType => Q;

  @override
  bool _accessFits() => (access as DwCheckAccess)._fits<Q>();

  @override
  Future<Object?> run(ctx, request, prepared) async {
    final typed = request as Q;
    return typed.encodeResult(await _handle(ctx, typed), ctx.protocol);
  }

  @override
  String toString() => 'list($Q)';
}

@internal
final class DwPageHandler<Q extends DwPageRequest<T>, T extends DwDataObject>
    extends DwRequestHandler {
  DwPageHandler._(super.access, super.maxBodyBytes, this._handle) : super._();

  final Future<List<T>> Function(DwCallContext ctx, Q request, DwPageInput page)
  _handle;

  @override
  Type get callType => Q;

  @override
  bool _accessFits() => (access as DwCheckAccess)._fits<Q>();

  @override
  DwPageInput prepare(request, query) {
    final offsetQuery = query! as DwOffsetQuery;
    return DwPageInput._(
      offsetQuery.offset,
      (request as Q).servedPageSize(offsetQuery.pageSize),
    );
  }

  @override
  Future<Object?> run(ctx, request, prepared) async {
    final typed = request as Q;
    final input = prepared! as DwPageInput;
    final rows = await _handle(ctx, typed, input);
    _checkLimit(this, rows, input.fetchLimit);
    final hasMore = rows.length > input.pageSize;
    return typed.encodeResult(
      DwPageResult<T>(
        hasMore ? rows.sublist(0, input.pageSize) : rows,
        hasMore: hasMore,
      ),
      ctx.protocol,
    );
  }

  @override
  String toString() => 'page($Q)';
}

@internal
final class DwTableHandler<Q extends DwTableRequest<T>, T extends DwDataObject>
    extends DwRequestHandler {
  DwTableHandler._(super.access, super.maxBodyBytes, this._rows, this._count)
    : super._();

  final Future<List<T>> Function(
    DwCallContext ctx,
    Q request,
    DwTableInput table,
  )
  _rows;
  final Future<int> Function(DwCallContext ctx, Q request) _count;

  @override
  Type get callType => Q;

  @override
  bool _accessFits() => (access as DwCheckAccess)._fits<Q>();

  @override
  DwTableInput prepare(request, query) {
    final typed = request as Q;
    return DwTableInput._(typed.page, typed.servedPageSize);
  }

  @override
  Future<Object?> run(ctx, request, prepared) async {
    final typed = request as Q;
    final input = prepared! as DwTableInput;
    final rows = await _rows(ctx, typed, input);
    _checkLimit(this, rows, input.fetchLimit);
    final full = rows.length > input.pageSize;
    final items = full ? rows.sublist(0, input.pageSize) : rows;
    final int total;
    if (full || (rows.isEmpty && input.page > 1)) {
      final counted = await _count(ctx, typed);
      if (counted < 0) {
        throw StateError('the count of $this is negative ($counted)');
      }
      // The count is a second statement and may see rows come or go; the
      // rows just read exist, so the total is never below them.
      final seen = items.isEmpty ? 0 : input.offset + items.length;
      total = counted < seen ? seen : counted;
    } else {
      total = input.offset + rows.length;
    }
    return typed.encodeResult(
      DwTablePage<T>(
        items,
        total: total,
        page: input.page,
        pageSize: input.pageSize,
      ),
      ctx.protocol,
    );
  }

  @override
  String toString() => 'table($Q)';
}

@internal
final class DwWindowHandler<
  Q extends DwWindowRequest<T, S, I>,
  T extends DwDataObject,
  S extends Object,
  I extends Object
>
    extends DwRequestHandler {
  DwWindowHandler._(super.access, super.maxBodyBytes, this._handle)
    : super._() {
    // Checked when the handler is declared: a cursor of any other type
    // cannot be encoded, and would fail on the first call instead.
    if (S != int && S != String && S != DateTime) {
      throw ArgumentError(
        'The sort value of a window handler for $Q is an int, a String or a '
        'DateTime, not $S',
      );
    }
    if (I != int && I != String) {
      throw ArgumentError(
        'The id of a window handler for $Q is an int or a String, not $I',
      );
    }
  }

  final Future<List<T>> Function(
    DwCallContext ctx,
    Q request,
    DwWindowInput<S, I> window,
  )
  _handle;

  @override
  Type get callType => Q;

  @override
  bool _accessFits() => (access as DwCheckAccess)._fits<Q>();

  /// Reads the position a client cursor names. Throws [FormatException] for a
  /// cursor that is not one of this handler's: the call is malformed.
  DwWindowPosition<S, I> positionOfCursor(String cursor) {
    final decoded = DwWindowCursor.decode(cursor);
    final sortValue = decoded.sortValue;
    final id = decoded.id;
    if (sortValue is! S || id is! I) {
      throw FormatException(
        'The cursor does not name a position of $Q: its sort value is '
        '${sortValue.runtimeType} and its id ${id.runtimeType}',
      );
    }
    return (sortValue: sortValue, id: id);
  }

  Future<List<T>> _read(
    DwCallContext ctx,
    Q request,
    DwWindowInput<S, I> input,
  ) async {
    final rows = await _handle(ctx, request, input);
    _checkLimit(this, rows, input.fetchLimit);
    return rows;
  }

  @override
  Object? prepare(request, query) {
    final windowQuery = query! as DwWindowQuery;
    final cursor = windowQuery.cursor;
    return (
      direction: windowQuery.direction,
      position: cursor == null ? null : positionOfCursor(cursor),
      size: (request as Q).servedPageSize(windowQuery.pageSize),
    );
  }

  @override
  Future<Object?> run(ctx, request, prepared) async {
    final typed = request as Q;
    final (:direction, :position, :size) = prepared! as _WindowPlan<S, I>;

    final List<T> items;
    final bool hasOlder;
    final bool hasNewer;
    if (position == null || direction == DwWindowDirection.older) {
      // The newest rows, or the rows below a cursor.
      final rows = await _read(
        ctx,
        typed,
        DwWindowInput._(DwWindowDirection.older, position, size + 1),
      );
      hasOlder = rows.length > size;
      items = hasOlder ? rows.sublist(0, size) : rows;
      // Rows at and above a cursor exist: the client holds them. Asking the
      // database again would cost a query to learn what the caller knows.
      hasNewer = position != null;
    } else if (direction == DwWindowDirection.newer) {
      final rows = await _read(
        ctx,
        typed,
        DwWindowInput._(DwWindowDirection.newer, position, size + 1),
      );
      hasNewer = rows.length > size;
      items = (hasNewer ? rows.sublist(0, size) : rows).reversed.toList();
      // As above: the client holds the rows at and below its cursor.
      hasOlder = true;
    } else {
      // Around an anchor: newer rows for half the page, the anchor and older
      // rows for the rest.
      final newerWanted = size ~/ 2;
      var newerRows = await _read(
        ctx,
        typed,
        DwWindowInput._(DwWindowDirection.newer, position, newerWanted + 1),
      );
      final olderWanted =
          size -
          (newerRows.length < newerWanted ? newerRows.length : newerWanted);
      final olderRows = await _read(
        ctx,
        typed,
        DwWindowInput._(
          DwWindowDirection.older,
          position,
          olderWanted + 1,
          includesPosition: true,
        ),
      );
      hasOlder = olderRows.length > olderWanted;
      final older = hasOlder ? olderRows.sublist(0, olderWanted) : olderRows;
      // Older rows ran short while newer ones remain: the anchor is near the
      // oldest end, and newer rows fill the page — one more read, only then.
      final newerRoom = size - older.length;
      if (newerRows.length > newerWanted && newerRoom > newerWanted) {
        newerRows = await _read(
          ctx,
          typed,
          DwWindowInput._(DwWindowDirection.newer, position, newerRoom + 1),
        );
      }
      final newer = newerRows.length > newerRoom
          ? newerRows.sublist(0, newerRoom)
          : newerRows;
      hasNewer = newerRows.length > newer.length;
      items = [...newer.reversed, ...older];
    }
    if (items.isEmpty) {
      return typed.encodeResult(DwWindowResult<T>(const []), ctx.protocol);
    }
    return typed.encodeResult(
      DwWindowResult<T>(
        items,
        olderCursor: hasOlder ? typed.cursorOf(items.last) : null,
        newerCursor: hasNewer ? typed.cursorOf(items.first) : null,
      ),
      ctx.protocol,
    );
  }

  @override
  String toString() => 'window($Q)';
}

/// What a window call reads, known before anything runs.
typedef _WindowPlan<S extends Object, I extends Object> = ({
  DwWindowDirection direction,
  DwWindowPosition<S, I>? position,
  int size,
});

/// The command handler, with what the dispatcher needs to run it.
@internal
final class DwCommandHandler<C extends DwActionCommand<R>, R>
    extends DwCallHandler {
  DwCommandHandler._(
    super.access,
    super.maxBodyBytes,
    this.transactional,
    this._handle, {
    required this.recordsSuccess,
  }) : super._();

  final bool transactional;

  /// Whether a successful outcome is stored for idempotency. Off only for a
  /// framework command whose result is a secret (the session token), which
  /// must never sit in the outcome table.
  final bool recordsSuccess;

  final Future<R> Function(DwCallContext ctx, C command) _handle;

  @override
  Type get callType => C;

  @override
  bool _accessFits() => (access as DwCheckAccess)._fits<C>();

  /// Runs the handler and encodes its result with the command class.
  Future<Object?> run(
    DwCallContext ctx,
    DwActionCommand<Object?> command,
  ) async {
    final typed = command as C;
    return typed.encodeResult(await _handle(ctx, typed), ctx.protocol);
  }

  @override
  String toString() => 'command($C)';
}

/// A framework command handler that does not store its successful outcome.
@internal
DwCallHandler dwSecretResultCommand<C extends DwActionCommand<R>, R>({
  required DwAccessRule access,
  required bool transactional,
  required Future<R> Function(DwCallContext ctx, C command) handle,
}) => DwCommandHandler<C, R>._(
  access,
  null,
  transactional,
  handle,
  recordsSuccess: false,
);

/// A handler that reads more rows than it was asked for reads a table where
/// it should read a page: loud, not trimmed.
void _checkLimit(DwCallHandler handler, List<Object?> rows, int fetchLimit) {
  if (rows.length > fetchLimit) {
    throw StateError(
      '$handler returned ${rows.length} rows; it was asked for at most '
      '$fetchLimit',
    );
  }
}
