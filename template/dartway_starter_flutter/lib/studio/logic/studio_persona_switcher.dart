import 'package:dartway_serverpod_core_flutter/dartway_serverpod_core_flutter.dart';
import 'package:dartway_studio_bridge/dartway_studio_bridge.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/dw_core.dart';
import '../../core/router/router.dart';
import 'studio_personas.dart';

part 'studio_persona_switcher.g.dart';

/// Programmatic sign-in as a seeded persona: the regular OTP flow with the
/// fixed dev code. No manual navigation — the router guards move the app
/// between /auth and the club zone on session changes. State = busy flag.
@Riverpod(keepAlive: true)
class StudioPersonaSwitcher extends _$StudioPersonaSwitcher {
  @override
  bool build() => false;

  Future<void> switchTo(StudioPersonaSpec persona) async {
    if (state) return;
    state = true;
    try {
      if (ref.read(isSignedInProvider)) {
        await ref.read(dw.sessionProvider!.notifier).signOut();
      }

      final request = await DwRepository.saveModel(
        DwAuthRequest(
          requestType: DwAuthRequestType.login,
          userIdentifier: persona.identifier,
          authProvider: DwAuthProvider.phone,
        ),
        apiGroupOverride: DwCoreConst.dartwayInternalApi,
      );
      if (request.status == DwAuthRequestStatus.failed) {
        dw.notify.error('Dev sign-in failed. Did you run bin/seed_dev.dart?');
        return;
      }

      final verification = await DwRepository.saveModel(
        DwAuthVerification(
          dwAuthRequestId: request.id!,
          verificationCode: studioDevOtpCode,
        ),
        apiGroupOverride: DwCoreConst.dartwayInternalApi,
      );
      final accessToken = verification.accessToken;
      if (accessToken == null) {
        dw.notify.error(
          'Dev code rejected. Run the server in development mode.',
        );
        return;
      }

      final completed = await DwRepository.saveModel(
        request.copyWith(accessToken: accessToken),
        apiGroupOverride: DwCoreConst.dartwayInternalApi,
      );
      if (completed.status != DwAuthRequestStatus.completed &&
          completed.status != DwAuthRequestStatus.verified) {
        dw.notify.error('Could not complete dev sign-in.');
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
