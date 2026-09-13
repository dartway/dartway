import 'dart:convert';

import 'package:dartway_server/dartway_server.dart';
import 'package:test/test.dart';

import 'support/test_app.dart';

void main() {
  final harness = useHarness(
    build: (app, config) => app.server(
      config,
      settings: const DwServerSettings(
        outboundLimitBytes: 256 * 1024,
        maxInboundMessageBytes: 16 * 1024,
        maxConcurrentCalls: 2,
        maxWaitingCalls: 8,
        allowedOrigins: {'app.example.com'},
      ),
    ),
  );

  test('a connection that does not read is closed as a slow consumer, and '
      'the others keep receiving', () async {
    final (slow, _) = await harness().signedIn('slow@example.com');
    final (fast, _) = await harness().signedIn('fast@example.com');
    final author = await harness().connect();
    for (final c in [slow, fast]) {
      expect(await c.subscribe('public'), isA<DwSubscribedMessage>());
    }
    slow.pause();
    var fastUpdates = 0;
    for (var i = 0; i < 60 && !slow.isClosed; i++) {
      await author.command(const Burst(50, 10000));
      await fast.expect<DwUpdateMessage>();
      fastUpdates++;
      if (i == 59) break;
    }
    slow.resume();
    expect(
      await slow.closeCode.timeout(const Duration(seconds: 20)),
      DwCloseCode.slowConsumer,
    );
    expect(slow.closeReason, 'dw.slowConsumer');
    // The slow connection received less than was published.
    final slowUpdates = slow.buffered.whereType<DwUpdateMessage>().length;
    expect(slowUpdates, lessThan(fastUpdates));
    await author.command(const Burst(1, 10));
    expect(await fast.expect<DwUpdateMessage>(), isA<DwUpdateMessage>());
    await fast.close();
    await author.close();
  }, timeout: const Timeout(Duration(minutes: 2)));

  test('a browser origin on the allow-list may connect', () async {
    final connection = await harness().server.connect(
      headers: {'Origin': 'https://app.example.com'},
    );
    expect(
      (await connection.request(const ListNotes(ownerId: -1))).status,
      DwResultStatus.ok,
    );
    await connection.close();
  });

  test('an inbound message over the limit closes with 1009', () async {
    final connection = await harness().connect();
    connection.sendRaw(
      jsonEncode({
        'k': 'req',
        'id': 1,
        'dto': {'@t': 'ListNotes', 'pad': 'x' * 20000},
      }),
    );
    expect(await connection.closeCode, DwCloseCode.messageTooBig);
  });

  test('past the concurrent call limit the connection waits, and every call '
      'is answered', () async {
    final connection = await harness().connect();
    final watch = Stopwatch()..start();
    final results = await Future.wait([
      for (var i = 0; i < 6; i++) connection.request(const SlowRequest(200)),
    ]);
    expect(results.map((r) => r.status), everyElement(DwResultStatus.ok));
    // Two at a time: three rounds of 200 ms.
    expect(watch.elapsedMilliseconds, greaterThanOrEqualTo(550));
    await connection.close();
  });

  test(
    'more waiting calls than allowed close the connection with 4029',
    () async {
      final connection = await harness().connect();
      for (var i = 0; i < 20; i++) {
        connection.send(
          DwRequestMessage(id: 1000 + i, request: const SlowRequest(300)),
        );
      }
      expect(await connection.closeCode, DwCloseCode.tooManyCalls);
    },
  );

  test(
    'stop answers the running calls, then closes connections with 1001',
    () async {
      final connection = await harness().connect();
      final pending = connection.request(const SlowRequest(400));
      await Future<void>.delayed(const Duration(milliseconds: 100));
      await harness().server.stop();
      expect((await pending).status, DwResultStatus.ok);
      expect(await connection.closeCode, DwCloseCode.serverStopping);
    },
  );
}
