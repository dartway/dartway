import 'package:dartway_serverpod_core_server/dartway_serverpod_core_server.dart';
import 'package:dartway_serverpod_core_server/src/business/auth/dw_auth_concurrency.dart';
import 'package:dartway_serverpod_core_server/src/business/auth/dw_auth_request_extension.dart';
import 'package:dartway_serverpod_core_server/src/business/auth/dw_auth_utils.dart';
import 'package:serverpod/serverpod.dart';
import '../private/dw_singleton.dart';

const verificationCodeKey = 'verificationCode';

final dwAuthRequestConfig = DwCrudConfig<DwAuthRequest>(
  table: DwAuthRequest.t,
  saveConfig: DwSaveConfig<DwAuthRequest>(
    // The one config that has to be open, and the reason the flag exists as an
    // opt-out rather than a hard rule: this *is* how a caller signs in.
    // Requiring a session here would mean "log in to log in".
    //
    // What guards it instead is below, in `beforeSaveTransaction`: an attempt
    // is prevalidated, identifiers are locked one at a time, and requests per
    // identifier are rate-limited inside the window. Authentication is not the
    // gate here — those are.
    allowAnonymous: true,
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
          if (saveContext.isInsert) {
            saveContext.currentModel.createdAt = DateTime.now();
          }

          final failReason = await dw.prevalidateAuthAttempt(
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
            final authConfig = dw.auth!.config;

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

            if (recentRequestCount >= authConfig.maxAuthRequestsPerIdentifier) {
              saveContext.currentModel.setFailed(
                session,
                DwAuthFailReason.rateLimited,
              );
              return;
            }

            final verificationCode = await dw
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
          return null;
        },
    afterSaveTransaction:
        (Session session, DwSaveContext<DwAuthRequest> saveContext) async =>
            null,
    // Awaited on purpose, and this is the hook the caller hears about. The
    // sign-in screen's whole answer is "a code is on its way", so a delivery
    // that failed has to travel back with the response — from
    // `afterSaveSideEffects` nobody was waiting for it, and the user was shown
    // "code sent" for a code that was never sent. The price is that the
    // sign-in response now waits for the SMS or mail provider.
    //
    // The request row stays saved either way: the transaction committed before
    // this runs. That is fine here — the user retries, the retry issues a new
    // code, and the abandoned request expires on its own.
    afterSaveTransform: (session, saveContext) async {
      final verificationCode = saveContext.extras[verificationCodeKey];
      if (verificationCode == null) return null;

      try {
        await dw.auth!.config.sendVerificationCodeMethod?.call(
          session,
          verificationRequest: saveContext.currentModel,
          verificationCode: verificationCode as String,
        );
      } catch (exception, stackTrace) {
        // Split audience: the operator gets the provider's actual complaint —
        // an unverified sender domain, an expired key, a rejected recipient —
        // and the user gets a sentence they can act on. Handing the provider's
        // message to the client would leak the delivery configuration to an
        // endpoint that is open to anonymous callers.
        dw.alerts.reportError(
          'Failed to send the verification code for '
          '${saveContext.currentModel.userIdentifier}',
          exception: exception,
          stackTrace: stackTrace,
        );
        return 'Could not send the verification code. Please try again.';
      }
      return null;
    },
  ),
);
