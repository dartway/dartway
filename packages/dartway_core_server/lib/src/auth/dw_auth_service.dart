import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:dartway_core_shared/dartway_core_shared.dart';
import 'package:meta/meta.dart';

import '../context/dw_call_context.dart';
import '../handlers/dw_call_handler.dart';
import '../server/dw_runtime.dart';
import 'dw_account_service.dart';
import 'dw_auth_config.dart';
import 'dw_auth_store.dart';
import 'dw_session_cache.dart';

/// What a one-time code ticket is for (`dw_code_ticket.purpose`). A ticket
/// is confirmed only by the command of its purpose.
enum _CodePurpose {
  signIn,

  /// `DwRequestIdentifierCode`: bound to the account that asked.
  attach,
}

/// Accounts, identities, codes and session keys: the built-in auth handlers
/// and token resolution.
@internal
final class DwAuthService {
  DwAuthService(this.runtime);

  final DwRuntime runtime;

  DwAuthConfig get auth => runtime.auth;
  DwSessionCache get _sessions => runtime.sessions;

  /// Tokens longer than this are rejected without hashing or a query.
  static const int maxTokenLength = 256;

  /// The framework's command types: they have built-in handlers and a project
  /// may not register its own.
  static const Set<Type> builtInTypes = {
    DwRequestCode,
    DwVerifyCode,
    DwSignOut,
    DwDeleteMyAccount,
    DwRequestIdentifierCode,
    DwConfirmIdentifier,
  };

  List<DwCallHandler> handlers() => [
    // Not transactional at the framework level: `deliverCode` runs after the
    // ticket's own transaction has committed — see `_requestCode` — so an
    // HTTP call to a provider does not hold that transaction's connection
    // (and, worse, the identifier's advisory lock) for as long as the
    // provider takes to answer. The ticket is real, and counted against the
    // limit, whether or not delivery goes on to succeed.
    DwCallHandler.command<DwRequestCode, DwCodeTicket>(
      access: DwAccessRule.anonymous,
      transactional: false,
      handle: (ctx, command) => _requestCode(
        ctx,
        command.kind,
        command.identifier,
        _CodePurpose.signIn,
      ),
    ),
    // Not transactional at the framework level: a wrong code must commit its
    // attempt even though the answer is a refusal (a refusal rolls the
    // handler's transaction back). Its successful outcome carries the token
    // and is therefore never stored for idempotency.
    dwSecretResultCommand<DwVerifyCode, DwAuthSession>(
      access: DwAccessRule.anonymous,
      transactional: false,
      handle: _verifyCode,
    ),
    DwCallHandler.command<DwSignOut, void>(
      access: DwAccessRule.signedIn,
      handle: _signOut,
    ),
    DwCallHandler.command<DwDeleteMyAccount, void>(
      access: DwAccessRule.signedIn,
      // Its own outcome would be the one row about this person left behind;
      // a repeat finds no account and does nothing, which is the same answer.
      recordsSuccess: false,
      handle: (ctx, command) async {
        await ctx.accounts.deleteAccount(ctx.requireAccountId);
      },
    ),
    // Not transactional for the same reason `DwRequestCode` is not.
    DwCallHandler.command<DwRequestIdentifierCode, DwCodeTicket>(
      access: DwAccessRule.signedIn,
      transactional: false,
      handle: (ctx, command) => _requestCode(
        ctx,
        command.kind,
        command.identifier,
        _CodePurpose.attach,
      ),
    ),
    // Not transactional for the reason `DwVerifyCode` is not; its result is
    // no secret, so a retry is answered the stored identity.
    DwCallHandler.command<DwConfirmIdentifier, DwIdentityInfo>(
      access: DwAccessRule.signedIn,
      transactional: false,
      handle: _confirmIdentifier,
    ),
  ];

