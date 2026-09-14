import 'dart:io';

import 'package:dartway_core_server/dartway_core_server.dart';
import 'package:test/test.dart';

import 'support/test_app.dart';

/// A graceful stop: in-flight calls are answered, sockets close with 1001,
/// nothing new is accepted.
void main() {
  test('stop answers the calls in flight and their updates, closes live '
      'sockets with 1001, and accepts nothing after', () async {
    final harness = await Harness.start();
    var stopped = false;
    addTearDown(() async {
      if (!stopped) await harness.stop();
    });
    final (author, session) = await harness.signedIn('stop@example.com');
    final socket = await harness.live(token: session.token);
    expect(await socket.subscribe('notes'), isA<DwSubscribedMessage>());
    final (_, otherSession) = await harness.signedIn('stop-l@example.com');
    final listener = await harness.live(token: otherSession.token);
    expect(await listener.subscribe('notes'), isA<DwSubscribedMessage>());

    final slow = harness.caller().call(const SlowRequest(500));
    await Future<void>.delayed(const Duration(milliseconds: 100));
    final port = harness.server.port;
    final stopping = harness.server.stop();
    await Future<void>.delayed(const Duration(milliseconds: 50));

    // A new connection is refused while the call in flight still runs.
    await expectLater(
      Socket.connect('127.0.0.1', port),
      throwsA(isA<SocketException>()),
    );
    expect((await slow).status, 200);
    await stopping;
    expect(await socket.closeCode, DwCloseCode.serverStopping);
    expect(await listener.closeCode, DwCloseCode.serverStopping);
    expect(socket.closeReason, 'dw.serverStopping');
    stopped = true;
    await harness.database.drop();
    author.close();
  });

  test('a command in flight commits, answers and publishes before the '
      'sockets close', () async {
    final harness = await Harness.start();
    final (_, session) = await harness.signedIn('stop-cmd@example.com');
    final listener = await harness.live(token: session.token);
    expect(await listener.subscribe('notes'), isA<DwSubscribedMessage>());
    final author = harness.caller();
    final call = author.call(const SlowNote('last words', 400));
    await Future<void>.delayed(const Duration(milliseconds: 100));
    final stopping = harness.server.stop();
    final answer = await call;
    expect(answer.value(const SlowNote('', 0)).text, 'last words');
    final update = await listener.expect<DwUpdateMessage>();
    expect((update.updates.objects.single as NoteView).text, 'last words');
    await stopping;
    expect(await listener.closeCode, DwCloseCode.serverStopping);
    author.close();
    await harness.database.drop();
  });

  test(
    'a call still running at the stop timeout does not hold the stop',
    () async {
      final harness = await Harness.start(
        build: (app, config) => app.server(
          config,
          settings: const DwServerSettings(
            stopTimeout: Duration(milliseconds: 300),
          ),
        ),
      );
      final caller = harness.caller();
      final call = caller
          .call(const SlowRequest(3000))
          .then<Object>((answer) => answer, onError: (Object error) => error);
      await Future<void>.delayed(const Duration(milliseconds: 100));
      final watch = Stopwatch()..start();
      await harness.server.stop();
      expect(watch.elapsed, lessThan(const Duration(seconds: 2)));
      expect(await call, isA<IOException>(), reason: 'cut off, not answered');
      caller.close();
      await harness.database.drop();
      expect(
        RecordingLogger.lines.any((l) => l.contains('still running at stop')),
        isTrue,
      );
    },
  );
}
