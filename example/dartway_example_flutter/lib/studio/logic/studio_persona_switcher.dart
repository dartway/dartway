import 'package:dartway_serverpod_core_flutter/dartway_serverpod_core_flutter.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/dw_core.dart';
import '../../core/router/router.dart';

part 'studio_persona_switcher.g.dart';

/// Programmatic sign-in with credentials received from Studio: the regular
/// OTP flow, with the verification code Studio sent (the server accepts it
/// when it matches the user's testVerificationCode / dev-mode code). No
/// manual navigation — the router guards move the app between /auth and the
/// club zone on session changes. State = busy flag.
@Riverpod(keepAlive: true)
class StudioPersonaSwitcher extends _$StudioPersonaSwitcher {
  @override
  bool build() => false;

  Future<void> signInWith({
    required String identifier,
    required String verificationCode,
  }) async {
    if (state) return;
    state = true;
    try {
      if (ref.read(isSignedInProvider)) {
        await ref.read(dw.sessionProvider!.notifier).signOut();
      }

      final request = await dw.repo.saveModel(
        DwAuthRequest(
          requestType: DwAuthRequestType.login,
          userIdentifier: identifier,
          authProvider: DwAuthProvider.phone,
        ),
        apiGroupOverride: DwCoreConst.dartwayInternalApi,
      );
      if (request.status == DwAuthRequestStatus.failed) {
        dw.notify.error('Studio sign-in failed. Is this user seeded?');
        return;
      }

      final verification = await dw.repo.saveModel(
        DwAuthVerification(
          dwAuthRequestId: request.id!,
          verificationCode: verificationCode,
        ),
        apiGroupOverride: DwCoreConst.dartwayInternalApi,
      );
      final accessToken = verification.accessToken;
      if (accessToken == null) {
        dw.notify.error(
          'Verification code rejected. Check the persona config in Studio.',
        );
        return;
      }

      final completed = await dw.repo.saveModel(
        request.copyWith(accessToken: accessToken),
        apiGroupOverride: DwCoreConst.dartwayInternalApi,
      );
      if (completed.status != DwAuthRequestStatus.completed &&
          completed.status != DwAuthRequestStatus.verified) {
        dw.notify.error('Could not complete Studio sign-in.');
      }
    } catch (_) {
      dw.notify.error('User switch failed. Is the local backend running?');
    } finally {
      state = false;
    }
  }

  Future<void> signOutCurrentUser() async {
    if (state) return;
    state = true;
    try {
      await ref.read(dw.sessionProvider!.notifier).signOut();
    } catch (_) {
      dw.notify.error('Sign out failed.');
    } finally {
      state = false;
    }
  }
}