  /// The session key of [token], or `null` when it is unknown or revoked.
  ///
  /// A token seen within `DwServerSettings.tokenCacheTtl` costs no query;
  /// `last_used_at` is written at most once per
  /// `DwAuthConfig.keyTouchInterval`, awaited, so no write outlives the call
  /// that caused it.
  Future<DwSessionKeyInfo?> resolve(String token) async {
    if (token.isEmpty || token.length > maxTokenLength) return null;
    final hash = DwAuthStore.hashToken(token);
    final cacheKey = base64Encode(hash);
    final cached = _sessions.lookup(cacheKey);
    if (cached != null) {
      final now = _sessions.now;
      if (now.difference(cached.touchedAt) >= auth.keyTouchInterval) {
        // Marked first: concurrent calls with this token write once.
        cached.touchedAt = now;
        cached.key = await _touch(cached.key);
      }
      return cached.key;
    }
    final rows = await runtime.db.query(
      'SELECT ${DwAuthStore.keyColumns}, '
      'EXTRACT(EPOCH FROM now() - last_used_at)::float8 AS idle_seconds '
      'FROM dw_auth_key WHERE token_hash = @hash AND revoked_at IS NULL',
      params: {'hash': hash},
    );
    if (rows.isEmpty) return null;
    final row = rows.single;
    var key = DwAuthStore.keyOf(row);
    final idle = Duration(
      microseconds: (row.get<double>('idle_seconds') * 1e6).round(),
    );
    var touchedAt = _sessions.now.subtract(idle);
    if (idle >= auth.keyTouchInterval) {
      key = await _touch(key);
      touchedAt = _sessions.now;
    }
    return _sessions.store(cacheKey, key, touchedAt) ? key : null;
  }

  /// Writes `last_used_at` of [key] and answers the key as touched.
  Future<DwSessionKeyInfo> _touch(DwSessionKeyInfo key) async {
    final touched = await runtime.db.query(
      'UPDATE dw_auth_key SET last_used_at = now() WHERE id = @id '
      'RETURNING last_used_at',
      params: {'id': key.id},
    );
    return touched.isEmpty
        ? key
        : DwAuthStore.touched(
            key,
            touched.single.get<DateTime>('last_used_at'),
          );
  }

  static Uint8List _codeHash(String ticketId, String code) =>
      Uint8List.fromList(sha256.convert(utf8.encode('$ticketId:$code')).bytes);

  /// Compares without an early exit, so the time taken says nothing about how
  /// much of a guess was right.
  static bool _constantTimeEquals(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    var difference = 0;
    for (var i = 0; i < a.length; i++) {
      difference |= a[i] ^ b[i];
    }
    return difference == 0;
  }

  String _identifierOrRefuse(
    DwCallContext ctx,
    DwIdentifierKind kind,
    String raw,
  ) =>
      auth.normalize(kind, raw) ??
      ctx.refuse(DwCoreRefusal.invalid, field: 'identifier');

