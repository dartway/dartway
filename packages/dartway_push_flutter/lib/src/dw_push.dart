import 'dart:async';

import 'package:dartway_core_flutter/dartway_core_flutter.dart';
import 'package:dartway_push_shared/dartway_push_shared.dart';
import 'package:flutter/foundation.dart';

import 'dw_push_notifications.dart';
import 'dw_push_transport_client.dart';

/// Push notifications for a DartWay app — `dw.plugins.push`.
///
/// ```dart
/// dw = DwFlutterCore(
///   ...,
///   protocol: DwWireProtocol(dwPushProtocolEntries, include: appProtocol),
///   plugins: [
///     DwSharedPreferences(),
///     DwPush(transports: [DwRuStorePush(), DwFirebasePush(webVapidKey: key)]),
///   ],
/// );
///
/// dw.plugins.push.opened.listen((opened) => router.go(opened.link ?? '/'));
/// await dw.plugins.push.requestPermission();   // when the user understands why
/// ```
///
/// On `dw.init()` it picks the first transport this platform and device can
/// use, starts listening, and from then on keeps the server's registration in
/// step with two facts that arrive independently: the device token and the
/// signed-in account. Whenever both are known and that pair has not been
/// registered, it sends `DwRegisterPushToken` — once per pair: a token
/// refresh, a sign-in and an account switch each cost one call, a restart
/// costs one, repeats cost none. A sign-out needs no call: the registration is
/// bound to the session key, and the server stops sending when it is revoked.
///
/// Everything it needs comes from the core it is initialized with; it never
/// reads the app's `dw`, which does not exist yet while its constructor runs
/// (#54).
class DwPush extends DwFlutterPlugin {
  DwPush({
    required List<DwPushTransportClient> transports,
    this.platform,
    this.isEnabled,
  }) : transports = List.unmodifiable(transports);

  /// The transports this app ships, most preferred first: the first that
  /// supports the platform and is available on the device is used.
  final List<DwPushTransportClient> transports;

  /// The platform registered with the token; by default this build's.
  final DwPushPlatform? platform;

  /// Whether the user wants notifications on this device, as the app keeps
  /// it; asked once at start. `false` starts paused — no registration until
  /// [resume]. Without it push is on.
  final Future<bool> Function()? isEnabled;

  /// A failing transport costs push, not the app.
  @override
  bool get blocksStartup => false;

  late final DwFlutterCore _core;
  DwPushTransportClient? _transport;
  StreamSubscription<int?>? _accounts;

  String? _token;
  int? _accountId;
  (int, String)? _registered;
  bool _registering = false;

  final List<DwPushOpened> _pendingOpens = [];
  late final StreamController<DwPushOpened> _opened =
      StreamController.broadcast(onListen: _flushOpens);
  final StreamController<DwPushReceived> _received =
      StreamController.broadcast();

  /// The transport in use; `null` when none can run here.
  DwPushTransportClient? get transport => _transport;

  /// The device token, once issued.
  String? get token => _token;

  /// Opened notifications. Those opened before anything listened — the one
  /// that started the app — are held and delivered to the first listener.
  Stream<DwPushOpened> get opened => _opened.stream;

  /// Notifications that arrived while the app was on screen.
  Stream<DwPushReceived> get received => _received.stream;

  @override
  Future<void> init(DwFlutterToolbox core) async {
    if (core is! DwFlutterCore) {
      throw StateError(
        'DwPush registers tokens through the data layer: declare it on a '
        'DwFlutterCore, not a plain DwFlutterToolbox.',
      );
    }
    _core = core;
    for (final type in [DwRegisterPushToken, DwUnregisterPushToken]) {
      if (!core.client.protocol.knows(type)) {
        throw StateError(
          'The app protocol does not register $type: build it as '
          'DwWireProtocol(dwPushProtocolEntries, include: appProtocol).',
        );
      }
    }
    _paused = !(await isEnabled?.call() ?? true);
    _transport = await _select();
    final transport = _transport;
    if (transport == null) return;

    // The account first: the client reads the stored session after the
    // plugins start, and its stream replays whatever it holds.
    _accounts = core.client.accountIdStream.listen((accountId) {
      // A sign-out revokes the key the registration was bound to: the next
      // sign-in, even as the same account, registers under its new key.
      if (accountId == null) _registered = null;
      _accountId = accountId;
      unawaited(_sync());
    });
    await transport.attach(
      DwPushTransportEvents(
        onToken: _onToken,
        onOpened: _onOpened,
        onReceived: _onReceived,
      ),
    );
    if (await transport.permission() == DwPushPermission.granted) {
      await _fetchToken();
    }
    if (await transport.takeInitialOpen() case final data?) {
      _onOpened(data, DwPushOpenSource.coldStart);
    }
  }

