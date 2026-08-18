import 'package:dartway_push_server/src/generated/protocol.dart';
import 'package:serverpod/serverpod.dart';

import 'dw_device_push_token_policy.dart';
import 'dw_push_contracts.dart';

/// Storage helpers for device push tokens, keyed on an opaque recipient id.
///
/// Generic machinery every push app needs: canonical-token lookup for dedupe,
/// eviction of tokens beyond the per-recipient cap, and "does this recipient
/// have a usable token" filtering used to skip enqueue for recipients that
/// would only fail with no-tokens. Tokens are app-owned data written by the
/// app; this store just keeps them canonical and bounded.
/// What happened to a device token handed to [DwDevicePushTokenStore.register].
enum DwDevicePushTokenRegistration {
  /// Stored, refreshed, or taken over from a previous owner of the device.
  registered,

  /// Empty, oversized, or otherwise unusable as a provider address.
  invalidToken,

  /// The token is registered to a different recipient and the configured
  /// conflict policy is [DwDevicePushTokenConflict.reject].
  ownedByAnotherRecipient,
}

/// What to do when the token being registered already belongs to somebody else.
///
/// A push token identifies an *app installation*, not a person: sign out, hand
/// the phone to somebody else, and the same token now belongs to the new user.
enum DwDevicePushTokenConflict {
  /// Move the token to the recipient registering it now. **The default, and
  /// the safe one:** the alternative leaves the previous owner's notifications
  /// going to a device somebody else is holding, whenever a sign-out failed to
  /// reach the server (offline, crash, app deleted).
  reassign,

  /// Refuse the registration and leave the existing owner alone. Choose it only
  /// when an installation genuinely cannot change hands.
  reject,
}

abstract final class DwDevicePushTokenStore {
  /// Stores [token] for [recipientId], canonically and idempotently.
  ///
  /// Everything a registration has to get right in one place: normalization,
  /// validation, the duplicate rows a device accumulates over reinstalls, the
  /// per-recipient cap, and the refresh window that keeps a chatty client from
  /// writing on every launch. Takes a transaction-scoped advisory lock on the
  /// token itself, because two devices reporting the same token at the same
  /// moment race on the unique index otherwise — and the loser of that race
  /// aborts the caller's whole transaction.
  ///
  /// [provider] is the transport that issued the token, when the device knows
  /// it. A null leaves whatever was established earlier untouched, so a client
  /// too old to report it does not erase what a probe discovered.
  static Future<DwDevicePushTokenRegistration> register(
    Session session, {
    required int recipientId,
    required String token,
    String? provider,
    required Transaction transaction,
    DwDevicePushTokenConflict onConflict = DwDevicePushTokenConflict.reassign,
    DateTime? now,
  }) async {
    final normalizedToken = DwDevicePushTokenPolicy.normalize(token);
    if (!DwDevicePushTokenPolicy.isValid(normalizedToken)) {
      return DwDevicePushTokenRegistration.invalidToken;
    }
    final normalizedProvider = _normalizeProvider(provider);
    final timestamp = (now ?? DateTime.now()).toUtc();

    await _lockToken(session, normalizedToken, transaction: transaction);
    final matchingTokens = await findByNormalizedValue(
      session,
      normalizedToken,
      transaction: transaction,
    );
    final foreignRows = matchingTokens
        .where((row) => row.recipientId != recipientId)
        .toList(growable: false);
    if (foreignRows.isNotEmpty &&
        onConflict == DwDevicePushTokenConflict.reject) {
      return DwDevicePushTokenRegistration.ownedByAnotherRecipient;
    }

    if (matchingTokens.isEmpty) {
      await DwDevicePushToken.db.insertRow(
        session,
        DwDevicePushToken(
          recipientId: recipientId,
          token: normalizedToken,
          provider: normalizedProvider,
          updatedAt: timestamp,
        ),
        transaction: transaction,
      );
    } else {
      final survivor = matchingTokens.first;
      final mustNormalizeStoredValue = survivor.token != normalizedToken;
      final mustReassign = survivor.recipientId != recipientId;
      final mustSetProvider =
          normalizedProvider != null && survivor.provider != normalizedProvider;
      if (mustNormalizeStoredValue ||
          mustReassign ||
          mustSetProvider ||
          DwDevicePushTokenPolicy.shouldRefresh(
            refreshedAt: survivor.updatedAt,
            now: timestamp,
          )) {
        await DwDevicePushToken.db.updateRow(
          session,
          survivor.copyWith(
            recipientId: recipientId,
            token: normalizedToken,
            provider: normalizedProvider ?? survivor.provider,
            updatedAt: timestamp,
          ),
          transaction: transaction,
        );
      }
      // Duplicates of one physical device, kept by older writers or by a
      // whitespace-wrapped legacy value. One row per token from here on.
      if (matchingTokens.length > 1) {
        await DwDevicePushToken.db.delete(
          session,
          matchingTokens.skip(1).toList(growable: false),
          transaction: transaction,
        );
      }
    }

    await evictExcessForRecipient(
      session,
      recipientId: recipientId,
      transaction: transaction,
    );
    return DwDevicePushTokenRegistration.registered;
  }

