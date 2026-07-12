import 'package:dartway_serverpod_core_server/dartway_serverpod_core_server.dart';
import 'package:serverpod/serverpod.dart';

import 'dw_auth_concurrency.dart';
import 'dw_auth_utils.dart';

extension DwAuthRequestVerification on DwAuthRequest {
  void setFailed(Session session, DwAuthFailReason reason) {
    // TODO: setup alerting
    session.log('Auth failed: $reason', level: LogLevel.warning);

    status = DwAuthRequestStatus.failed;
    failReason = reason;
    return;
  }

  Future<TableRow?> findRelatedUserProfile(Session session) async {
    final userProfile = await DwCore.instance.getUserProfileByIdentifier(
      session,
      userIdentifier,
    );

    userId = userProfile?.id;
    return userProfile;
  }

  /// Checks password / hash and returns status.
  ///
  /// [transaction] must be the transaction of the enclosing save: redeeming an
  /// access token flips the original request to `completed`, and that write has
  /// to commit or roll back together with the sign-in it authorizes.
  Future<void> tryVerify(
    Session session, {
    required SerializableModel? userProfile,
    Transaction? transaction,
  }) async {
    // External providers (Apple, …): validate the provider credential, then
    // register on first sign-in or log in when the user already exists.
    if (authProvider != DwAuthProvider.email) {
      final verifyExternal =
          DwCore.instance.auth!.config.verifyExternalCredential;

      // An unconfigured provider is a closed door, not an open one.
      if (verifyExternal == null) {
        return setFailed(session, DwAuthFailReason.invalidAccessToken);
      }

      final failReason = await verifyExternal(session, authRequest: this);
      if (failReason != null) return setFailed(session, failReason);

      requestType = userProfile == null
          ? DwAuthRequestType.register
          : DwAuthRequestType.login;
      status = DwAuthRequestStatus.verified;
      session.log(
        'Auth verified for $userIdentifier via ${authProvider.name}',
        level: LogLevel.info,
      );
      return;
    }

    // TODO: add alternative logic for registration requests
    if (requestType != DwAuthRequestType.register && userProfile == null) {
      return setFailed(session, DwAuthFailReason.userNotFound);
    }

    if (requestType == DwAuthRequestType.register && userProfile != null) {
      return setFailed(session, DwAuthFailReason.userAlreadyExists);
    }

    if (password != null) {
      final userPassword = await DwUserPassword.db.findFirstRow(
        session,
        where: (t) => t.userId.equals(userId),
      );
      if (userPassword == null) {
        return setFailed(session, DwAuthFailReason.passwordNotSet);
      }

      final isValid = DwAuthUtils.verifyPassword(
        password!,
        userPassword.passwordHash,
      );

      if (!isValid) {
        return setFailed(session, DwAuthFailReason.invalidPassword);
      } else {
        status = DwAuthRequestStatus.verified;
        session.log(
          'Auth verified for userId=$userId ($userIdentifier) with password',
          level: LogLevel.info,
        );
        return;
      }
    } else if (accessToken != null) {
      final verification = await DwAuthVerification.db.findFirstRow(
        session,
        where: (t) => t.accessToken.equals(accessToken!),
        include: DwAuthVerification.include(
          dwAuthRequest: DwAuthRequest.include(),
        ),
        transaction: transaction,
      );

      final originalRequest = verification?.dwAuthRequest;

      if (originalRequest == null ||
          originalRequest.userIdentifier != userIdentifier) {
        return setFailed(session, DwAuthFailReason.invalidAccessToken);
      }

      // Claim the request atomically instead of checking its status and then
      // writing it back: two requests carrying the same token would otherwise
      // both read `verified` and both be signed in, which is the one thing a
      // single-use token must not allow. Only the winner gets `true`.
      final claimed = await DwAuthConcurrency.claimVerifiedRequest(
        session,
        originalRequest.id!,
        transaction: transaction,
      );

      if (!claimed) {
        return setFailed(session, DwAuthFailReason.invalidAccessToken);
      }

      status = DwAuthRequestStatus.verified;
      session.log(
        'Auth verified for userId=$userId ($userIdentifier) with accessToken',
        level: LogLevel.info,
      );
      return;
    }

    status = DwAuthRequestStatus.pendingVerification;
    return;
  }

  Future<List<DwModelWrapper>> onVerified(
    Session session, {
    required TableRow? userProfile,
  }) async {
    switch (requestType) {
      case DwAuthRequestType.login:
        final authKey = await DwCore.instance.auth!.signInUser(
          session,
          userId!,
        );
        return [
          DwModelWrapper(
            object: DwAuthData(
              key: authKey.key!,
              keyId: authKey.id!,
              userProfile: userProfile!,
            ),
          ),
        ];
      case DwAuthRequestType.changePassword:
        if (newPassword == null) {
          throw Exception('New password is not provided');
        }

        await DwCore.instance.auth!.setUserPassword(
          session,
          userId: userId!,
          newPassword: newPassword,
        );

        return [];
      case DwAuthRequestType.register:
        userId = await DwCore.instance.createUserProfile(
          session,
          registrationRequest: this,
        );

        userProfile = await DwCore.instance.getUserProfile(session, userId!);

        if (newPassword != null) {
          await DwCore.instance.auth!.setUserPassword(
            session,
            userId: userId!,
            newPassword: newPassword,
          );
        }

        final authKey = await DwCore.instance.auth!.signInUser(
          session,
          userId!,
        );

        return [
          DwModelWrapper(
            // TODO: try to replace with DwAuthKey
            object: DwAuthData(
              key: authKey.key!,
              keyId: authKey.id!,
              userProfile: userProfile!,
            ),
          ),
        ];
      default:
        throw UnimplementedError('Unknown request type: $requestType');
    }
  }
}
