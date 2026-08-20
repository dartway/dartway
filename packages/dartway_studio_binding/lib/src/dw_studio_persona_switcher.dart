import 'package:dartway_serverpod_core_flutter/dartway_serverpod_core_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Signs the app in and out on Studio's request, through the app's regular
/// OTP flow — request a code, submit the one Studio sent, complete.
///
/// The server accepts that code when it matches the user's
/// `testVerificationCode` (or the dev-mode code), so the app ships no test
/// users and no special sign-in path: Studio holds the personas, the app holds
/// nothing. No manual navigation either — the router guards move the app
/// between the auth zone and the rest on session changes.
class DwStudioPersonaSwitcher {
  DwStudioPersonaSwitcher(this._core, this._ref);

  final DwCore<ServerpodClientShared, SerializableModel> _core;
  final WidgetRef _ref;

  /// True while a requested sign-in or sign-out is in flight — Studio shows it
  /// as a pending state instead of a session that refuses to change.
  final ValueNotifier<bool> isBusy = ValueNotifier(false);

  /// An app configured without an auth key manager has no session to switch.
  /// Studio may still preview it; the persona controls simply have nothing to
  /// act on, and saying so beats a null check failing mid-flow.
  bool get _hasSession => _core.sessionProvider != null;

  Future<void> signInWith({
    required String identifier,
    required String verificationCode,
  }) async {
    if (isBusy.value) return;
    if (!_hasSession) {
      _core.notify.error('This app has no session to switch personas on.');
      return;
    }
    isBusy.value = true;
    try {
      if (_ref.read(_core.userProfileProvider) != null) {
        await _ref.read(_core.sessionProvider!.notifier).signOut();
      }

      final request = await _core.repo.saveModel(
        DwAuthRequest(
          requestType: DwAuthRequestType.login,
          userIdentifier: identifier,
          authProvider: DwAuthProvider.phone,
        ),
        apiGroupOverride: DwCoreConst.dartwayInternalApi,
      );
      if (request.status == DwAuthRequestStatus.failed) {
        _core.notify.error('Studio sign-in failed. Is this user seeded?');
        return;
      }

      final verification = await _core.repo.saveModel(
        DwAuthVerification(
          dwAuthRequestId: request.id!,
          verificationCode: verificationCode,
        ),
        apiGroupOverride: DwCoreConst.dartwayInternalApi,
      );
      final accessToken = verification.accessToken;
      if (accessToken == null) {
        _core.notify.error(
          'Verification code rejected. Check the persona config in Studio.',
        );
        return;
      }

      final completed = await _core.repo.saveModel(
        request.copyWith(accessToken: accessToken),
        apiGroupOverride: DwCoreConst.dartwayInternalApi,
      );
      if (completed.status != DwAuthRequestStatus.completed &&
          completed.status != DwAuthRequestStatus.verified) {
        _core.notify.error('Could not complete Studio sign-in.');
      }
    } catch (_) {
      _core.notify.error('User switch failed. Is the local backend running?');
    } finally {
      isBusy.value = false;
    }
  }

  Future<void> signOutCurrentUser() async {
    if (isBusy.value) return;
    if (!_hasSession) {
      _core.notify.error('This app has no session to sign out of.');
      return;
    }
    isBusy.value = true;
    try {
      await _ref.read(_core.sessionProvider!.notifier).signOut();
    } catch (_) {
      _core.notify.error('Sign out failed.');
    } finally {
      isBusy.value = false;
    }
  }

  void dispose() => isBusy.dispose();
}
