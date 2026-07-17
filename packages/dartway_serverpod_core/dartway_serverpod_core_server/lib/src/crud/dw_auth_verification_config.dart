import 'package:dartway_serverpod_core_server/dartway_serverpod_core_server.dart';
import 'package:dartway_serverpod_core_server/src/business/auth/dw_auth_concurrency.dart';
import 'package:dartway_serverpod_core_server/src/business/auth/dw_auth_utils.dart';
import 'package:dartway_serverpod_core_server/src/business/auth/dw_auth_verification_extension.dart';
import 'package:serverpod/serverpod.dart';

const verificationCodeKey = 'verificationCode';

final dwAuthVerificationConfig = DwCrudConfig<DwAuthVerification>(
  table: DwAuthVerification.t,
  saveConfig: DwSaveConfig<DwAuthVerification>(
    allowSave:
        (
          Session session,
          DwSaveContext<DwAuthVerification> saveContext,
        ) async => true,
    beforeSaveTransaction: (
      Session session,
      DwSaveContext<DwAuthVerification> saveContext,
    ) async {
      final authConfig = DwCore.instance.auth!.config;
      final verification = saveContext.currentModel;

      // The attempt limit below is a read-then-write decision, so only one
      // attempt per request may be in flight. Refuse rather than queue: a
      // waiting lock holds a pooled connection, and an attacker firing guesses
      // in parallel would drain the pool. Refusing costs a real user nothing —
      // they never verify the same request twice at once. See
      // [DwAuthConcurrency].
      final locked = await DwAuthConcurrency.tryLockAuthRequest(
        session,
        verification.dwAuthRequestId,
        transaction: saveContext.transaction,
      );

      if (!locked) {
        verification.setFailed(session, DwAuthFailReason.rateLimited);
        return;
      }

      final authRequest = await DwAuthRequest.db.findById(
        session,
        verification.dwAuthRequestId,
        transaction: saveContext.transaction,
      );

      if (authRequest == null ||
          authRequest.status != DwAuthRequestStatus.pendingVerification) {
        verification.setFailed(
          session,
          authRequest?.status == DwAuthRequestStatus.failed
              ? DwAuthFailReason.tooManyAttempts
              : DwAuthFailReason.invalidVerificationCode,
        );
        return;
      }

      final isExpired =
          DateTime.now().difference(authRequest.createdAt) >
          authConfig.verificationCodeLifetime;

      if (isExpired) {
        await _burnAuthRequest(session, authRequest, saveContext.transaction);
        verification.setFailed(session, DwAuthFailReason.codeExpired);
        return;
      }

      final previousAttempts = await DwAuthVerification.db.count(
        session,
        where: (t) => t.dwAuthRequestId.equals(authRequest.id!),
        transaction: saveContext.transaction,
      );

      if (previousAttempts >= authConfig.maxVerificationAttempts) {
        await _burnAuthRequest(session, authRequest, saveContext.transaction);
        verification.setFailed(session, DwAuthFailReason.tooManyAttempts);
        return;
      }

      final isCodeValid =
          verification.verificationCode != null &&
          authRequest.verificationHash ==
              DwAuthUtils.hashVerificationCode(verification.verificationCode!);

      if (!isCodeValid) {
        final isLastAttempt =
            previousAttempts + 1 >= authConfig.maxVerificationAttempts;
        if (isLastAttempt) {
          await _burnAuthRequest(session, authRequest, saveContext.transaction);
        }
        verification.setFailed(
          session,
          isLastAttempt
              ? DwAuthFailReason.tooManyAttempts
              : DwAuthFailReason.invalidVerificationCode,
        );
        return;
      }

      verification.accessToken = DwAuthUtils.generateSecureToken();
      authRequest.status = DwAuthRequestStatus.verified;
      await DwAuthRequest.db.updateRow(
        session,
        authRequest,
        transaction: saveContext.transaction,
      );
      return null;
    },
  ),
);

Future<void> _burnAuthRequest(
  Session session,
  DwAuthRequest authRequest,
  Transaction? transaction,
) async {
  authRequest.status = DwAuthRequestStatus.failed;
  await DwAuthRequest.db.updateRow(
    session,
    authRequest,
    transaction: transaction,
  );
}
