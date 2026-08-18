import 'dart:async';

import 'package:dartway_studio_bridge/dartway_studio_bridge.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

/// The app at the other end of the probe. Everything it hears and says crosses
/// the wire first — encoded and decoded exactly as the real channel would — so
/// nothing passes here that would not survive `postMessage`.
class _FakeApp implements StudioMessageChannel {
  final _incoming = StreamController<StudioBridgeMessage>.broadcast();
  final heard = <StudioBridgeMessage>[];
  bool disposed = false;

  @override
  Stream<StudioBridgeMessage> get messages => _incoming.stream;

  @override
  void send(StudioBridgeMessage message) {
    final decoded = StudioBridgeMessage.tryDecode(message.encode());
    expect(decoded, isNotNull);
    heard.add(decoded!);
  }

  @override
  void dispose() {
    disposed = true;
    _incoming.close();
  }

  void say(StudioBridgeMessage message) {
    final decoded = StudioBridgeMessage.tryDecode(message.encode());
    expect(decoded, isNotNull);
    _incoming.add(decoded!);
  }

  Iterable<T> of<T extends StudioBridgeMessage>() => heard.whereType<T>();
}

void main() {
  late _FakeApp app;

  setUp(() => app = _FakeApp());
  tearDown(() => app.dispose());

  const manifest = StudioProjectManifest(projectName: 'Demo', zones: []);
  const manifestAnswer = ManifestMessage(
    manifest: manifest,
    currentPath: '/schedule',
    session: StudioSessionState.signedOut,
  );

  /// Runs the handshake and answers it once the connect has actually arrived,
  /// the way an app that is already loaded would.
  Future<StudioHandshakeResult> probe(
    void Function() answer, {
    StudioAccessTokenSupplier? accessToken,
    Duration timeout = const Duration(seconds: 5),
  }) {
    final result = runStudioHandshake(
      app,
      accessToken: accessToken,
      timeout: timeout,
    );
    return pumpEventQueue().then((_) {
      answer();
      return result;
    });
  }

  test('the manifest means the token was accepted', () async {
    expect(
      await probe(() => app.say(manifestAnswer)),
      StudioHandshakeResult.accepted,
    );
  });

  test('a refusal means the app is there and would not have us', () async {
    expect(
      await probe(() => app.say(const ConnectRefusedMessage())),
      StudioHandshakeResult.rejected,
    );
  });

  test('no answer at all is silence, not a hang', () {
    // The channel is built inside the fake zone on purpose: a stream created
    // outside it delivers on the real clock, and half of this test would then
    // be waiting on a queue `elapse` cannot reach.
    fakeAsync((async) {
      final silentApp = _FakeApp();
      StudioHandshakeResult? result;
      unawaited(
        runStudioHandshake(
          silentApp,
          timeout: const Duration(seconds: 10),
        ).then((value) => result = value),
      );

      async.elapse(const Duration(seconds: 9));
      expect(result, isNull, reason: 'gave up before the timeout was out');

      async.elapse(const Duration(seconds: 2));
      expect(result, StudioHandshakeResult.silent);
      silentApp.dispose();
    });
  });

  test('the token presented is the one the supplier handed over', () async {
    await probe(
      () => app.say(manifestAnswer),
      accessToken: () async => 'a-token',
    );

    expect(app.of<StudioConnectMessage>().single.accessToken, 'a-token');
  });

  test('no supplier presents nothing, which only local dev accepts', () async {
    await probe(() => app.say(manifestAnswer));

    expect(app.of<StudioConnectMessage>().single.accessToken, '');
  });

  test('a supplier that fails leaves the question unasked', () async {
    await expectLater(
      runStudioHandshake(app, accessToken: () => throw StateError('no token')),
      throwsStateError,
    );

    expect(app.heard, isEmpty);
  });

  test('an app that announces itself late is asked again', () async {
    // The ordinary case: the frame is still loading, so the first connect is
    // spoken into an empty page and only the second one is heard.
    final result = runStudioHandshake(app, accessToken: () => 'a-token');
    await pumpEventQueue();
    expect(app.of<StudioConnectMessage>(), hasLength(1));

    app.say(const AppReadyMessage());
    await pumpEventQueue();
    expect(
      app.of<StudioConnectMessage>().map((m) => m.accessToken),
      ['a-token', 'a-token'],
      reason: 'the app that just attached was never asked',
    );

    app.say(manifestAnswer);
    expect(await result, StudioHandshakeResult.accepted);
  });

  test('the clock starts when the question is asked, not before', () {
    fakeAsync((async) {
      final slowApp = _FakeApp();
      final slowToken = Completer<String>();
      StudioHandshakeResult? result;
      unawaited(
        runStudioHandshake(
          slowApp,
          accessToken: () => slowToken.future,
          timeout: const Duration(seconds: 10),
        ).then((value) => result = value),
      );

      // A supplier that takes its time must not eat the app's answer window.
      async.elapse(const Duration(seconds: 30));
      expect(result, isNull);
      expect(slowApp.of<StudioConnectMessage>(), isEmpty);

      slowToken.complete('a-token');
      async.flushMicrotasks();
      expect(slowApp.of<StudioConnectMessage>(), hasLength(1));

      async.elapse(const Duration(seconds: 11));
      expect(result, StudioHandshakeResult.silent);
      slowApp.dispose();
    });
  });

  test('reports the probe never asked for are not answers', () async {
    final result = runStudioHandshake(app, timeout: const Duration(seconds: 5));
    await pumpEventQueue();

    app.say(const RouteChangedMessage('/ad/123'));
    app.say(const LocaleChangedMessage('ru'));
    app.say(const SessionChangedMessage(StudioSessionState.signedOut));
    await pumpEventQueue();

    app.say(const ConnectRefusedMessage());
    expect(await result, StudioHandshakeResult.rejected);
  });

  test('the channel is left for its owner to dispose', () async {
    await probe(() => app.say(manifestAnswer));
    expect(app.disposed, isFalse);
  });
}
