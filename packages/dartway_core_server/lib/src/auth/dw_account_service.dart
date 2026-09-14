import 'dart:async';

import 'package:dartway_core_shared/dartway_core_shared.dart';
import 'package:dartway_orm/dartway_orm.dart';
import 'package:meta/meta.dart';

import '../alerts/dw_server_logger.dart';
import '../context/dw_call_context.dart';
import '../jobs/dw_job_queue.dart';
import '../server/dw_runtime.dart';
import 'dw_auth_config.dart';

/// The outcome of [DwAccountService.ensure].
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
/// - [DwAccountService.new] over a bare database, where no server runs in
///   this process (a seed script).
final class DwAccountService {
  /// Accounts over [db] with no server in this process.
  ///
  /// `DwAuthConfig.onAccountCreated` gets a context bound to the transaction
  /// that creates the account; with no server behind it, its `publish`,
  /// `revoke` and `jobs` throw rather than drop what they are given (D-022).
  /// [revokeKeys] writes the database only: a running server notices within
  /// its `DwServerSettings.tokenCacheTtl` — inside a server, use
  /// `ctx.accounts` or `server.accounts`, which take effect at once.
  DwAccountService(DwDatabaseHandle db, DwAuthConfig auth)
    : this._(auth, _DetachedScope(db, auth));

  DwAccountService._(this._auth, this._scope);

  /// Bound to a call: the call's database and effects.
  @internal
  DwAccountService.ofContext(DwRuntimeContext ctx, DwRuntime runtime)
    : this._(runtime.auth, _ContextScope(ctx));

  /// Bound to a running server, outside any call.
  @internal
  DwAccountService.ofRuntime(DwRuntime runtime)
    : this._(runtime.auth, _RuntimeScope(runtime));

  final DwAuthConfig _auth;
  final _Scope _scope;

  /// The account of an identifier, created when it has none.
  ///
  /// [rawIdentifier] is normalized with `DwAuthConfig.normalize`; an
  /// identifier it rejects throws [ArgumentError] — a bootstrap with a
  /// mistyped admin phone must not start quietly without its admin. A new
  /// account gets its identity and runs `DwAuthConfig.onAccountCreated` (with
  /// an empty registration) in one transaction, under the per-identifier lock
  /// sign-in takes, so a sign-in racing an `ensure` makes one account, not
  /// two.
  Future<DwEnsuredAccount> ensure(
    DwIdentifierKind kind,
    String rawIdentifier,
  ) async {
    final identifier = _normalize(kind, rawIdentifier);
    // The common case — the admin exists since the first start — costs one
    // query instead of a transaction and a lock.
    final existing = await _scope.direct(
      (db, _) => dwAccountOf(db, kind, identifier),
    );
    if (existing != null) return (accountId: existing, created: false);
    return _scope.transaction(
      (ctx) => dwEnsureAccount(ctx, _auth, kind, identifier, const {}),
    );
  }

  /// The account of an identifier, or `null` when it has none. An identifier
  /// `DwAuthConfig.normalize` rejects throws [ArgumentError], as in [ensure].
  Future<int?> find(DwIdentifierKind kind, String rawIdentifier) {
    final identifier = _normalize(kind, rawIdentifier);
    return _scope.direct((db, _) => dwAccountOf(db, kind, identifier));
  }

  /// Revokes every session key of [accountId]. Bound to a server, each call
  /// with one of them is unauthenticated from then on, and each live
  /// connection holding one loses its subscriptions and is told its session
  /// was rejected — as after a sign-out on another device.
  Future<void> revokeKeys(int accountId) {
    // Checked before the write: a revocation whose delivery is refused must
    // not have happened.
    _scope.checkRevocation();
    return _revokeKeys(accountId);
  }

  Future<void> _revokeKeys(int accountId) => _scope.direct((db, revoked) async {
    final rows = await db.query(
      'UPDATE dw_auth_key SET revoked_at = now() '
      'WHERE account_id = @account AND revoked_at IS NULL RETURNING id',
      params: {'account': accountId},
    );
    for (final row in rows) {
      revoked(row.get<int>('id'));
    }
  });

  String _normalize(DwIdentifierKind kind, String raw) =>
      _auth.normalize(kind, raw) ??
      (throw ArgumentError.value(
        raw,
        'rawIdentifier',
        'not a valid ${kind.name} identifier for DwAuthConfig.normalize',
      ));
}

@internal
Future<int?> dwAccountOf(
  DwDatabaseHandle db,
  DwIdentifierKind kind,
  String identifier,
) async {
  final rows = await db.query(
    'SELECT account_id FROM dw_identity WHERE kind = @kind AND value = @value',
    params: {'kind': kind.name, 'value': identifier},
  );
  return rows.isEmpty ? null : rows.single.get<int>('account_id');
}

