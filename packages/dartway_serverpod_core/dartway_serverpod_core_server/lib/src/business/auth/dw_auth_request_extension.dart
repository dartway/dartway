import 'package:dartway_serverpod_core_server/dartway_serverpod_core_server.dart';
import 'package:serverpod/serverpod.dart';

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

  /// Checks password / hash and returns status
  Future<void> tryVerify(
    Session session, {
    required SerializableModel? userProfile,
  }) async {
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
      );

      if (verification != null &&
          verification.dwAuthRequest?.userIdentifier == userIdentifier) {
        status = DwAuthRequestStatus.verified;
        session.log(
          'Auth verified for userId=$userId ($userIdentifier) with accessToken',
          level: LogLevel.info,
        );
        return;
      } else {
        return setFailed(session, DwAuthFailReason.invalidAccessToken);
      }
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
