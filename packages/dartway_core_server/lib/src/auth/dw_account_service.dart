import 'dart:async';

import 'package:dartway_core_shared/dartway_core_shared.dart';
import 'package:dartway_orm/dartway_orm.dart';
import 'package:meta/meta.dart';

import '../alerts/dw_server_logger.dart';
import '../context/dw_call_context.dart';
import '../files/dw_file_service.dart';
import '../jobs/dw_job_queue.dart';
import '../server/dw_runtime.dart';
import '../server/dw_server_module.dart';
import 'dw_auth_config.dart';
import 'dw_auth_store.dart';

/// The outcome of [DwAccountService.ensure].
typedef DwEnsuredAccount = ({int accountId, bool created});

/// A session key just made by [DwAccountService.issueKey], with its token.
typedef DwIssuedKey = ({DwSessionKeyInfo key, String token});

/// Accounts, their identifiers and their session keys, for code that is not a
/// sign-in: seeding a development database, creating or promoting an admin at
/// startup, personal access keys, merging two accounts, revoking someone's
/// sessions from an admin command. A project never needs SQL on the
/// framework's `dw_account`, `dw_identity` or `dw_auth_key`.
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
  /// The hooks of `DwAuthConfig` get a context bound to the transaction they
  /// run in; with no server behind it, its `publish`, `revoke` and `jobs`
  /// throw rather than drop what they are given (D-022). [revokeKeys] and
  /// [revokeKey] write the database only: a running server notices within its
  /// `DwServerSettings.tokenCacheTtl` — inside a server, use `ctx.accounts`
  /// or `server.accounts`, which take effect at once.
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

  // --- accounts ---------------------------------------------------------------

  /// The account of an identifier, created when it has none.
  ///
  /// [rawIdentifier] is normalized with `DwAuthConfig.normalize`; an
  /// identifier it rejects throws [ArgumentError] — a bootstrap with a
  /// mistyped admin phone must not start quietly without its admin. A new
  /// account gets its identity (not verified: no code proved it) and runs
  /// `DwAuthConfig.onAccountCreated` with [DwToolOrigin] in one transaction,
  /// under the per-identifier lock sign-in takes, so a sign-in racing an
  /// `ensure` makes one account, not two.
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
      (ctx) => dwEnsureAccount(
        ctx,
        _auth,
        kind,
        identifier,
        const DwAccountOrigin.tool(),
      ),
    );
  }

  /// The account of an identifier, or `null` when it has none. An identifier
  /// `DwAuthConfig.normalize` rejects throws [ArgumentError], as in [ensure].
  Future<int?> find(DwIdentifierKind kind, String rawIdentifier) {
    final identifier = _normalize(kind, rawIdentifier);
    return _scope.direct((db, _) => dwAccountOf(db, kind, identifier));
  }

  // --- identities ---------------------------------------------------------------

  /// The identifiers [accountId] signs in with, oldest first; empty for an
  /// account without any, or no such account.
  Future<List<DwIdentityInfo>> listIdentities(int accountId) async =>
      (await listIdentitiesOf([accountId]))[accountId]!;

  /// The identifiers of every account of [accountIds] in one query — for a
  /// list of profiles, without a query per row. Every account asked for is a
  /// key of the answer, with an empty list when it has no identifiers.
  Future<Map<int, List<DwIdentityInfo>>> listIdentitiesOf(
    Iterable<int> accountIds,
  ) async {
    final ids = accountIds.toSet().toList();
    final found = {for (final id in ids) id: <DwIdentityInfo>[]};
    if (ids.isEmpty) return found;
    final rows = await _scope.direct(
      (db, _) => db.query(
        'SELECT ${DwAuthStore.identityColumns} FROM dw_identity '
        'WHERE account_id = ANY(@ids::int8[]) ORDER BY id',
        params: {'ids': ids},
      ),
    );
    for (final row in rows) {
      final identity = DwAuthStore.identityOf(row);
      found[identity.accountId]!.add(identity);
    }
    return found;
  }

  /// The accounts one of whose identifiers contains [fragment], ignoring
  /// case — an admin's search box. `%`, `_` and `\` in [fragment] match
  /// themselves. [kinds] narrows the identifiers searched; an empty
  /// [fragment] throws [ArgumentError] rather than match every account.
  ///
  /// The identifiers are compared as stored (normalized), so search with the
  /// form `DwAuthConfig.normalize` produces: digits of a phone, a lower-case
  /// e-mail.
  Future<Set<int>> accountsMatching(
    String fragment, {
    Set<DwIdentifierKind>? kinds,
  }) async {
    if (fragment.isEmpty) {
      throw ArgumentError.value(fragment, 'fragment', 'must not be empty');
    }
    final pattern =
        '%${fragment.replaceAllMapped(RegExp(r'[\\%_]'), (m) => '\\${m[0]}')}%';
    final rows = await _scope.direct(
      (db, _) => db.query(
        'SELECT DISTINCT account_id FROM dw_identity WHERE value ILIKE @pattern '
        '${kinds == null ? '' : 'AND kind = ANY(@kinds::text[])'}',
        params: {
          'pattern': pattern,
          if (kinds != null) 'kinds': [for (final kind in kinds) kind.name],
        },
      ),
    );
    return {for (final row in rows) row.get<int>('account_id')};
  }

  /// Moves the identifiers of [fromAccountId] — those of [kinds], or all —
  /// to [toAccountId], for a merge of two accounts. Answers the identities as
  /// moved (their ids unchanged).
  ///
  /// One transaction, under the per-identifier locks sign-in and
  /// `DwConfirmIdentifier` take, so a sign-in with a moving identifier lands
  /// in one account or the other, never in a new one. Identifiers are unique
  /// across accounts, so a move never collides; [toAccountId] may end up with
  /// two identifiers of one kind — choose [kinds] when the merge should keep
  /// the target's own. `DwAuthConfig.onIdentifierChanged` runs for each
  /// identifier on both accounts ([DwIdentifierChangeCause.moved]).
  ///
  /// Revokes nothing: whether the source account's sessions should end is the
  /// merge's decision ([revokeKeys]). Throws [ArgumentError] when the two
  /// accounts are one, or [toAccountId] does not exist.
  Future<List<DwIdentityInfo>> moveIdentities(
    int fromAccountId,
    int toAccountId, {
    Set<DwIdentifierKind>? kinds,
  }) {
    if (fromAccountId == toAccountId) {
      throw ArgumentError.value(
        toAccountId,
        'toAccountId',
        'identifiers move between two different accounts',
      );
    }
    return _scope.transaction((ctx) async {
      final db = ctx.db;
      final target = await db.query(
        'SELECT id FROM dw_account WHERE id = @id FOR SHARE',
        params: {'id': toAccountId},
      );
      if (target.isEmpty) {
        throw ArgumentError.value(
          toAccountId,
          'toAccountId',
          'no such account',
        );
      }
      final moving = await _lockedIdentities(db, fromAccountId, kinds);
      if (moving.isEmpty) return const <DwIdentityInfo>[];
      final moved = [
        for (final row in await db.query(
          'UPDATE dw_identity SET account_id = @to '
          'WHERE id = ANY(@ids::int8[]) AND account_id = @from '
          'RETURNING ${DwAuthStore.identityColumns}',
          params: {
            'to': toAccountId,
            'from': fromAccountId,
            'ids': [for (final identity in moving) identity.id],
          },
        ))
          DwAuthStore.identityOf(row),
      ]..sort((a, b) => a.id.compareTo(b.id));
      for (final identity in moved) {
        await _changed(
          ctx,
          DwIdentifierChange(
            accountId: fromAccountId,
            kind: identity.kind,
            cause: DwIdentifierChangeCause.moved,
            previous: identity.value,
          ),
        );
        await _changed(
          ctx,
          DwIdentifierChange(
            accountId: toAccountId,
            kind: identity.kind,
            cause: DwIdentifierChangeCause.moved,
            current: identity.value,
          ),
        );
      }
      return moved;
    });
  }

  /// Removes the identifiers of [accountId] — those of [kinds], or all — and
  /// answers them as they were. A removed identifier is free: a later sign-in
  /// with it makes a new account.
  ///
  /// One transaction under the per-identifier locks;
  /// `DwAuthConfig.onIdentifierChanged` runs for each
  /// ([DwIdentifierChangeCause.removed]). Revokes nothing: keys stay valid
  /// until [revokeKeys].
  Future<List<DwIdentityInfo>> removeIdentities(
    int accountId, {
    Set<DwIdentifierKind>? kinds,
  }) => _scope.transaction((ctx) async {
    final db = ctx.db;
    final removing = await _lockedIdentities(db, accountId, kinds);
    if (removing.isEmpty) return const <DwIdentityInfo>[];
    await db.execute(
      'DELETE FROM dw_identity WHERE id = ANY(@ids::int8[])',
      params: {
        'ids': [for (final identity in removing) identity.id],
      },
    );
    for (final identity in removing) {
      await _changed(
        ctx,
        DwIdentifierChange(
          accountId: accountId,
          kind: identity.kind,
          cause: DwIdentifierChangeCause.removed,
          previous: identity.value,
        ),
      );
    }
    return removing;
  });

  /// The identities of [accountId] (of [kinds]), each identifier locked the
  /// way sign-in locks it, then the rows — read again under the locks, so an
  /// identifier attached meanwhile is either included or not touched.
  Future<List<DwIdentityInfo>> _lockedIdentities(
    DwDatabaseHandle db,
    int accountId,
    Set<DwIdentifierKind>? kinds,
  ) async {
    Future<List<DwIdentityInfo>> read({bool lock = false}) async => [
      for (final row in await db.query(
        'SELECT ${DwAuthStore.identityColumns} FROM dw_identity '
        'WHERE account_id = @account '
        '${kinds == null ? '' : 'AND kind = ANY(@kinds::text[]) '}'
        'ORDER BY id${lock ? ' FOR UPDATE' : ''}',
        params: {
          'account': accountId,
          if (kinds != null) 'kinds': [for (final kind in kinds) kind.name],
        },
      ))
        DwAuthStore.identityOf(row),
    ];
    // In one order for every caller, so two moves over the same identifiers
    // queue instead of deadlocking.
    final keys = {
      for (final identity in await read())
        dwLockKey('${identity.kind.name}:${identity.value}'),
    }.toList()..sort();
    for (final key in keys) {
      await db.advisoryLock(DwLockSpace.identifier, key);
    }
    return read(lock: true);
  }

  Future<void> _changed(DwCallContext ctx, DwIdentifierChange change) async =>
      _auth.onIdentifierChanged?.call(ctx, change);

  // --- session keys -------------------------------------------------------------

  /// Makes a session key of [accountId] and answers it with its token.
  ///
  /// **The token exists only in this answer**: the database keeps its SHA-256,
  /// nothing logs it, and it cannot be read again — hand it to the person once
  /// and let them keep it. When the call is a command, its successful outcome
  /// is therefore not stored for idempotency (a stored outcome would hold the
  /// token): a retried send runs the handler again and makes a second key,
  /// while the first, whose token nobody received, can be listed and revoked.
  ///
  /// [label] is for people choosing which key to revoke — trimmed; empty,
  /// longer than `DwSessionKeyInfo.maxLabelLength` or holding control
  /// characters throws [ArgumentError]. [kind] is [DwSessionKeyKind.personal]
  /// unless the key stands for an app. Throws [ArgumentError] when the account
  /// does not exist.
  Future<DwIssuedKey> issueKey(
    int accountId, {
    required String label,
    DwSessionKeyKind kind = DwSessionKeyKind.personal,
  }) async {
    final checked = DwAuthStore.personalLabel(label);
    final issued = await _scope.direct(
      (db, _) => DwAuthStore.insertKey(
        db,
        accountId: accountId,
        kind: kind,
        label: checked,
      ),
    );
    if (issued == null) {
      throw ArgumentError.value(accountId, 'accountId', 'no such account');
    }
    _scope.madeSecret();
    return issued;
  }

  /// The session keys of [accountId], newest first: live ones, and revoked
  /// ones until the framework's cleanup removes them a day after revocation.
  Future<List<DwSessionKeyInfo>> listKeys(int accountId) async => [
    for (final row in await _scope.direct(
      (db, _) => db.query(
        'SELECT ${DwAuthStore.keyColumns} FROM dw_auth_key '
        'WHERE account_id = @account ORDER BY id DESC',
        params: {'account': accountId},
      ),
    ))
      DwAuthStore.keyOf(row),
  ];

  /// Revokes the session key [keyId]; answers whether a live key was revoked
  /// (`false` for an unknown or already revoked key). With [accountId], only a
  /// key of that account is revoked — pass the caller's account when the key
  /// id came from a client, so nobody revokes a key that is not theirs.
  ///
  /// Bound to a server, the revocation takes effect in this process at once
  /// — after the enclosing transaction commits, in a handler: the next call
  /// with the token is unauthenticated whatever the token cache holds, and
  /// every live connection authenticated with the key loses its subscriptions
  /// and is told its session was rejected, as after a sign-out. Other server
  /// processes notice within their `DwServerSettings.tokenCacheTtl`.
  Future<bool> revokeKey(int keyId, {int? accountId}) {
    // Checked before the write: a revocation whose delivery is refused must
    // not have happened.
    _scope.checkRevocation();
    return _scope.direct((db, revoked) async {
      final rows = await db.query(
        'UPDATE dw_auth_key SET revoked_at = now() '
        'WHERE id = @id AND revoked_at IS NULL '
        'AND (@account::int8 IS NULL OR account_id = @account::int8) '
        'RETURNING id',
        params: {'id': keyId, 'account': accountId},
      );
      if (rows.isEmpty) return false;
      revoked(keyId);
      return true;
    });
  }

  /// Deletes [accountId] and everything the framework keeps for it, and
  /// answers whether it existed.
  ///
  /// In one transaction: `DwAuthConfig.onAccountDeleting` (the project's
  /// rows), the account's stored files (their objects go once it commits),
  /// every session key revoked (its sessions close once it commits), then the
  /// account — identities, keys, code tickets and push devices with it;
  /// analytics keep their events without the account.
  Future<bool> deleteAccount(int accountId) {
    _scope.checkRevocation();
    return _scope.transaction((ctx) async {
      final db = ctx.db;
      final found = await db.query(
        'SELECT id FROM dw_account WHERE id = @id FOR UPDATE',
        params: {'id': accountId},
      );
      if (found.isEmpty) return false;
      await _auth.onAccountDeleting?.call(ctx, accountId);
      final files = await db.query(
        'SELECT id FROM dw_stored_file WHERE account_id = @id',
        params: {'id': accountId},
      );
      for (final file in files) {
        await ctx.files.delete(file.get<int>('id'));
      }
      await _scope.direct((db, revoked) async {
        final keys = await db.query(
          'UPDATE dw_auth_key SET revoked_at = now() '
          'WHERE account_id = @account AND revoked_at IS NULL RETURNING id',
          params: {'account': accountId},
        );
        for (final row in keys) {
          revoked(row.get<int>('id'));
        }
      });
      await db.execute(
        'DELETE FROM dw_account WHERE id = @id',
        params: {'id': accountId},
      );
      return true;
    });
  }

  /// Revokes every session key of [accountId], app and personal alike, with
  /// the effect described in [revokeKey].
  Future<void> revokeKeys(int accountId) {
    _scope.checkRevocation();
    return _scope.direct((db, revoked) async {
      final rows = await db.query(
        'UPDATE dw_auth_key SET revoked_at = now() '
        'WHERE account_id = @account AND revoked_at IS NULL RETURNING id',
        params: {'account': accountId},
      );
      for (final row in rows) {
        revoked(row.get<int>('id'));
      }
    });
  }

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
/// A sign-in ([DwSignInOrigin]) has just proved the identifier, so its
/// identity is marked verified now, new or not; a tool's is not.
///
/// Must run inside a transaction on `ctx.db`: the lock is transaction-scoped
/// and the account, its identity and `onAccountCreated` commit together.
@internal
Future<DwEnsuredAccount> dwEnsureAccount(
  DwCallContext ctx,
  DwAuthConfig auth,
  DwIdentifierKind kind,
  String identifier,
  DwAccountOrigin origin,
) async {
  final db = ctx.db;
  if (!db.inTransaction) {
    throw StateError('dwEnsureAccount needs a transaction');
  }
  final verified = origin is DwSignInOrigin;
  // Two first sign-ins of one identifier at once must create one account.
  await db.advisoryLock(
    DwLockSpace.identifier,
    dwLockKey('${kind.name}:$identifier'),
  );
  if (verified) {
    final existing = await db.query(
      'UPDATE dw_identity SET verified_at = now() '
      'WHERE kind = @kind AND value = @value RETURNING account_id',
      params: {'kind': kind.name, 'value': identifier},
    );
    if (existing.isNotEmpty) {
      return (
        accountId: existing.single.get<int>('account_id'),
        created: false,
      );
    }
  } else {
    final existing = await dwAccountOf(db, kind, identifier);
    if (existing != null) return (accountId: existing, created: false);
  }
  final accountId = (await db.query(
    'INSERT INTO dw_account DEFAULT VALUES RETURNING id',
  )).single.get<int>('id');
  await db.execute(
    'INSERT INTO dw_identity (account_id, kind, value, verified_at) '
    'VALUES (@account, @kind, @value, '
    '${verified ? 'now()' : 'NULL'})',
    params: {'account': accountId, 'kind': kind.name, 'value': identifier},
  );
  await auth.onAccountCreated?.call(ctx, accountId, kind, identifier, origin);
  return (accountId: accountId, created: true);
}