  /// Sends a code for [rawIdentifier] and answers its ticket — one path for
  /// signing in and for attaching an identifier, so both are held to the same
  /// normalization, the same limits (counted per identifier across both
  /// purposes), the same [DwAuthConfig.generateCode] and the same
  /// [DwAuthConfig.deliverCode].
  ///
  /// The answer is the same whether the identifier belongs to an account or
  /// not, and whoever it belongs to.
  ///
  /// **Two phases, one transaction and then none.** The limit check, picking
  /// the code and recording the ticket run inside `ctx.transaction` — the
  /// part that has to be atomic, and the part every earlier version of this
  /// method ran entirely under. [DwAuthConfig.deliverCode] runs after that
  /// transaction has committed and given its connection back to the pool:
  /// a project's `deliverCode` is commonly an HTTP call to a provider, and
  /// making it wait on that call while holding both a pooled connection and
  /// the identifier's advisory lock is how one slow provider empties the
  /// pool for every caller, not only this identifier's. The ticket this
  /// writes is real, and already counted against the limit, before delivery
  /// is even attempted — so a provider that times out is answered as an
  /// incident (or a refusal, if `deliverCode` throws one), not silently
  /// undone, and the next attempt waits out `resendDelay` like any other
  /// resend rather than being free to retry at once.
  Future<DwCodeTicket> _requestCode(
    DwCallContext ctx,
    DwIdentifierKind kind,
    String rawIdentifier,
    _CodePurpose purpose,
  ) async {
    final identifier = _identifierOrRefuse(ctx, kind, rawIdentifier);
    final attachingAccount = switch (purpose) {
      _CodePurpose.signIn => null,
      _CodePurpose.attach => ctx.requireAccountId,
    };
    final (ticket, code, accountId) = await ctx.transaction((tx) async {
      // The limit is read and extended under one lock per identifier, or two
      // parallel requests would both see room for one more.
      await ctx.db.advisoryLock(
        DwLockSpace.identifier,
        dwLockKey('${kind.name}:$identifier'),
      );
      final stats = (await ctx.db.query(
        'SELECT now() AS now, count(*) AS n, min(created_at) AS first, '
        'max(created_at) AS last FROM dw_code_ticket '
        'WHERE kind = @kind AND identifier = @identifier '
        'AND created_at > now() - @window::int8 * interval \'1 microsecond\'',
        params: {
          'kind': kind.name,
          'identifier': identifier,
          'window': auth.requestWindow.inMicroseconds,
        },
      )).single;
      final now = stats.get<DateTime>('now');
      final count = stats.get<int>('n');
      final first = stats['first'] as DateTime?;
      final last = stats['last'] as DateTime?;
      DateTime? retryAt;
      if (count >= auth.maxRequestsPerWindow && first != null) {
        retryAt = first.add(auth.requestWindow);
      }
      if (last != null && last.add(auth.resendDelay).isAfter(now)) {
        final resendAt = last.add(auth.resendDelay);
        if (retryAt == null || resendAt.isAfter(retryAt)) retryAt = resendAt;
      }
      if (retryAt != null) {
        throw DwRefusalException(
          DwCallRefusal.tooManyRequests(retryAt.difference(now)),
        );
      }

      final accountId = await dwAccountOf(ctx.db, kind, identifier);
      final code =
          await auth.generateCode?.call(ctx, kind, identifier, accountId) ??
          dwRandomCode(auth.codeLength);
      final ticketId = DwAuthStore.randomToken(16);
      final row = (await ctx.db.query(
        'INSERT INTO dw_code_ticket '
        '(id, kind, identifier, code_hash, expires_at, purpose, account_id) '
        'VALUES (@id, @kind, @identifier, @hash, '
        'now() + @lifetime::int8 * interval \'1 microsecond\', @purpose, '
        '@account::int8) '
        'RETURNING created_at, expires_at',
        params: {
          'id': ticketId,
          'kind': kind.name,
          'identifier': identifier,
          'hash': _codeHash(ticketId, code),
          'lifetime': auth.codeLifetime.inMicroseconds,
          'purpose': purpose.name,
          'account': attachingAccount,
        },
      )).single;
      final ticket = DwCodeTicket(
        id: ticketId,
        expiresAt: row.get<DateTime>('expires_at'),
        resendAfter: row.get<DateTime>('created_at').add(auth.resendDelay),
      );
      return (ticket, code, accountId);
    });
    await auth.deliverCode(ctx, kind, identifier, code, accountId);
    return ticket;
  }

  /// Checks [code] against a live ticket of [purpose] — requested by
  /// [accountId], for an attach ticket — on [ctx]'s transaction, and uses the
  /// ticket up when the code is right.
  ///
  /// A ticket of another purpose or another account reads as unknown and is
  /// left untouched: guessing at someone else's ticket must neither learn
  /// anything nor burn its attempts.
  Future<_TicketCheck> _checkCode(
    DwCallContext ctx,
    String ticketId,
    String code,
    _CodePurpose purpose, {
    int? accountId,
  }) async {
    final tx = ctx.db;
    final rows = await tx.query(
      'SELECT kind, identifier, code_hash, attempts, '
      'expires_at <= now() OR consumed_at IS NOT NULL AS dead '
      'FROM dw_code_ticket WHERE id = @id AND purpose = @purpose '
      'AND account_id IS NOT DISTINCT FROM @account::int8 FOR UPDATE',
      params: {'id': ticketId, 'purpose': purpose.name, 'account': accountId},
    );
    if (rows.isEmpty) return const _TicketCheck.expired();
    final ticket = rows.single;
    final attempts = ticket.get<int>('attempts');
    if (ticket.get<bool>('dead') || attempts >= auth.maxAttempts) {
      return const _TicketCheck.expired();
    }
    final expected = ticket.get<Uint8List>('code_hash');
    if (!_constantTimeEquals(_codeHash(ticketId, code), expected)) {
      await tx.execute(
        'UPDATE dw_code_ticket SET attempts = attempts + 1 WHERE id = @id',
        params: {'id': ticketId},
      );
      final left = auth.maxAttempts - attempts - 1;
      return left > 0 ? _TicketCheck.wrong(left) : const _TicketCheck.expired();
    }
    await tx.execute(
      'UPDATE dw_code_ticket SET consumed_at = now() WHERE id = @id',
      params: {'id': ticketId},
    );
    return _TicketCheck.right(
      DwIdentifierKind.values.byName(ticket.get<String>('kind')),
      ticket.get<String>('identifier'),
    );
  }