  /// Asks the user for permission — at a moment they understand why — and
  /// registers the token when the answer is yes.
  Future<DwPushPermission> requestPermission() async {
    final transport = _transport;
    if (transport == null) return DwPushPermission.unsupported;
    final answer = await transport.requestPermission();
    if (answer == DwPushPermission.granted) await _fetchToken();
    return answer;
  }

  /// The permission as it stands, without asking.
  Future<DwPushPermission> permission() async =>
      await _transport?.permission() ?? DwPushPermission.unsupported;

  /// The user turned notifications off in the app: removes this device's
  /// registration for the signed-in account and registers nothing until
  /// [resume]. The choice is the app's to keep ([isEnabled]).
  Future<DwCallResult<void>?> pause() async {
    _paused = true;
    final token = _token;
    if (token == null || _core.client.accountId == null) return null;
    final result = await _core.client.command(
      DwUnregisterPushToken(token: token),
    );
    if (result is DwCallOk<void>) _registered = null;
    return result;
  }

  bool _paused = false;

  /// Registers again after [pause].
  Future<void> resume() async {
    _paused = false;
    await _sync();
  }

  Future<void> dispose() async {
    await _accounts?.cancel();
    await _transport?.detach();
    await _opened.close();
    await _received.close();
  }

  Future<DwPushTransportClient?> _select() async {
    for (final candidate in transports) {
      if (!candidate.isSupportedPlatform) continue;
      if (await candidate.isAvailable()) return candidate;
    }
    return null;
  }

  Future<void> _fetchToken() async {
    final token = await _transport?.token();
    if (token != null && token.isNotEmpty) _onToken(token);
  }

  void _onToken(String token) {
    if (token == _token) return;
    _token = token;
    unawaited(_sync());
  }

  /// Registers the current (account, token) pair unless it already is. One
  /// call at a time; a change that arrives during a call is caught up after
  /// it.
  Future<void> _sync() async {
    if (_registering || _paused) return;
    final accountId = _accountId;
    final token = _token;
    final transport = _transport;
    if (accountId == null || token == null || transport == null) return;
    if (_registered == (accountId, token)) return;
    _registering = true;
    try {
      final result = await _core.client.command(
        DwRegisterPushToken(
          transport: transport.transport,
          token: token,
          platform: platform ?? _currentPlatform(),
        ),
      );
      switch (result) {
        case DwCallOk():
          // The pair the call was made for, whatever changed meanwhile.
          _registered = (accountId, token);
        case DwNotAuthenticated():
          break; // Signed out meanwhile; the next sign-in registers.
        case DwCallRefused(:final refusal):
          _core.handleError(
            StateError('The push token was refused: ${refusal.code}'),
            StackTrace.current,
            source: DwErrorSource.client,
          );
        case DwCallFailed():
          _core.handleError(
            StateError('Registering the push token failed: $result'),
            StackTrace.current,
            source: DwErrorSource.client,
          );
      }
    } catch (error, stackTrace) {
      // Offline past the call deadline: the next token, sign-in or restart
      // tries again.
      _core.handleError(error, stackTrace, source: DwErrorSource.client);
    } finally {
      _registering = false;
    }
    if (_accountId != accountId || _token != token) await _sync();
  }

  void _onOpened(Map<Object?, Object?> data, DwPushOpenSource source) {
    final read = _read(data);
    final opened = DwPushOpened(
      source: source,
      payload: read.payload,
      link: read.link,
    );
    if (_opened.hasListener) {
      _opened.add(opened);
    } else {
      _pendingOpens.add(opened);
    }
  }

  void _flushOpens() {
    final pending = List.of(_pendingOpens);
    _pendingOpens.clear();
    // After the listener's `listen` returns, so it is attached to receive.
    scheduleMicrotask(() => pending.forEach(_opened.add));
  }

  void _onReceived(String? title, String? body, Map<Object?, Object?> data) {
    final read = _read(data);
    _received.add(
      DwPushReceived(
        title: title ?? data[DwPushData.titleKey] as String?,
        body: body ?? data[DwPushData.bodyKey] as String?,
        payload: read.payload,
        link: read.link,
      ),
    );
  }

  /// The payload and link of [data]. A payload this build cannot read — a
  /// newer server's class — is reported, and the link still opens.
  DwPushData _read(Map<Object?, Object?> data) {
    try {
      return DwPushData.fromWire(data, _core.client.protocol);
    } on FormatException catch (error, stackTrace) {
      _core.handleError(error, stackTrace, source: DwErrorSource.client);
      final link = data[DwPushData.linkKey];
      return DwPushData(link: link is String && link.isNotEmpty ? link : null);
    }
  }

  static DwPushPlatform _currentPlatform() {
    if (kIsWeb) return DwPushPlatform.web;
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => DwPushPlatform.android,
      TargetPlatform.iOS => DwPushPlatform.ios,
      TargetPlatform.macOS => DwPushPlatform.macos,
      _ => DwPushPlatform.other,
    };
  }
}

/// `dw.plugins.push`.
extension DwPushAccess on DwPluginRegistry {
  DwPush get push => of<DwPush>();
}
