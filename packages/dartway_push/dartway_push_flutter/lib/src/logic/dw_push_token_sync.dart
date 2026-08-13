import 'dart:async';

import 'package:flutter/foundation.dart';

/// Sends one token to the server. Returns false when the server declined it,
/// which is not the same as an error — see [DwPushTokenSync].
typedef DwPushTokenRegistrar =
    Future<bool> Function({required String token, required String provider});

/// Keeps the server's idea of this device's token in step with the platform's.
///
/// The two facts arrive independently and in either order: the platform issues
/// a token whenever it feels like it, the user signs in whenever they feel like
/// it, and a token registered against nobody is worthless. So this is written
/// as "have both? try" rather than as a reaction to one event — every input
/// nudges it, and it decides whether anything is actually left to do.
///
/// What it refuses to do is send the same thing twice. The triple that matters
/// is (token, provider, recipient): a refresh, a re-login as somebody else, or
/// the same app resuming ten times a day must each produce at most one call.
class DwPushTokenSync {
  DwPushTokenSync({required DwPushTokenRegistrar register})
    : _register = register;

  final DwPushTokenRegistrar _register;

  String? _pendingToken;
  String? _pendingProvider;
  int? _pendingRecipientId;

  String? _syncedToken;
  String? _syncedProvider;
  int? _syncedRecipientId;

  bool _isSyncing = false;

  String? get token => _pendingToken;

  /// A token was issued or refreshed. A genuinely new one invalidates what was
  /// synced before, so the next attempt goes through even for the same user.
  void onToken({required String token, required String provider}) {
    if (_pendingToken != token || _pendingProvider != provider) {
      _syncedToken = null;
      _syncedProvider = null;
      _syncedRecipientId = null;
    }
    _pendingToken = token;
    _pendingProvider = provider;
  }

  /// Sends the current token if there is one, somebody to attach it to, and it
  /// has not already been sent for exactly this combination.
  Future<void> sync({required int? recipientId}) async {
    _pendingRecipientId = recipientId;
    final token = _pendingToken;
    final provider = _pendingProvider;

    if (token == null || provider == null || recipientId == null) return;
    if (_isSyncing) return;
    if (_syncedToken == token &&
        _syncedProvider == provider &&
        _syncedRecipientId == recipientId) {
      return;
    }

    _isSyncing = true;
    try {
      if (await _register(token: token, provider: provider)) {
        _syncedToken = token;
        _syncedProvider = provider;
        _syncedRecipientId = recipientId;
      }
    } catch (error) {
      // Nothing louder than a debug line: a phone that is offline at launch is
      // the ordinary case, and the next nudge retries anyway.
      debugPrint('DwPush: sending the device token failed: $error');
    } finally {
      _isSyncing = false;
    }

    // The world may have moved while the call was in flight — a refreshed
    // token, a different user — and that attempt was suppressed by the guard
    // above. Catch up with whatever is current now.
    if (_pendingToken != token ||
        _pendingProvider != provider ||
        _pendingRecipientId != recipientId) {
      unawaited(sync(recipientId: _pendingRecipientId));
    }
  }

  /// Forgets what was sent, without forgetting the token itself.
  ///
  /// Sign-out: the token is still this device's, but it is no longer attached
  /// to anyone, and the next person to sign in here has to be registered even
  /// though the token never changed.
  void forgetRegistration() {
    _syncedToken = null;
    _syncedProvider = null;
    _syncedRecipientId = null;
  }

  /// Forgets the token as well — it has been handed back to the server.
  void forgetToken() {
    forgetRegistration();
    _pendingToken = null;
    _pendingProvider = null;
  }
}