  /// The refusal of a code that did not verify.
  static Never _refuseCode(DwCallContext ctx, _TicketCheck check) =>
      switch (check) {
        _TicketCheck(:final attemptsLeft?) => ctx.refuse(
          DwCoreRefusal.invalid,
          field: 'code',
          params: {'attemptsLeft': attemptsLeft},
        ),
        _ => ctx.refuse(DwCoreRefusal.codeExpired, field: 'code'),
      };

  Future<DwAuthSession> _verifyCode(
    DwCallContext ctx,
    DwVerifyCode command,
  ) async {
    final (check, session) = await ctx.transaction((tx) async {
      final check = await _checkCode(
        ctx,
        command.ticketId,
        command.code,
        _CodePurpose.signIn,
      );
      final (kind, identifier) = (check.kind, check.identifier);
      if (kind == null || identifier == null) return (check, null);
      final (:accountId, created: isNew) = await dwEnsureAccount(
        ctx,
        auth,
        kind,
        identifier,
        DwAccountOrigin.signIn(command.registration),
      );
      final issued = (await DwAuthStore.insertKey(
        tx,
        accountId: accountId,
        kind: DwSessionKeyKind.app,
        label: (ctx as DwRuntimeContext).clientLabel,
      ))!;
      return (
        check,
        DwAuthSession(id: accountId, token: issued.token, isNewAccount: isNew),
      );
    });
    return session ?? _refuseCode(ctx, check);
  }

  Future<DwIdentityInfo> _confirmIdentifier(
    DwCallContext ctx,
    DwConfirmIdentifier command,
  ) async {
    final caller = ctx.requireAccountId;
    final (check, identity) = await ctx.transaction((tx) async {
      final check = await _checkCode(
        ctx,
        command.ticketId,
        command.code,
        _CodePurpose.attach,
        accountId: caller,
      );
      final (kind, identifier) = (check.kind, check.identifier);
      if (kind == null || identifier == null) return (check, null);
      // `null` when the identifier is another account's. The ticket stays
      // used then: the code was right, and the answer to it is final.
      final identity = await dwAttachIdentity(
        ctx,
        auth,
        accountId: caller,
        kind: kind,
        identifier: identifier,
        replace: command.replace,
      );
      return (check, identity);
    });
    if (identity != null) return identity;
    if (check.kind != null) {
      ctx.refuse(DwAuthRefusal.identifierTaken, field: 'code');
    }
    _refuseCode(ctx, check);
  }

  Future<void> _signOut(DwCallContext ctx, DwSignOut command) async {
    final call = ctx as DwRuntimeContext;
    final keyId = call.sessionKey?.id;
    if (keyId == null) throw const DwNotAuthenticatedException();
    await ctx.db.execute(
      'UPDATE dw_auth_key SET revoked_at = now() '
      'WHERE id = @id AND revoked_at IS NULL',
      params: {'id': keyId},
    );
    call.revokedKey(keyId);
  }
}

/// The outcome of checking a code: expired (or unknown), wrong with attempts
/// left, or right for an identifier.
final class _TicketCheck {
  const _TicketCheck.expired()
    : attemptsLeft = null,
      kind = null,
      identifier = null;
  const _TicketCheck.wrong(int this.attemptsLeft)
    : kind = null,
      identifier = null;
  const _TicketCheck.right(DwIdentifierKind this.kind, String this.identifier)
    : attemptsLeft = null;

  final int? attemptsLeft;
  final DwIdentifierKind? kind;
  final String? identifier;
}
