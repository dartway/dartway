import 'dart:async';

import 'package:dartway_push_client/dartway_push_client.dart';
// Re-exports dartway_flutter (DwPlugin, DwPlugins) along with the data layer.
import 'package:dartway_serverpod_core_flutter/dartway_serverpod_core_flutter.dart';
import 'package:flutter/foundation.dart';

import 'dw_push_config.dart';
import 'dw_push_notification.dart';
import 'dw_push_provider.dart';
import 'logic/dw_push_token_sync.dart';

/// Push notifications for a DartWay app — `dw.plugins.push`.
///
/// Owns the part that is the same whoever delivers the message: pick the
/// transport this device can actually use, ask for permission once, keep the
/// server's copy of the token in step with the platform's, and make sure a tap
/// reaches the app exactly once whether it was cold, backgrounded or already on
/// screen. It ships no vendor SDK; the transports arrive as separate packages.
///
/// Declared like any plugin, and driven by a [DwPushScope] in the widget tree:
///
/// ```dart
/// dw = DwCore(
///   plugins: [DwPush(config: DwPushConfig(providers: [DwFirebasePush()]))],
/// );
/// ```
class DwPush extends DwPlugin {
  DwPush({required this.config});

  final DwPushConfig config;

  final ValueNotifier<String?> _token = ValueNotifier<String?>(null);
  final List<DwPushOpened> _pendingOpens = [];

  late final DwPushTokenSync _tokenSync = DwPushTokenSync(
    register: config.registerToken ?? _registerThroughCrudAction,
  );

  DwPushClientProvider? _provider;
  int? _recipientId;
  bool _isAttached = false;
  bool _isAttaching = false;
  bool _canDeliverOpens = false;

  /// The current device token, once a transport has issued one. Listenable so a
  /// debug screen can show it; an app has no other reason to read it.
  ValueListenable<String?> get token => _token;

  /// The transport actually in use, or null while push is off or unavailable.
  DwPushClientProvider? get provider => _provider;

  /// Nothing happens here. Transports are started by [DwPushScope], because a
  /// permission prompt before the first frame is a prompt with no app behind
  /// it, and a notification tap has nowhere to go until the tree is up.
  @override
  Future<void> init() async {}

  // --- Driven by DwPushScope -------------------------------------------------

  Future<void> attach() async {
    if (_isAttached || _isAttaching) return;
    _isAttaching = true;
    try {
      final isEnabled = config.isEnabled;
      if (isEnabled != null && !await isEnabled()) {
        debugPrint('DwPush: disabled for this build');
        return;
      }

      final provider = await _selectProvider();
      if (provider == null) {
        debugPrint('DwPush: no push transport is available on this device');
        return;
      }
      _provider = provider;
      _isAttached = true;

      await provider.attach(
        DwPushProviderCallbacks(
          onToken: _onToken,
          onOpened: _onOpened,
          onReceived: (message) => config.onReceived?.call(message),
        ),
      );

      if (config.requestPermissionOnAttach) {
        final permission = await provider.requestPermission();
        if (permission != DwPushPermission.granted &&
            permission != DwPushPermission.unsupported) {
          // Attached but silent: a refusal can be reversed from the settings
          // screen, and the transport must already be listening when it is.
          debugPrint('DwPush: notifications not granted (${permission.name})');
          return;
        }
      }

      final token = await provider.requestToken();
      if (token != null && token.isNotEmpty) _onToken(token);

      final initialPayload = await provider.takeInitialPayload();
      if (initialPayload != null) {
        _onOpened(initialPayload, DwPushOpenSource.coldStart);
      }
    } finally {
      _isAttaching = false;
    }
  }

  Future<void> detach() async {
    _canDeliverOpens = false;
    if (!_isAttached) return;
    _isAttached = false;
    final provider = _provider;
    _provider = null;
    await provider?.detach();
  }

