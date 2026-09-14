import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:dartway_core/dartway_core.dart';
import 'package:meta/meta.dart';

import '../context/dw_call_context.dart';
import '../handlers/dw_call_handler.dart';
import '../server/dw_runtime.dart';
import 'dw_account_service.dart';
import 'dw_auth_config.dart';
import 'dw_session_cache.dart';

/// Accounts, identities, codes and session keys: the built-in auth handlers
/// and token resolution.
@internal
final class DwAuthService {
  DwAuthService(this.runtime);

  final DwRuntime runtime;

  DwAuthConfig get auth => runtime.auth;
  DwSessionCache get _sessions => runtime.sessions;

  static final Random _random = Random.secure();

  /// Tokens longer than this are rejected without hashing or a query.
  static const int maxTokenLength = 256;

  /// The framework's command types: they have built-in handlers and a project
  /// may not register its own.
  static const Set<Type> builtInTypes = {
    DwRequestCode,
    DwVerifyCode,
    DwSignOut,
  };

  List<DwCallHandler> handlers() => [
    DwCallHandler.command<DwRequestCode, DwCodeTicket>(
      access: DwAccessRule.anonymous,
      handle: _requestCode,
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
  ];

  /// The session of [token], or `null` when it is unknown or revoked.
  ///
  /// A token seen within `DwServerSettings.tokenCacheTtl` costs no query;
  /// `last_used_at` is written at most once per
  /// `DwAuthConfig.keyTouchInterval`, awaited, so no write outlives the call
  /// that caused it.
  Future<DwResolvedSession?> resolve(String token) async {
    if (token.isEmpty || token.length > maxTokenLength) return null;
    final hash = hashToken(token);
    final cacheKey = base64Encode(hash);
    final cached = _sessions.lookup(cacheKey);
    if (cached != null) {
      final now = _sessions.now;
      if (now.difference(cached.touchedAt) >= auth.keyTouchInterval) {
        // Marked first: concurrent calls with this token write once.
        cached.touchedAt = now;
        await runtime.db.execute(
          'UPDATE dw_auth_key SET last_used_at = now() WHERE id = @id',
          params: {'id': cached.session.keyId},
        );
      }
      return cached.session;
    }
    final rows = await runtime.db.query(
      'SELECT id, account_id, '
      'EXTRACT(EPOCH FROM now() - last_used_at)::float8 AS idle_seconds '
      'FROM dw_auth_key WHERE token_hash = @hash AND revoked_at IS NULL',
      params: {'hash': hash},
    );
    if (rows.isEmpty) return null;
    final row = rows.single;
    final session = (
      accountId: row.get<int>('account_id'),
      keyId: row.get<int>('id'),
    );
    final idle = Duration(
      microseconds: (row.get<double>('idle_seconds') * 1e6).round(),
    );
    var touchedAt = _sessions.now.subtract(idle);
    if (idle >= auth.keyTouchInterval) {
      await runtime.db.execute(
        'UPDATE dw_auth_key SET last_used_at = now() WHERE id = @id',
        params: {'id': session.keyId},
      );
      touchedAt = _sessions.now;
    }
    return _sessions.store(cacheKey, session, touchedAt) ? session : null;
  }

  static Uint8List hashToken(String token) =>
      Uint8List.fromList(sha256.convert(utf8.encode(token)).bytes);

  static String _randomToken(int bytes) => base64Url
      .encode(List.generate(bytes, (_) => _random.nextInt(256)))
      .replaceAll('=', '');

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

  Future<DwCodeTicket> _requestCode(
    DwCallContext ctx,
    DwRequestCode command,
  ) async {
    final kind = command.kind;
    final identifier = _identifierOrRefuse(ctx, kind, command.identifier);
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
    final fixed = await auth.fixedCode?.call(ctx, kind, identifier, accountId);
    final code =
        fixed ??
        List.generate(auth.codeLength, (_) => _random.nextInt(10)).join();
    final ticketId = _randomToken(16);
    final ticket = (await ctx.db.query(
      'INSERT INTO dw_code_ticket (id, kind, identifier, code_hash, expires_at) '
      'VALUES (@id, @kind, @identifier, @hash, '
      'now() + @lifetime::int8 * interval \'1 microsecond\') '
      'RETURNING created_at, expires_at',
      params: {
        'id': ticketId,
        'kind': kind.name,
        'identifier': identifier,
        'hash': _codeHash(ticketId, code),
        'lifetime': auth.codeLifetime.inMicroseconds,
      },
    )).single;
    if (fixed == null) {
      await auth.deliverCode(ctx, kind, identifier, code);
    }
    return DwCodeTicket(
      id: ticketId,
      expiresAt: ticket.get<DateTime>('expires_at'),
      resendAfter: ticket.get<DateTime>('created_at').add(auth.resendDelay),
    );
  }

  Future<DwAuthSession> _verifyCode(
    DwCallContext ctx,
    DwVerifyCode command,
  ) async {
    final outcome = await ctx.transaction((tx) async {
      final rows = await tx.query(
        'SELECT kind, identifier, code_hash, attempts, '
        'expires_at <= now() OR consumed_at IS NOT NULL AS dead '
        'FROM dw_code_ticket WHERE id = @id FOR UPDATE',
        params: {'id': command.ticketId},
      );
      if (rows.isEmpty) return const _Verification.expired();
      final ticket = rows.single;
      final attempts = ticket.get<int>('attempts');
      if (ticket.get<bool>('dead') || attempts >= auth.maxAttempts) {
        return const _Verification.expired();
      }
      final expected = ticket.get<Uint8List>('code_hash');
      if (!_constantTimeEquals(
        _codeHash(command.ticketId, command.code),
        expected,
      )) {
        await tx.execute(
          'UPDATE dw_code_ticket SET attempts = attempts + 1 WHERE id = @id',
          params: {'id': command.ticketId},
        );
        final left = auth.maxAttempts - attempts - 1;
        return left > 0
            ? _Verification.wrong(left)
            : const _Verification.expired();
      }
      await tx.execute(
        'UPDATE dw_code_ticket SET consumed_at = now() WHERE id = @id',
        params: {'id': command.ticketId},
      );

      final (:accountId, created: isNew) = await dwEnsureAccount(
        ctx,
        auth,
        DwIdentifierKind.values.byName(ticket.get<String>('kind')),
        ticket.get<String>('identifier'),
        command.registration,
      );
      final token = _randomToken(32);
      await tx.execute(
        'INSERT INTO dw_auth_key (account_id, token_hash) VALUES (@account, @hash)',
        params: {'account': accountId, 'hash': hashToken(token)},
      );
      return _Verification.signedIn(
        DwAuthSession(id: accountId, token: token, isNewAccount: isNew),
      );
    });
    return switch (outcome) {
      _Verification(:final session?) => session,
      _Verification(:final attemptsLeft?) => ctx.refuse(
        DwCoreRefusal.invalid,
        field: 'code',
        params: {'attemptsLeft': attemptsLeft},
      ),
      _ => ctx.refuse(DwCoreRefusal.codeExpired, field: 'code'),
    };
  }

  Future<void> _signOut(DwCallContext ctx, DwSignOut command) async {
    final call = ctx as DwRuntimeContext;
    final keyId = call.keyId;
    if (keyId == null) throw const DwNotAuthenticatedException();
    await ctx.db.execute(
      'UPDATE dw_auth_key SET revoked_at = now() '
      'WHERE id = @id AND revoked_at IS NULL',
      params: {'id': keyId},
    );
    call.revokedKey(keyId);
  }
}

final class _Verification {
  const _Verification.expired() : session = null, attemptsLeft = null;
  const _Verification.wrong(int this.attemptsLeft) : session = null;
  const _Verification.signedIn(DwAuthSession this.session)
    : attemptsLeft = null;

  final DwAuthSession? session;
  final int? attemptsLeft;
}
