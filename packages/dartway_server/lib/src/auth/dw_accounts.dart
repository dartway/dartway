import 'dart:async';

import 'package:dartway_core/dartway_core.dart';
import 'package:dartway_orm/dartway_orm.dart';
import 'package:meta/meta.dart';

import '../alerts/dw_logger.dart';
import '../channels/dw_hub.dart';
import '../context/dw_context.dart';
import '../handlers/dw_handler.dart';
import '../jobs/dw_jobs.dart';
import '../server/dw_runtime.dart';
import 'dw_auth.dart';

/// The outcome of [DwAccounts.ensure].
typedef DwEnsuredAccount = ({int accountId, bool created});

/// Accounts by identifier, for code that is not a sign-in: seeding a
/// development database, creating or promoting an admin at startup, revoking
/// someone's sessions from an admin command.
///
/// Three ways to get one, by where the code runs:
///
/// - `ctx.accounts` in a handler, job or route: its writes join the call's
///   transaction, and the sessions it revokes close after that commits;
/// - `server.accounts` next to a running server (a startup bootstrap);
/// - [DwAccounts.new] over a bare database, where no server runs in this
///   process (a seed script).
final class DwAccounts {
  /// Accounts over [db] with no server in this process.
  ///
  /// `DwAuth.onAccountCreated` gets a context bound to the transaction that
  /// creates the account; with no server behind it, its `publish`, `revoke`
  /// and `jobs` throw rather than drop what they are given. [revokeKeys]
  /// writes the database only: connections a server holds elsewhere stay
  /// signed in until they reconnect — inside a server, use `ctx.accounts` or
  /// `server.accounts`, which close them.
  DwAccounts(DwDb db, DwAuth auth) : this._(auth, _DetachedScope(db, auth));

  DwAccounts._(this._auth, this._scope);

  /// Bound to a call: the call's database and effects.
  @internal
  DwAccounts.ofContext(DwCallContext ctx, DwAuth auth, DwHub hub)
    : this._(auth, _ContextScope(ctx, hub));

  /// Bound to a running server, outside any call.
  @internal
  DwAccounts.ofRuntime(DwRuntime runtime)
    : this._(runtime.auth, _RuntimeScope(runtime));

  final DwAuth _auth;
  final _Scope _scope;

  /// The account of an identifier, created when it has none.
  ///
  /// [rawIdentifier] is normalized with `DwAuth.normalize`; an identifier it
  /// rejects throws [ArgumentError] — a bootstrap with a mistyped admin phone
  /// must not start quietly without its admin. A new account gets its
  /// identity and runs `DwAuth.onAccountCreated` (with an empty registration)
  /// in one transaction, under the per-identifier lock sign-in takes, so a
  /// sign-in racing an `ensure` makes one account, not two.
  Future<DwEnsuredAccount> ensure(
    DwIdentifierKind kind,
    String rawIdentifier,
  ) async {
    final identifier = _normalize(kind, rawIdentifier);
    // The common case — the admin exists since the first start — costs one
    // query instead of a transaction and a lock.
    final existing = await _scope.direct(
      (db, _) => _accountOf(db, kind, identifier),
    );
    if (existing != null) return (accountId: existing, created: false);
    return _scope.transaction(
      (ctx) => dwEnsureAccount(ctx, _auth, kind, identifier, const {}),
    );
  }

  /// The account of an identifier, or `null` when it has none. An identifier
  /// `DwAuth.normalize` rejects throws [ArgumentError], as in [ensure].
  Future<int?> find(DwIdentifierKind kind, String rawIdentifier) {
    final identifier = _normalize(kind, rawIdentifier);
    return _scope.direct((db, _) => _accountOf(db, kind, identifier));
  }

  /// Revokes every session key of [accountId]. Bound to a server, each
  /// connection holding one of them loses its subscriptions and is told its
  /// session was rejected — as after a sign-out on another device.
  Future<void> revokeKeys(int accountId) => _scope.direct((db, closed) async {
    final rows = await db.query(
      'UPDATE dw_auth_key SET revoked_at = now() '
      'WHERE account_id = @account AND revoked_at IS NULL RETURNING id',
      params: {'account': accountId},
    );
    for (final row in rows) {
      closed(row.get<int>('id'));
    }
  });

  String _normalize(DwIdentifierKind kind, String raw) =>
      _auth.normalize(kind, raw) ??
      (throw ArgumentError.value(
        raw,
        'rawIdentifier',
        'not a valid ${kind.name} identifier for DwAuth.normalize',
      ));

  static Future<int?> _accountOf(
    DwDb db,
    DwIdentifierKind kind,
    String identifier,
  ) async {
    final rows = await db.query(
      'SELECT account_id FROM dw_identity WHERE kind = @kind AND value = @value',
      params: {'kind': kind.name, 'value': identifier},
    );
    return rows.isEmpty ? null : rows.single.get<int>('account_id');
  }
}

