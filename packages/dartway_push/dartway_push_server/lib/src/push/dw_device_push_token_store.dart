import 'package:dartway_push_server/src/generated/protocol.dart';
import 'package:serverpod/serverpod.dart';

import 'dw_device_push_token_policy.dart';

/// Storage helpers for device push tokens, keyed on an opaque recipient id.
///
/// Generic machinery every push app needs: canonical-token lookup for dedupe,
/// eviction of tokens beyond the per-recipient cap, and "does this recipient
/// have a usable token" filtering used to skip enqueue for recipients that
/// would only fail with no-tokens. Tokens are app-owned data written by the
/// app; this store just keeps them canonical and bounded.
abstract final class DwDevicePushTokenStore {
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
