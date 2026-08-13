import 'package:dartway_push_server/src/generated/protocol.dart';
import 'package:serverpod/serverpod.dart';

import 'dw_device_push_token_policy.dart';
import 'dw_device_push_token_store.dart';
import 'dw_push_contracts.dart';

/// Whether this recipient should receive this particular message right now.
///
/// The one thing the module cannot answer: consent, muted categories, a
/// deleted account, a blocked user, quiet hours. Returning false skips the
/// delivery cleanly — it is not a failure and nothing is retried.
typedef DwPushRecipientEligibility =
    Future<bool> Function(
      Session session, {
      required int recipientId,
      required DwPushPayload payload,
      required Transaction transaction,
    });

/// The resolver most apps want: device tokens come from the module's own
/// store, and the app supplies only the part that is about its users.
///
/// Without it every app rewrites the same three things — read the tokens,
/// canonicalize them, delete the ones a provider rejected — around one method
/// that is genuinely theirs. Pass [isEligible] and you are done; implement
/// [DwPushRecipientResolver] yourself only when the tokens live somewhere else
/// entirely.
final class DwDevicePushTokenResolver extends DwPushRecipientResolver {
  const DwDevicePushTokenResolver({this.isEligible});

  final DwPushRecipientEligibility? isEligible;

  @override
  Future<DwPushRecipient> resolve(
    Session session, {
    required int recipientId,
    required DwPushPayload payload,
    required Transaction transaction,
  }) async {
    final eligibility = isEligible;
    if (eligibility != null &&
        !await eligibility(
          session,
          recipientId: recipientId,
          payload: payload,
          transaction: transaction,
        )) {
      return DwPushRecipient(const []);
    }

    return DwPushRecipient(
      await DwDevicePushTokenStore.targetsForRecipient(
        session,
        recipientId,
        transaction: transaction,
      ),
    );
  }

  @override
  Future<void> invalidateTargets(
    Session session, {
    required int recipientId,
    required List<String> targets,
    required Transaction transaction,
  }) async {
    final normalizedTargets = targets
        .map(DwDevicePushTokenPolicy.normalize)
        .where(DwDevicePushTokenPolicy.isValid)
        .toSet();
    if (normalizedTargets.isEmpty) return;

    // Compared canonically rather than by equality: rows written before the
    // policy existed still carry whitespace-wrapped values, and those would
    // never match the target string the transport reported.
    final storedRows = await DwDevicePushToken.db.find(
      session,
      where: (table) => table.recipientId.equals(recipientId),
      transaction: transaction,
    );
    final invalidRows = storedRows
        .where(
          (row) => normalizedTargets.contains(
            DwDevicePushTokenPolicy.normalize(row.token),
          ),
        )
        .toList(growable: false);
    if (invalidRows.isEmpty) return;

    await DwDevicePushToken.db.delete(
      session,
      invalidRows,
      transaction: transaction,
    );
  }

  @override
  Future<void> rememberTargetProvider(
    Session session, {
    required int recipientId,
    required String token,
    required String provider,
    required Transaction transaction,
  }) => DwDevicePushTokenStore.setProvider(
    session,
    recipientId: recipientId,
    token: token,
    provider: provider,
    transaction: transaction,
  );
}