  /// Removes [token] from [recipientId] — sign-out, or a token the platform
  /// replaced. Silent about tokens that are not there, and about tokens
  /// belonging to somebody else: a caller must not learn either fact.
  static Future<void> unregister(
    Session session, {
    required int recipientId,
    required String token,
    required Transaction transaction,
  }) async {
    final normalizedToken = DwDevicePushTokenPolicy.normalize(token);
    if (!DwDevicePushTokenPolicy.isValid(normalizedToken)) return;

    await _lockToken(session, normalizedToken, transaction: transaction);
    final ownedRows = (await findByNormalizedValue(
      session,
      normalizedToken,
      transaction: transaction,
    )).where((row) => row.recipientId == recipientId).toList(growable: false);
    if (ownedRows.isEmpty) return;
    await DwDevicePushToken.db.delete(
      session,
      ownedRows,
      transaction: transaction,
    );
  }

  /// Records the transport a token turned out to belong to, matched
  /// canonically so a legacy whitespace-wrapped row is not probed forever.
  static Future<void> setProvider(
    Session session, {
    required int recipientId,
    required String token,
    required String provider,
    Transaction? transaction,
  }) async {
    final normalizedToken = DwDevicePushTokenPolicy.normalize(token);
    final normalizedProvider = _normalizeProvider(provider);
    if (!DwDevicePushTokenPolicy.isValid(normalizedToken) ||
        normalizedProvider == null) {
      return;
    }
    final trimCharacters =
        DwDevicePushTokenPolicy.canonicalTrimCharactersSqlLiteral;
    await session.db.unsafeExecute(
      '''
UPDATE "dw_device_push_token"
SET "provider" = @provider
WHERE "recipientId" = @recipientId
  AND BTRIM("token", $trimCharacters) = @token
  AND ("provider" IS DISTINCT FROM @provider)
''',
      transaction: transaction,
      parameters: QueryParameters.named({
        'recipientId': recipientId,
        'token': normalizedToken,
        'provider': normalizedProvider,
      }),
    );
  }

  /// The recipient's usable targets, newest first, capped by the policy —
  /// exactly what a resolver hands to the transport.
  static Future<List<DwPushTarget>> targetsForRecipient(
    Session session,
    int recipientId, {
    Transaction? transaction,
  }) async {
    final rows = await DwDevicePushToken.db.find(
      session,
      where: (table) => table.recipientId.equals(recipientId),
      orderByList: (table) => [
        Order(column: table.updatedAt, orderDescending: true),
        Order(column: table.id, orderDescending: true),
      ],
      limit: DwDevicePushTokenPolicy.maximumTokensPerRecipient,
      transaction: transaction,
    );
    final targets = <DwPushTarget>[];
    final seenTokens = <String>{};
    for (final row in rows) {
      final token = DwDevicePushTokenPolicy.normalize(row.token);
      if (!DwDevicePushTokenPolicy.isValid(token)) continue;
      if (!seenTokens.add(token)) continue;
      targets.add(DwPushTarget(token: token, provider: row.provider));
    }
    return targets;
  }

