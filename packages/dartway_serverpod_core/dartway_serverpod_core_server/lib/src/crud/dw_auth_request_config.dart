import 'package:dartway_serverpod_core_server/dartway_serverpod_core_server.dart';
import 'package:dartway_serverpod_core_server/src/business/auth/dw_auth_concurrency.dart';
import 'package:dartway_serverpod_core_server/src/business/auth/dw_auth_request_extension.dart';
import 'package:dartway_serverpod_core_server/src/business/auth/dw_auth_utils.dart';
import 'package:serverpod/serverpod.dart';

const verificationCodeKey = 'verificationCode';

final dwAuthRequestConfig = DwCrudConfig<DwAuthRequest>(
  table: DwAuthRequest.t,
  saveConfig: DwSaveConfig<DwAuthRequest>(
    allowSave: (Session session, DwSaveContext<DwAuthRequest> ctx) async {
      // // Update is not allowed
      // if (ctx.currentModel.id != null) {
      //   // TODO: implement centralized logging and alerting
      //   session.log(
      //     'Attempt to update DwAuthRequest with id=${ctx.currentModel.id} rejected',
      //     level: LogLevel.warning,
      //   );
      //   throw Exception('DwAuthRequest objects cannot be updated.');
      // }

      return true;
    },
    // TODO: !!! ensure password is not visible in logs or database
    beforeSaveTransaction:
        (Session session, DwSaveContext<DwAuthRequest> saveContext) async {
          final failReason = await DwCore.instance.prevalidateAuthAttempt(
            session,
            saveContext.currentModel,
          );
          if (failReason != null) {
            saveContext.currentModel.setFailed(session, failReason);
            return;
          }

          final userProfile = await saveContext.currentModel
              .findRelatedUserProfile(session);

          await saveContext.currentModel.tryVerify(
            session,
            userProfile: userProfile,
            transaction: saveContext.transaction,
          );

          if (saveContext.currentModel.status ==
              DwAuthRequestStatus.pendingVerification) {
            final authConfig = DwCore.instance.auth!.config;

            // Only one request per identifier may be counted at a time:
            // parallel ones would otherwise each see the same recent rows, all
            // pass the limit and all send a code. Refuse rather than queue —
            // a request already in flight for this identifier *is* the answer
            // "too fast", and a waiting lock would pin a pooled connection per
            // attacker request. See [DwAuthConcurrency].
            final locked = await DwAuthConcurrency.tryLockIdentifier(
              session,
              saveContext.currentModel.userIdentifier,
              transaction: saveContext.transaction,
            );

            if (!locked) {
              saveContext.currentModel.setFailed(
                session,
                DwAuthFailReason.rateLimited,
              );
              return;
            }

            final recentRequestCount = await DwAuthRequest.db.count(
              session,
              where: (t) =>
                  t.userIdentifier.equals(
                    saveContext.currentModel.userIdentifier,
                  ) &
                  (t.createdAt >
                      DateTime.now().subtract(
                        authConfig.authRequestRateLimitWindow,
                      )),
              transaction: saveContext.transaction,
            );

            if (recentRequestCount >=
                authConfig.maxAuthRequestsPerIdentifier) {
              saveContext.currentModel.setFailed(
                session,
                DwAuthFailReason.rateLimited,
              );
              return;
            }

            final verificationCode = await DwCore
                .instance
                .auth!
                .config
                .generateVerificationCodeMethod
                ?.call(session, verificationRequest: saveContext.currentModel);

            if (verificationCode != null) {
              saveContext.extras[verificationCodeKey] = verificationCode;
              saveContext.currentModel.verificationHash =
                  DwAuthUtils.hashVerificationCode(verificationCode);
            }
          } else if (saveContext.currentModel.status ==
              DwAuthRequestStatus.verified) {
            saveContext.beforeUpdates.addAll(
              await saveContext.currentModel.onVerified(
                session,
                userProfile: userProfile,
              ),
            );
          }
        },
    afterSaveTransaction:
        (Session session, DwSaveContext<DwAuthRequest> saveContext) async {},
    afterSaveSideEffects: (session, saveContext) async {
      if (saveContext.extras[verificationCodeKey] != null) {
        await DwCore.instance.auth!.config.sendVerificationCodeMethod?.call(
          session,
          verificationRequest: saveContext.currentModel,
          verificationCode: saveContext.extras[verificationCodeKey] as String,
        );
      }
    },
  ),
);