/// Finds or creates the account of a normalized [identifier] — the one place
/// accounts are made, shared by sign-in and [DwAccounts.ensure].
///
/// Must run inside a transaction on `ctx.db`: the lock is transaction-scoped
/// and the account, its identity and `onAccountCreated` commit together.
@internal
Future<DwEnsuredAccount> dwEnsureAccount(
  DwContext ctx,
  DwAuth auth,
  DwIdentifierKind kind,
  String identifier,
  Map<String, String> registration,
) async {
  final db = ctx.db;
  if (!db.inTransaction) {
    throw StateError('dwEnsureAccount needs a transaction');
  }
  // Two first sign-ins of one identifier at once must create one account.
  await db.advisoryLock(
    DwLockSpace.identifier,
    dwLockKey('${kind.name}:$identifier'),
  );
  final existing = await DwAccounts._accountOf(db, kind, identifier);
  if (existing != null) return (accountId: existing, created: false);
  final accountId = (await db.query(
    'INSERT INTO dw_account DEFAULT VALUES RETURNING id',
  )).single.get<int>('id');
  await db.execute(
    'INSERT INTO dw_identity (account_id, kind, value) '
    'VALUES (@account, @kind, @value)',
    params: {'account': accountId, 'kind': kind.name, 'value': identifier},
  );
  await auth.onAccountCreated?.call(
    ctx,
    accountId,
    kind,
    identifier,
    registration,
  );
  return (accountId: accountId, created: true);
}

/// Where [DwAccounts] reads and writes, and what closing a session means
/// there.
sealed class _Scope {
  /// Runs [body] in a transaction (a savepoint inside one) with a context
  /// whose database is that transaction.
  Future<T> transaction<T>(Future<T> Function(DwContext ctx) body);

  /// Runs [body] on the scope's database as it is. `closeSessions` closes the
  /// live sessions of a key revoked through that database, once what it wrote
  /// has committed.
  Future<T> direct<T>(
    Future<T> Function(DwDb db, void Function(int keyId) closeSessions) body,
  );
}

final class _ContextScope extends _Scope {
  _ContextScope(this.ctx, this.hub);

  final DwCallContext ctx;
  final DwHub hub;

  @override
  Future<T> transaction<T>(Future<T> Function(DwContext ctx) body) =>
      ctx.transaction((_) => body(ctx));

  @override
  Future<T> direct<T>(
    Future<T> Function(DwDb db, void Function(int keyId) closeSessions) body,
  ) => body(
    ctx.db,
    // An effect of the call: delivered after its transaction commits, dropped
    // if it rolls back.
    (keyId) => ctx.afterCommit(() => hub.revokeKey(keyId)),
  );
}

final class _RuntimeScope extends _Scope {
  _RuntimeScope(this.runtime);

  final DwRuntime runtime;

  @override
  Future<T> transaction<T>(Future<T> Function(DwContext ctx) body) async {
    final ctx = runtime.context(scope: 'accounts');
    try {
      return await ctx.transaction((_) => body(ctx));
    } finally {
      // What `onAccountCreated` published, delivered once committed.
      runtime.deliver(ctx);
    }
  }

  @override
  Future<T> direct<T>(
    Future<T> Function(DwDb db, void Function(int keyId) closeSessions) body,
  ) =>
      // Outside a transaction every statement has committed when it returns.
      body(runtime.db, runtime.hub.revokeKey);
}

final class _DetachedScope extends _Scope {
  _DetachedScope(this.db, this.auth);

  final DwDb db;
  final DwAuth auth;

  @override
  Future<T> transaction<T>(Future<T> Function(DwContext ctx) body) =>
      db.transaction((tx) => body(_DetachedContext(tx, auth)));

  @override
  Future<T> direct<T>(
    Future<T> Function(DwDb db, void Function(int keyId) closeSessions) body,
  ) => body(db, (_) {});
}

/// The context of [DwAccounts.new]: a database and nothing a server provides.
final class _DetachedContext extends DwContext {
  _DetachedContext(this._root, this._auth);

  final DwDb _root;
  final DwAuth _auth;
  final Map<Object, Object?> _memo = {};
  final Object _zoneKey = Object();

  /// The innermost transaction of [transaction], as in a server's context.
  @override
  DwDb get db => (Zone.current[_zoneKey] as DwDb?) ?? _root;

  static Never _noServer(String what) => throw StateError(
    '$what needs a running server; this context belongs to DwAccounts over a '
    'bare database. Use server.accounts or ctx.accounts instead.',
  );

  @override
  int? get accountId => null;

  @override
  int get requireAccountId => throw const DwNotAuthenticatedException();

  @override
  DwProtocol get protocol => _noServer('protocol');

  @override
  DwJobs get jobs => _noServer('jobs');

  @override
  DwLogger get log => const DwStdLogger(scope: 'accounts');

  @override
  DwAccounts get accounts => DwAccounts(db, _auth);

  @override
  Future<T> transaction<T>(Future<T> Function(DwDb tx) body) => db.transaction(
    (tx) => runZoned(() => body(tx), zoneValues: {_zoneKey: tx}),
  );

  @override
  void publish(DwChannel channel, DwDto item) => _noServer('publish');

  @override
  void revoke(DwChannel channel, int accountId) => _noServer('revoke');

  @override
  Never refuse(
    DwRefusalCode code, {
    Map<String, Object?> params = const {},
    String? field,
  }) => throw DwRefusalException(DwRefusal(code, params: params, field: field));

  @override
  T memo<T>(Object key, T Function() create) {
    if (_memo.containsKey(key)) return _memo[key] as T;
    final value = create();
    _memo[key] = value;
    return value;
  }
}
