import 'package:dartway_core_flutter/dartway_core_flutter.dart';
import 'package:flutter/foundation.dart';

/// Signs the app in and out on Studio's request, through the app's regular
/// sign-in by code — ask for a code, confirm the one Studio sent.
///
/// The server accepts that code when its `DwAuthConfig.fixedCode` says so (the
/// reviewer and test-account code), so the app ships no test users and no
/// special sign-in path: Studio holds the personas, the app holds nothing. No
/// navigation either — the router guards move the app between the auth zone
/// and the rest when the session changes.
class DwStudioPersonaSwitcher {
  DwStudioPersonaSwitcher(this._core);

  final DwFlutterCore _core;

  /// True while a requested sign-in or sign-out is in flight — Studio shows it
  /// as a pending state instead of a session that refuses to change.
  final ValueNotifier<bool> isBusy = ValueNotifier(false);

  /// The kind an identifier is: what Studio sends is a phone or an e-mail,
  /// and the server normalises it either way.
  static DwIdentifierKind kindOf(String identifier) => identifier.contains('@')
      ? DwIdentifierKind.email
      : DwIdentifierKind.phone;

  Future<void> signInWith({
    required String identifier,
    required String verificationCode,
  }) async {
    if (isBusy.value) return;
    isBusy.value = true;
    try {
      if (_core.client.accountId != null) await _core.signOut();
      final ticket = await _core.client.command(
        DwRequestCode(kind: kindOf(identifier), identifier: identifier),
      );
      switch (ticket) {
        case DwCallOk(:final value):
          final session = await _core.client.command(
            DwVerifyCode(ticketId: value.id, code: verificationCode),
          );
          switch (session) {
            case DwCallOk(:final value):
              await _core.signIn(value);
            case DwCallRefused():
              _core.notify.error(
                'Studio sign-in was refused: check the persona code.',
              );
            case DwCallResult():
              _core.notify.error('Studio sign-in failed. Is the server up?');
          }
        case DwCallRefused():
          _core.notify.error(
            'Studio sign-in was refused: is this persona seeded?',
          );
        case DwCallResult():
          _core.notify.error('Studio sign-in failed. Is the server up?');
      }
    } catch (_) {
      _core.notify.error('User switch failed. Is the local backend running?');
    } finally {
      isBusy.value = false;
    }
  }

  Future<void> signOutCurrentUser() async {
    if (isBusy.value) return;
    isBusy.value = true;
    try {
      await _core.signOut();
    } catch (_) {
      _core.notify.error('Sign out failed.');
    } finally {
      isBusy.value = false;
    }
  }

  void dispose() => isBusy.dispose();
}