/// Attaches a code-confirmed [identifier] to [accountId] — or, with
/// [replace], puts it in place of the account's identifiers of [kind] — and
/// answers the identity; `null` when the identifier belongs to another
/// account, and then nothing changes.
///
/// Must run inside a transaction on `ctx.db`. Under the identifier's lock, as
/// sign-in: a sign-in creating an account for the identifier and an attach of
/// it cannot both succeed.
///
/// With [replace], the oldest identity of the kind takes the new value (its id
/// stays) and the others of the kind are removed; an identifier the account
/// already has stays and only the others go. Every change runs
/// `onIdentifierChanged` ([DwIdentifierChangeCause.confirmed]); an identifier
/// the account already had is only marked verified.
@internal
Future<DwIdentityInfo?> dwAttachIdentity(
  DwCallContext ctx,
  DwAuthConfig auth, {
  required int accountId,
  required DwIdentifierKind kind,
  required String identifier,
  required bool replace,
}) async {
  final db = ctx.db;
  if (!db.inTransaction) {
    throw StateError('dwAttachIdentity needs a transaction');
  }
  await db.advisoryLock(
    DwLockSpace.identifier,
    dwLockKey('${kind.name}:$identifier'),
  );
  final owner = await dwAccountOf(db, kind, identifier);
  if (owner != null && owner != accountId) return null;
  final ofKind = [
    for (final row in await db.query(
      'SELECT ${DwAuthStore.identityColumns} FROM dw_identity '
      'WHERE account_id = @account AND kind = @kind ORDER BY id FOR UPDATE',
      params: {'account': accountId, 'kind': kind.name},
    ))
      DwAuthStore.identityOf(row),
  ];
  final changes = <DwIdentifierChange>[];
  final DwIdentityInfo attached;
  final List<DwIdentityInfo> dropped;
  final own = ofKind.where((i) => i.value == identifier).firstOrNull;
  if (own != null) {
    attached = await _identityWrite(
      db,
      'UPDATE dw_identity SET verified_at = now() WHERE id = @id '
      'RETURNING ${DwAuthStore.identityColumns}',
      {'id': own.id},
    );
    dropped = replace ? [...ofKind.where((i) => i.id != own.id)] : const [];
  } else if (replace && ofKind.isNotEmpty) {
    final replaced = ofKind.first;
    attached = await _identityWrite(
      db,
      'UPDATE dw_identity SET value = @value, verified_at = now() '
      'WHERE id = @id RETURNING ${DwAuthStore.identityColumns}',
      {'id': replaced.id, 'value': identifier},
    );
    changes.add(
      DwIdentifierChange(
        accountId: accountId,
        kind: kind,
        cause: DwIdentifierChangeCause.confirmed,
        previous: replaced.value,
        current: identifier,
      ),
    );
    dropped = ofKind.skip(1).toList();
  } else {
    attached = await _identityWrite(
      db,
      'INSERT INTO dw_identity (account_id, kind, value, verified_at) '
      'VALUES (@account, @kind, @value, now()) '
      'RETURNING ${DwAuthStore.identityColumns}',
      {'account': accountId, 'kind': kind.name, 'value': identifier},
    );
    changes.add(
      DwIdentifierChange(
        accountId: accountId,
        kind: kind,
        cause: DwIdentifierChangeCause.confirmed,
        current: identifier,
      ),
    );
    dropped = const [];
  }
  if (dropped.isNotEmpty) {
    await db.execute(
      'DELETE FROM dw_identity WHERE id = ANY(@ids::int8[])',
      params: {
        'ids': [for (final identity in dropped) identity.id],
      },
    );
    for (final identity in dropped) {
      changes.add(
        DwIdentifierChange(
          accountId: accountId,
          kind: kind,
          cause: DwIdentifierChangeCause.confirmed,
          previous: identity.value,
        ),
      );
    }
  }
  for (final change in changes) {
    await auth.onIdentifierChanged?.call(ctx, change);
  }
  return attached;
}

