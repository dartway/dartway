import 'package:dartway_core/dartway_core.dart';
import 'package:meta/meta.dart';

import '../context/dw_context.dart';

/// A DTO that can check its own input.
///
/// The server runs [validate] before the handler and answers the first
/// refusal. It belongs in `dartway_core` — the client must run the same code
/// before sending — and lives here only until the core exposes it.
abstract interface class DwValidatable {
  /// Every problem with the input; empty when the input is acceptable.
  List<DwRefusal> validate();
}

/// Thrown when a call needs a signed-in account and the connection has none.
/// The framework answers `DwNotAuthenticated`.
final class DwNotAuthenticatedException implements Exception {
  const DwNotAuthenticatedException();

  @override
  String toString() => 'DwNotAuthenticatedException';
}

/// Who may make a call. Required on every handler: there is no default, so a
/// handler cannot be open by omission.
sealed class DwAccess {
  const DwAccess();

  /// Anyone, including a connection without a session.
  static const DwAccess anonymous = DwAnonymousAccess._();

  /// Any signed-in account.
  static const DwAccess signedIn = DwSignedInAccess._();

  /// A signed-in account for which [check] is true; otherwise `dw.forbidden`.
  /// The check runs after validation, in the handler's context (inside the
  /// transaction of a transactional command).
  const factory DwAccess.check(Future<bool> Function(DwContext ctx) check) =
      DwCheckAccess;
}

final class DwAnonymousAccess extends DwAccess {
  const DwAnonymousAccess._();
}

final class DwSignedInAccess extends DwAccess {
  const DwSignedInAccess._();
}

final class DwCheckAccess extends DwAccess {
  const DwCheckAccess(this.check);

  final Future<bool> Function(DwContext ctx) check;
}

/// Which page a paginated handler must read.
final class DwPageInput {
  const DwPageInput._({
    required this.pageSize,
    required this.offset,
    required this.before,
  });

  /// Rows per page, from the request class.
  final int pageSize;

  /// Rows to skip (offset requests); 0 for cursor requests.
  final int offset;

  /// The id of the oldest loaded object (cursor requests); `null` for the
  /// newest page and for offset requests.
  final Object? before;

  /// How many rows to read: one past the page, so the framework learns
  /// whether another page exists without counting.
  int get fetchLimit => pageSize + 1;
}

@internal
DwPageInput dwPageInput({
  required int pageSize,
  required int offset,
  required Object? before,
}) => DwPageInput._(pageSize: pageSize, offset: offset, before: before);

/// A server handler for one request or command type.
///
/// Built only through [request], [page] and [command]; the registry passed to
/// `DwServer` must hold exactly one handler per request and command type.
sealed class DwHandler {
  const DwHandler._(this.type, this.access);

  /// The request or command class this handler answers.
  final Type type;
  final DwAccess access;

  /// A request answered with one value of its result type — single, maybe
  /// and list requests. A single request whose object is absent refuses with
  /// `ctx.refuse(DwCoreRefusal.notFound)`.
  static DwHandler request<Q extends DwRequest<R>, R>({
    required DwAccess access,
    required Future<R> Function(DwContext ctx, Q request) handle,
  }) => DwRequestHandler<Q, R>._(access, handle);

  /// A paginated request (`DwPageRequest` or `DwCursorRequest`). The handler
  /// reads up to `page.fetchLimit` rows in the request's order (newest first
  /// for cursor requests) and returns them; the framework trims the extra row
  /// and sets `hasMore`.
  static DwHandler
  page<Q extends DwRequest<DwPage<T>>, T extends DwDataObject>({
    required DwAccess access,
    required Future<List<T>> Function(
      DwContext ctx,
      Q request,
      DwPageInput page,
    )
    handle,
  }) => DwPageHandler<Q, T>._(access, handle);

  /// A command. [transactional] (the default) runs the handler, its access
  /// check and its idempotency record in one database transaction; set it to
  /// `false` for handlers that call external services, which then open their
  /// own `ctx.transaction` where they write.
  static DwHandler command<C extends DwCommand<R>, R>({
    required DwAccess access,
    bool transactional = true,
    required Future<R> Function(DwContext ctx, C command) handle,
  }) => DwCommandHandler<C, R>._(access, transactional, handle, true);
}

final class DwRequestHandler<Q extends DwRequest<R>, R> extends DwHandler {
  DwRequestHandler._(DwAccess access, this._handle) : super._(Q, access);

  /// Whether [Q] is paginated — then it needs `DwHandler.page`, which the
  /// type system cannot demand of `DwHandler.request`.
  bool get isForPagedRequest =>
      <Q>[] is List<DwPageRequest<DwDataObject>> ||
      <Q>[] is List<DwCursorRequest<DwDataObject>>;

  final Future<R> Function(DwContext ctx, Q request) _handle;

  /// Runs the handler and encodes its result with the request class.
  Future<Object?> run(DwContext ctx, DwRequest<Object?> request) async {
    final typed = request as Q;
    final result = await _handle(ctx, typed);
    return typed.encodeResult(result, ctx.protocol);
  }
}

final class DwPageHandler<
  Q extends DwRequest<DwPage<T>>,
  T extends DwDataObject
>
    extends DwHandler {
  DwPageHandler._(DwAccess access, this._handle) : super._(Q, access);

  final Future<List<T>> Function(DwContext ctx, Q request, DwPageInput page)
  _handle;

  Future<Object?> run(
    DwContext ctx,
    DwRequest<Object?> request,
    DwPageInput page,
  ) async {
    final typed = request as Q;
    final rows = await _handle(ctx, typed, page);
    final hasMore = rows.length > page.pageSize;
    final items = hasMore ? rows.sublist(0, page.pageSize) : rows;
    return typed.encodeResult(DwPage<T>(items, hasMore: hasMore), ctx.protocol);
  }
}

final class DwCommandHandler<C extends DwCommand<R>, R> extends DwHandler {
  DwCommandHandler._(
    DwAccess access,
    this.transactional,
    this._handle,
    this.recordsSuccess,
  ) : super._(C, access);

  final bool transactional;

  /// Whether a successful outcome is stored for idempotency. Off only for a
  /// framework command whose result is a secret (the session token), which
  /// must never sit in the outcome table.
  final bool recordsSuccess;

  final Future<R> Function(DwContext ctx, C command) _handle;

  Future<Object?> run(DwContext ctx, DwCommand<Object?> command) async {
    final typed = command as C;
    final result = await _handle(ctx, typed);
    return typed.encodeResult(result, ctx.protocol);
  }
}

/// A framework command handler that does not store its successful outcome.
@internal
DwHandler dwSecretResultCommand<C extends DwCommand<R>, R>({
  required DwAccess access,
  required bool transactional,
  required Future<R> Function(DwContext ctx, C command) handle,
}) => DwCommandHandler<C, R>._(access, transactional, handle, false);

/// The page size a paginated request declares.
@internal
int? dwPageSizeOf(DwRequest<Object?> request) => switch (request) {
  DwPageRequest(:final pageSize) => pageSize,
  DwCursorRequest(:final pageSize) => pageSize,
  _ => null,
};
