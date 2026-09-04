import 'package:dartway_serverpod_core_server/dartway_serverpod_core_server.dart';
import 'package:serverpod/serverpod.dart';

import 'dw_auth_concurrency.dart';
import '../../private/dw_singleton.dart';

extension DwAuthRequestVerification on DwAuthRequest {
  /// Whether the request carries a credential issued by a third party, which
  /// only the app can validate (see [DwAuthConfig.verifyExternalCredential]).
  ///
  /// Email and phone are DartWay's own identifier + verification-code flows and
  /// must never take that path: an app doing phone OTP configures no external
  /// verifier, and treating phone as external would reject every login.
  ///
  /// The switch is exhaustive on purpose — a new provider has to be classified,
  /// not silently inherit a default.
  bool get isExternalProvider => switch (authProvider) {
    DwAuthProvider.email || DwAuthProvider.phone => false,
    DwAuthProvider.google ||
    DwAuthProvider.apple ||
    DwAuthProvider.telegram ||
    DwAuthProvider.other => true,
  };

  void setFailed(Session session, DwAuthFailReason reason) {
    // TODO: setup alerting
    session.log('Auth failed: $reason', level: LogLevel.warning);

    status = DwAuthRequestStatus.failed;
    failReason = reason;
    return;
  }

  Future<TableRow?> findRelatedUserProfile(Session session) async {
    final userProfile = await dw.getUserProfileByIdentifier(
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
    if (isExternalProvider) {
      final verifyExternal = dw.auth!.config.verifyExternalCredential;

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

    // Two request types claim an identifier that must be free rather than
    // present: a registration, and a signed-in person moving their phone or
    // address onto their own account. For both, finding a profile is the
    // failure and finding none is the happy path — the mirror image of a
    // sign-in.
    final claimsFreeIdentifier =
        requestType == DwAuthRequestType.register ||
        requestType == DwAuthRequestType.changeIdentifier;

    if (!claimsFreeIdentifier && userProfile == null) {
      return setFailed(session, DwAuthFailReason.userNotFound);
    }

    if (claimsFreeIdentifier && userProfile != null) {
      return setFailed(session, DwAuthFailReason.userAlreadyExists);
    }

    if (requestType == DwAuthRequestType.changeIdentifier) {
      // Refused here rather than after the code has been sent: an app that
      // never said where a verified identifier goes cannot finish this flow,
      // and finding that out at the end costs the person an SMS and the belief
      // that their address changed.
      if (!dw.canAttachVerifiedIdentifier) {
        return setFailed(session, DwAuthFailReason.userNotFound);
      }

      // The account being changed is the caller's own, and it is read from the
      // session rather than from the request: `userId` arrives on a model the
      // client sends, so taking it at its word would let anyone write an
      // identifier onto anyone's profile.
      final callerProfileId = session.signedInUserProfileId;
      if (callerProfileId == null) {
        return setFailed(session, DwAuthFailReason.userNotFound);
      }
      userId = callerProfileId;
    }

    if (password != null) {
      final userPassword = await DwUserPassword.db.findFirstRow(
        session,
        where: (t) => t.userId.equals(userId),
      );
      if (userPassword == null) {
        return setFailed(session, DwAuthFailReason.passwordNotSet);
      }

      // Reads whichever format the hash is in — and quietly upgrades a legacy
      // one to the active hasher, so a migrated user pays that path only once.
      final isValid = await dw.auth!.verifyPassword(
        session,
        userId: userId!,
        password: password!,
        storedHash: userPassword.passwordHash,
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
        final DwAuthKey authKey;
        try {
          authKey = await dw.auth!.signInUser(session, userId!);
        } on DwAuthKeyIssuanceRejectedException catch (rejection) {
          // A final key-issuance guard (e.g. the user was deleted mid-flow)
          // rejected the sign-in; surface it as a typed auth failure.
          setFailed(session, rejection.reason);
          return [];
        }
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

        await dw.auth!.setUserPassword(
          session,
          userId: userId!,
          newPassword: newPassword,
        );

        return [];
      case DwAuthRequestType.changeIdentifier:
        // Nobody is being signed in here — the caller already is. What travels
        // back is the profile carrying its new value, so the screen that asked
        // redraws without a second read.
        final updatedProfile = await dw.attachVerifiedIdentifier(
          session,
          userId: userId!,
          verifiedRequest: this,
        );

        if (updatedProfile == null) {
          // Either the app never said where a verified identifier goes, or the
          // account disappeared mid-flow. Both leave the person having proved
          // an address that was then not written, so the request says so
          // instead of reporting success.
          setFailed(session, DwAuthFailReason.userNotFound);
          return [];
        }

        return [DwModelWrapper(object: updatedProfile as SerializableModel)];

      case DwAuthRequestType.register:
        userId = await dw.createUserProfile(session, registrationRequest: this);

        userProfile = await dw.getUserProfile(session, userId!);

        if (newPassword != null) {
          await dw.auth!.setUserPassword(
            session,
            userId: userId!,
            newPassword: newPassword,
          );
        }

        final authKey = await dw.auth!.signInUser(session, userId!);

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