  /// Who the token belongs to now. Null while signed out.
  void setRecipient(int? recipientId) {
    if (_recipientId == recipientId) return;
    if (recipientId == null) {
      // The token is still this device's; it is simply attached to nobody. The
      // next person to sign in here must be registered even though the platform
      // never issued a new token.
      _tokenSync.forgetRegistration();
    }
    _recipientId = recipientId;
    unawaited(_tokenSync.sync(recipientId: recipientId));
  }

  /// Lets buffered taps through, and flushes whatever arrived before the app
  /// was ready for them.
  void markReadyForOpens(void Function(void Function()) runAfterFrame) {
    _canDeliverOpens = true;
    if (_pendingOpens.isEmpty) return;
    final pending = List<DwPushOpened>.of(_pendingOpens);
    _pendingOpens.clear();
    runAfterFrame(() {
      for (final opened in pending) {
        config.onOpened?.call(opened);
      }
    });
  }

  // --- Called by the app -----------------------------------------------------

  /// Asks the user for permission at a moment of the app's choosing — pair it
  /// with `requestPermissionOnAttach: false`.
  ///
  /// Requests a token as well when the answer is yes, so a user who agrees late
  /// does not wait for the next launch to become reachable.
  Future<DwPushPermission> requestPermission() async {
    final provider = _provider;
    if (provider == null) return DwPushPermission.unsupported;
    final permission = await provider.requestPermission();
    if (permission == DwPushPermission.granted) {
      final token = await provider.requestToken();
      if (token != null && token.isNotEmpty) _onToken(token);
    }
    return permission;
  }

  /// The current permission state, without asking for anything.
  Future<DwPushPermission> permission() async =>
      await _provider?.currentPermission() ?? DwPushPermission.unsupported;

  /// Hands the token back to the server — **call it before signing out**, while
  /// the session is still valid. Afterwards there is nobody to authenticate the
  /// call, and the device would keep receiving the previous user's
  /// notifications until the server next fails to deliver to it.
  Future<void> revokeToken() async {
    final token = _tokenSync.token;
    if (token == null || _recipientId == null) return;
    try {
      await const DwRepo().saveModel(
        DwPushTokenRegistration(
          token: token,
          provider: _provider?.id,
          revoke: true,
        ),
      );
      _tokenSync.forgetToken();
      _token.value = null;
    } catch (error) {
      debugPrint('DwPush: handing the device token back failed: $error');
    }
  }

  // --- Internals -------------------------------------------------------------

  /// The first declared transport that both fits the platform and answers for
  /// itself on this device.
  Future<DwPushClientProvider?> _selectProvider() async {
    for (final candidate in config.providers) {
      if (!candidate.isSupportedPlatform) continue;
      if (!await candidate.isAvailable()) {
        debugPrint('DwPush: ${candidate.id} is not available on this device');
        continue;
      }
      return candidate;
    }
    return null;
  }

  void _onToken(String token) {
    final provider = _provider;
    if (provider == null) return;
    _token.value = token;
    _tokenSync.onToken(token: token, provider: provider.id);
    unawaited(_tokenSync.sync(recipientId: _recipientId));
  }

  void _onOpened(Map<String, String> data, DwPushOpenSource source) {
    final opened = DwPushOpened(
      data: Map.unmodifiable(data),
      source: source,
      link: data[dwPushLinkDataKey],
    );
    if (!_canDeliverOpens || config.onOpened == null) {
      // A cold start hands over its notification before anything can route it.
      // Held, not dropped: this is the tap that brought the user here.
      _pendingOpens.add(opened);
      return;
    }
    config.onOpened!.call(opened);
  }

  Future<bool> _registerThroughCrudAction({
    required String token,
    required String provider,
  }) async {
    await const DwRepo().saveModel(
      DwPushTokenRegistration(
        token: token,
        provider: provider,
        revoke: false,
      ),
    );
    return true;
  }
}

/// `dw.plugins.push`, declared here rather than in the framework — the core
/// must not carry a getter named after an integration.
extension DwPushAccess on DwPlugins {
  DwPush get push => of<DwPush>();
}
