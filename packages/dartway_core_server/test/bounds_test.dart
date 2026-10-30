import 'dart:io';

import 'package:dartway_core_server/dartway_core_server.dart';
import 'package:test/test.dart';

import 'support/test_app.dart';

/// A list answered past its request's `maxItems`, and a response above
/// `largeResponseBytes` (dartway/dartway#644): the call fails in tests and on
/// a development server, and is served whole with a warning in production —
/// never cut short.
void main() {
  group('strict — a test server, whatever its settings', () {
    final harness = useHarness();
    late DwTestCaller caller;
    setUpAll(() => caller = harness().caller());

    test('a list within its bound is served', () async {
      const request = BoundedNotes(3);
      harness().app.boundReadLimits.clear();
      expect((await caller.call(request)).value(request), hasLength(3));
      expect(harness().app.boundReadLimits, [4]);
    });

    test('a list past its bound fails the call, naming the request and the '
        'count', () async {
      final incidents = harness().app.alerts.incidents.length;
      harness().app.boundReadLimits.clear();
      final answer = await caller.call(const BoundedNotes(8));
      await eventually(() async {
        return harness().app.alerts.incidents.length > incidents;
      });
      expect(harness().app.boundReadLimits, [
        4,
      ], reason: 'strict never re-reads');
      expect(answer.status, 500);
      expect(
        '${harness().app.alerts.incidents.skip(incidents).single.error}',
        allOf(
          contains('BoundedNotes answered 4 items, past its bound of 3'),
          contains('request.readWhole'),
        ),
      );
    });
  });

  group('lenient — a deployed server', () {
    final start = DateTime.utc(2026, 10, 21, 12);
    final clock = DwTestClock(start);
    final app = TestApp();
    late DwTestDatabase database;
    late DwAppServer server;
    late DwTestCaller caller;

    setUpAll(() async {
      database = await DwTestDatabase.create(
        admin: adminConfig(),
        prefix: 'server_test',
      );
      server = app.server(
        database.config,
        clock: clock,
        settings: const DwServerSettings(largeResponseBytes: 2000),
      );
      // Started as `DwAppServer.start` starts it, without the test server's
      // strictness.
      await server.startOn(
        port: 0,
        address: InternetAddress.loopbackIPv4,
        handleSignals: false,
        outbound: DwFakeOutboundHttp(),
      );
      caller = DwTestCaller(
        Uri.parse('http://127.0.0.1:${server.boundPort}'),
        testProtocol,
      );
    });

    tearDownAll(() async {
      caller.close();
      await server.stop();
      await database.drop();
    });

    List<String> warningsSince(int from, String about) => [
      for (final line in RecordingLogger.lines.skip(from))
        if (line.startsWith('warning') && line.contains(about)) line,
    ];

    test('a list past its bound is served whole, with a warning once per '
        'request per interval', () async {
      final from = RecordingLogger.lines.length;
      const request = BoundedNotes(8);
      app.boundReadLimits.clear();
      expect((await caller.call(request)).value(request), hasLength(8));
      expect(app.boundReadLimits, [4, null]);
      expect(warningsSince(from, 'BoundedNotes answered'), [
        allOf(
          contains('BoundedNotes answered 8 items, past its bound of 3'),
          matches(RegExp(r'\d+ bytes; served whole')),
        ),
      ]);

      expect((await caller.call(request)).value(request), hasLength(8));
      expect(warningsSince(from, 'BoundedNotes answered'), hasLength(1));

      clock.advance(const Duration(hours: 1));
      expect((await caller.call(request)).value(request), hasLength(8));
      expect(warningsSince(from, 'BoundedNotes answered'), hasLength(2));
      expect(app.alerts.incidents, isEmpty);
    });

    test('a response above largeResponseBytes is logged with the call, once '
        'per interval', () async {
      final from = RecordingLogger.lines.length;
      const small = BoundedNotes(1, padding: 100);
      const large = BoundedNotes(1, padding: 3000);
      expect((await caller.call(small)).status, 200);
      expect(warningsSince(from, 'largeResponseBytes'), isEmpty);

      expect(
        (await caller.call(large)).value(large).single.text,
        hasLength(3000),
      );
      expect(warningsSince(from, 'largeResponseBytes'), [
        matches(RegExp(r'BoundedNotes answered \d+ bytes, above 2000')),
      ]);
      await caller.call(large);
      expect(warningsSince(from, 'largeResponseBytes'), hasLength(1));
    });
  });
}
