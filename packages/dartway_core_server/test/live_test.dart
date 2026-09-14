import 'dart:io';

import 'package:dartway_core_server/dartway_core_server.dart';
import 'package:test/test.dart';

import 'support/test_app.dart';

/// The live socket's own protocol: the upgrade, frames, limits and pings.
void main() {
  final harness = useHarness(
    build: (app, config) => app.server(
      config,
      settings: const DwServerSettings(
        outboundLimitBytes: 256 * 1024,
        maxLiveMessageBytes: 1024,
        allowedOrigins: {'https://app.example.com', 'http://localhost:5000'},
      ),
    ),
  );

  test('the first message is hello with the connection id', () async {
    final socket = await harness().server.openLive(awaitHello: false);
    final hello = await socket.expect<DwHelloMessage>();
    expect(hello.connectionId, isNotEmpty);
    expect(
      socket.frames.first,
      '{"k":"hello","connection":"${hello.connectionId}"}',
    );
    await socket.close();
  });

  group('origin', () {
    test('a foreign browser origin is refused before the upgrade', () async {
      final server = harness().server;
      final port = server.port;
      for (final origin in [
        'https://evil.example',
        // The allow-list names full origins: the same host on another scheme
        // or port is another site.
        'http://app.example.com',
        'https://app.example.com:8443',
        // The server's own host on another port.
        'http://127.0.0.1:${port + 1}',
        // Opaque and malformed origins.
        'null',
        'file://',
        'app.example.com',
        'https://app.example.com/path',
      ]) {
        await expectLater(
          server.openLive(headers: {'Origin': origin}),
          throwsA(isA<WebSocketException>()),
          reason: origin,
        );
      }
    });

    test('the origin the upgrade was sent to and the allow-list may connect, '
        'and so may a native app without Origin', () async {
      final server = harness().server;
      final port = server.port;
      for (final origin in [
        'http://127.0.0.1:$port',
        'HTTP://127.0.0.1:$port',
        'https://app.example.com',
        'https://APP.example.com:443',
        'http://localhost:5000',
        null,
      ]) {
        final socket = await server.openLive(headers: {'Origin': ?origin});
        expect(socket.connectionId, isNotEmpty, reason: '$origin');
        await socket.close();
      }
    });
  });

  test('a plain GET of the live path is not an upgrade: 400', () async {
    final answer = await harness().caller().raw('GET', DwHttpContract.livePath);
    expect(answer.status, 400);
  });

  group('frames', () {
    test('a malformed message closes with 4000', () async {
      for (final frame in [
        'not json',
        '[1]',
        '{"k":"what"}',
        '{"k":"sub"}',
        '{"k":"auth","token":7}',
        '{"k":"sub","ch":"notes","extra":1}',
      ]) {
        final socket = await harness().server.openLive();
        socket.sendRaw(frame);
        expect(
          await socket.closeCode,
          DwCloseCode.protocolError,
          reason: frame,
        );
      }
    });

    test('a binary frame closes with 1003', () async {
      final socket = await harness().server.openLive();
      socket.sendRaw([1, 2, 3]);
      expect(await socket.closeCode, DwCloseCode.unsupportedData);
    });

    test('a message over the limit closes with 1009', () async {
      final socket = await harness().server.openLive();
      socket.sendRaw('{"k":"auth","token":"${'x' * 2000}"}');
      expect(await socket.closeCode, DwCloseCode.messageTooBig);
    });
  });

  test('a connection that does not read is closed as a slow consumer, and '
      'the others keep receiving', () async {
    final (_, slowSession) = await harness().signedIn('slow@example.com');
    final (_, fastSession) = await harness().signedIn('fast@example.com');
    final slow = await harness().live(token: slowSession.token);
    final fast = await harness().live(token: fastSession.token);
    for (final socket in [slow, fast]) {
      expect(await socket.subscribe('public'), isA<DwSubscribedMessage>());
    }
    final author = harness().caller();
    slow.pause();
    var fastUpdates = 0;
    for (var i = 0; i < 60 && !slow.isClosed; i++) {
      await author.call(const Burst(50, 10000));
      await fast.expect<DwUpdateMessage>();
      fastUpdates++;
    }
    slow.resume();
    expect(
      await slow.closeCode.timeout(const Duration(seconds: 20)),
      DwCloseCode.slowConsumer,
    );
    expect(slow.closeReason, 'dw.slowConsumer');
    expect(
      slow.frames.where((f) => f.contains('"upd"')).length,
      lessThan(fastUpdates),
    );
    await author.call(const Burst(1, 10));
    expect(await fast.expect<DwUpdateMessage>(), isA<DwUpdateMessage>());
  }, timeout: const Timeout(Duration(minutes: 2)));
}