Future<DwIdentityInfo> _identityWrite(
  DwDatabaseHandle db,
  String sql,
  Map<String, Object?> params,
) async => DwAuthStore.identityOf((await db.query(sql, params: params)).single);

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

  /// A secret — a session key's token — was made, and may travel in the
  /// result of the call this scope belongs to.
  void madeSecret() {}
}

final class _ContextScope extends _Scope {
  _ContextScope(this.ctx);

  final DwRuntimeContext ctx;

  @override
  void checkRevocation() => ctx.requireSideEffects('revokeKeys');

  @override
  void madeSecret() => ctx.markSecret();

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
      // What the hooks published, delivered once committed.
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

  @override
  DwJobAttempt? get job => null;

  static Never _noServer(String what) => throw StateError(
    '$what needs a running server; this context belongs to DwAccountService '
    'over a bare database. Use server.accounts or ctx.accounts instead.',
  );

  @override
  int? get accountId => null;

  @override
  DwSessionKeyInfo? get sessionKey => null;

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
  DwFileService get files => _noServer('files');

  @override
  M module<M extends DwServerModule>() => _noServer('module<$M>()');

  @override
  Future<T> transaction<T>(Future<T> Function(DwDatabaseHandle tx) body) =>
      db.transaction(
        (tx) => runZoned(() => body(tx), zoneValues: {_zoneKey: tx}),
      );

  @override
  void publish(
    DwLiveChannel channel,
    DwWireObject item, {
    Set<int> exceptAccounts = const {},
  }) => _noServer('publish');

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
