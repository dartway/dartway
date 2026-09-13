import 'dart:io';

import 'package:dartway_server/dartway_server.dart';
import 'package:test/test.dart';

import 'support/test_app.dart';

void main() {
  final harness = useHarness(
    build: (app, config) => app.server(
      config,
      settings: const DwServerSettings(
        pingInterval: Duration(milliseconds: 300),
      ),
    ),
  );

  test('a peer that does not answer pings is dropped', () async {
    final socket = await Socket.connect('127.0.0.1', harness().server.port);
    socket.write(
      'GET /dw?v=1 HTTP/1.1\r\nHost: 127.0.0.1\r\nUpgrade: websocket\r\n'
      'Connection: Upgrade\r\nSec-WebSocket-Version: 13\r\n'
      'Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==\r\n\r\n',
    );
    final watch = Stopwatch()..start();
    // Read (and ignore) everything, answering nothing.
    await socket.drain<void>().timeout(const Duration(seconds: 10));
    expect(watch.elapsedMilliseconds, lessThan(5000));
    socket.destroy();
  });
}