  /// Serialises writers of one token. Two devices reporting the same token at
  /// the same moment would otherwise collide on `UNIQUE(token)`, and a unique
  /// violation does not merely fail the statement — it aborts the transaction
  /// it happened in, taking the caller's work with it.
  static Future<void> _lockToken(
    Session session,
    String normalizedToken, {
    required Transaction transaction,
  }) => session.db.unsafeExecute(
    'SELECT pg_advisory_xact_lock(hashtextextended(@token, 0))',
    transaction: transaction,
    parameters: QueryParameters.named({'token': normalizedToken}),
  );

  static String? _normalizeProvider(String? provider) {
    final normalized = provider?.trim();
    return normalized == null || normalized.isEmpty ? null : normalized;
  }

  /// Rows whose token normalizes to [normalizedToken], locked `FOR UPDATE`,
  /// exact matches first. Used to collapse duplicates on registration.
  static Future<List<DwDevicePushToken>> findByNormalizedValue(
    Session session,
    String normalizedToken, {
    required Transaction transaction,
  }) async {
    final trimCharacters =
        DwDevicePushTokenPolicy.canonicalTrimCharactersSqlLiteral;
    final rows = await session.db.unsafeQuery(
      '''
SELECT "id"
FROM "dw_device_push_token"
WHERE BTRIM("token", $trimCharacters) = @token
FOR UPDATE
''',
      transaction: transaction,
      parameters: QueryParameters.named({'token': normalizedToken}),
    );
    final ids = rows.map((row) => row.first as int).toSet();
    if (ids.isEmpty) return const [];
    final tokens = await DwDevicePushToken.db.find(
      session,
      where: (table) => table.id.inSet(ids),
      transaction: transaction,
    );
    tokens.sort((left, right) {
      final leftIsExact = left.token == normalizedToken;
      final rightIsExact = right.token == normalizedToken;
      if (leftIsExact != rightIsExact) return leftIsExact ? -1 : 1;
      return (left.id ?? 0).compareTo(right.id ?? 0);
    });
    return tokens;
  }

  /// Deletes the recipient's tokens beyond [DwDevicePushTokenPolicy.
  /// maximumTokensPerRecipient], keeping the newest by `updatedAt`/`id`.
  static Future<void> evictExcessForRecipient(
    Session session, {
    required int recipientId,
    required Transaction transaction,
  }) async {
    await session.db.unsafeExecute(
      '''
DELETE FROM "dw_device_push_token" AS stored_token
USING (
  SELECT "id"
  FROM "dw_device_push_token"
  WHERE "recipientId" = @recipientId
  ORDER BY "updatedAt" DESC, "id" DESC
  OFFSET @maximumTokens
  FOR UPDATE
) AS excess_token
WHERE stored_token."id" = excess_token."id"
''',
      parameters: QueryParameters.named({
        'recipientId': recipientId,
        'maximumTokens': DwDevicePushTokenPolicy.maximumTokensPerRecipient,
      }),
      transaction: transaction,
    );
  }

  /// Whether [recipientId] has at least one valid (non-empty, in-bounds) token.
  static Future<bool> recipientHasToken(
    Session session,
    int recipientId, {
    Transaction? transaction,
  }) async {
    final tokens = await DwDevicePushToken.db.find(
      session,
      where: (t) => t.recipientId.equals(recipientId),
      transaction: transaction,
    );
    return tokens.any(
      (token) => DwDevicePushTokenPolicy.isValid(
        DwDevicePushTokenPolicy.normalize(token.token),
      ),
    );
  }

  /// The subset of [recipientIds] that have at least one valid token — used to
  /// drop no-token recipients before enqueue.
  static Future<Set<int>> filterRecipientsWithTokens(
    Session session,
    Set<int> recipientIds, {
    Transaction? transaction,
  }) async {
    if (recipientIds.isEmpty) return {};

    final tokens = await DwDevicePushToken.db.find(
      session,
      where: (t) => t.recipientId.inSet(recipientIds),
      transaction: transaction,
    );
    return tokens
        .where(
          (token) => DwDevicePushTokenPolicy.isValid(
            DwDevicePushTokenPolicy.normalize(token.token),
          ),
        )
        .map((token) => token.recipientId)
        .toSet();
  }
}