/// Finds or creates the account of a normalized [identifier] — the one place
/// accounts are made, shared by sign-in and [DwAccountService.ensure].
///
/// Must run inside a transaction on `ctx.db`: the lock is transaction-scoped
/// and the account, its identity and `onAccountCreated` commit together.
@internal
Future<DwEnsuredAccount> dwEnsureAccount(
  DwCallContext ctx,
  DwAuthConfig auth,
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
  final existing = await dwAccountOf(db, kind, identifier);
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

/// Where [DwAccountService] reads and writes, and what revoking a session key
/// means there.
sealed class _Scope {
  /// Runs [body] in a transaction (a savepoint inside one) with a context
  /// whose database is that transaction.
  Future<T> transaction<T>(Future<T> Function(DwCallContext ctx) body);

  /// Runs [body] on the scope's database as it is. `revoked` reports a key
  /// revoked through that database, to take effect once what it wrote has
  /// committed.
  Future<T> direct<T>(
    Future<T> Function(DwDatabaseHandle db, void Function(int keyId) revoked)
    body,
  );

  /// Throws when sessions cannot be revoked from here.
  void checkRevocation() {}
}

final class _ContextScope extends _Scope {
  _ContextScope(this.ctx);

  final DwRuntimeContext ctx;

  @override
  void checkRevocation() => ctx.requireSideEffects('revokeKeys');

  @override
  Future<T> transaction<T>(Future<T> Function(DwCallContext ctx) body) =>
      ctx.transaction((_) => body(ctx));

  @override
  Future<T> direct<T>(
    Future<T> Function(DwDatabaseHandle db, void Function(int keyId) revoked)
    body,
  ) =>
      // An effect of the call: delivered after its transaction commits,
      // dropped if it rolls back.
      body(ctx.db, ctx.revokedKey);
}

final class _RuntimeScope extends _Scope {
  _RuntimeScope(this.runtime);

  final DwRuntime runtime;

  @override
  Future<T> transaction<T>(Future<T> Function(DwCallContext ctx) body) async {
    final ctx = runtime.context(
      scope: 'accounts',
      kind: DwContextKind.background,
    );
    try {
      return await ctx.transaction((_) => body(ctx));
    } finally {
      // What `onAccountCreated` published, delivered once committed.
      runtime.deliver(ctx);
    }
  }

  @override
  Future<T> direct<T>(
    Future<T> Function(DwDatabaseHandle db, void Function(int keyId) revoked)
    body,
  ) =>
      // Outside a transaction every statement has committed when it returns.
      body(runtime.db, runtime.revokeKey);
}

final class _DetachedScope extends _Scope {
  _DetachedScope(this.db, this.auth);

  final DwDatabaseHandle db;
  final DwAuthConfig auth;

  @override
  Future<T> transaction<T>(Future<T> Function(DwCallContext ctx) body) =>
      db.transaction((tx) => body(_DetachedContext(tx, auth)));

  @override
  Future<T> direct<T>(
    Future<T> Function(DwDatabaseHandle db, void Function(int keyId) revoked)
    body,
  ) => body(db, (_) {});
}

/// The context of [DwAccountService.new]: a database and nothing a server
/// provides.
final class _DetachedContext extends DwCallContext {
  _DetachedContext(this._root, this._auth);

  final DwDatabaseHandle _root;
  final DwAuthConfig _auth;
  final Map<Object, Object?> _memo = {};
  final Object _zoneKey = Object();

  /// The innermost transaction of [transaction], as in a server's context.
  @override
  DwDatabaseHandle get db =>
      (Zone.current[_zoneKey] as DwDatabaseHandle?) ?? _root;

  static Never _noServer(String what) => throw StateError(
    '$what needs a running server; this context belongs to DwAccountService '
    'over a bare database. Use server.accounts or ctx.accounts instead.',
  );

  @override
  int? get accountId => null;

  @override
  int get requireAccountId => throw const DwNotAuthenticatedException();

  @override
  DwWireProtocol get protocol => _noServer('protocol');

  @override
  DwJobQueue get jobs => _noServer('jobs');

  @override
  DwServerLogger get log => const DwConsoleLogger(scope: 'accounts');

  @override
  DwAccountService get accounts => DwAccountService(db, _auth);

  @override
  Future<T> transaction<T>(Future<T> Function(DwDatabaseHandle tx) body) =>
      db.transaction(
        (tx) => runZoned(() => body(tx), zoneValues: {_zoneKey: tx}),
      );

  @override
  void publish(DwLiveChannel channel, DwWireObject item) =>
      _noServer('publish');

  @override
  void revoke(DwLiveChannel channel, int accountId) => _noServer('revoke');

  @override
  Never refuse(
    DwRefusalCode code, {
    Map<String, Object?> params = const {},
    String? field,
  }) => throw DwRefusalException(
    DwCallRefusal(code, params: params, field: field),
  );

  @override
  T memo<T>(Object key, T Function() create) {
    if (_memo.containsKey(key)) return _memo[key] as T;
    final value = create();
    _memo[key] = value;
    return value;
  }
}
