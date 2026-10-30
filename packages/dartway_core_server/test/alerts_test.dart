import 'dart:convert';
import 'dart:io';

import 'package:dartway_core_server/src/alerts/dw_alert_sink.dart';
import 'package:test/test.dart';

import 'support/test_app.dart';

void main() {
  group('alert gate', () {
    late RecordingAlerts sink;
    late DateTime now;
    late DwAlertGate gate;

    setUp(() {
      sink = RecordingAlerts();
      now = DateTime.utc(2026, 9, 13, 12);
      gate = DwAlertGate(
        sink: sink,
        logger: RecordingLogger(),
        maxPerWindow: 3,
        window: const Duration(hours: 1),
        clock: () => now,
      );
    });

    String fail(String where, [String message = 'boom']) {
      try {
        throw StateError(message);
      } catch (error, stackTrace) {
        return gate.report(where: where, error: error, stackTrace: stackTrace);
      }
    }

    test('one signature alerts up to the ceiling per window, the last one '
        'saying so; every incident is logged', () async {
      final ids = [for (var i = 0; i < 5; i++) fail('command X', 'boom $i')];
      await Future<void>.delayed(Duration.zero);
      expect(ids.toSet(), hasLength(5));
      expect(sink.incidents.map((i) => i.id), ids.take(3));
      expect(sink.notes, [
        null,
        null,
        contains('muted until 2026-09-13T13:00'),
      ]);
      expect(
        RecordingLogger.lines.where((l) => l.contains('incident ')),
        hasLength(greaterThanOrEqualTo(5)),
      );

      now = now.add(const Duration(hours: 1));
      fail('command X');
      await Future<void>.delayed(Duration.zero);
      expect(sink.incidents, hasLength(4));
    });

    test('different places are different signatures', () async {
      for (var i = 0; i < 4; i++) {
        fail('command A');
        fail('command B');
      }
      await Future<void>.delayed(Duration.zero);
      expect(sink.incidents.where((i) => i.where == 'command A'), hasLength(3));
      expect(sink.incidents.where((i) => i.where == 'command B'), hasLength(3));
    });

    test('many signatures at once stay under the per-minute ceiling, and the '
        'next alert says how many were held back', () async {
      final minute = DwAlertGate(
        sink: sink,
        logger: RecordingLogger(),
        maxPerMinute: 4,
        clock: () => now,
      );
      for (var i = 0; i < 10; i++) {
        try {
          throw StateError('boom');
        } catch (error, stackTrace) {
          minute.report(
            where: 'place $i',
            error: error,
            stackTrace: stackTrace,
          );
        }
      }
      await Future<void>.delayed(Duration.zero);
      expect(sink.incidents, hasLength(4));

      now = now.add(const Duration(minutes: 1));
      minute.report(
        where: 'later',
        error: StateError('x'),
        stackTrace: StackTrace.current,
      );
      await Future<void>.delayed(Duration.zero);
      expect(sink.incidents, hasLength(5));
      expect(sink.notes.last, contains('6 more alert(s) were held back'));
    });

    test('a failing sink does not throw into the caller', () async {
      final failing = DwAlertGate(
        sink: _ThrowingAlerts(),
        logger: RecordingLogger(),
      );
      expect(
        failing.report(
          where: 'x',
          error: StateError('e'),
          stackTrace: StackTrace.current,
        ),
        isNotEmpty,
      );
      await Future<void>.delayed(Duration.zero);
    });

    test(
      'durable mode persists every repeat instead of process-muting it',
      () async {
        final persisted = <DwServerIncident>[];
        final durable = DwAlertGate(
          sink: sink,
          logger: RecordingLogger(),
          maxPerWindow: 1,
          enqueue: (incident) async => persisted.add(incident),
        );
        for (var i = 0; i < 1000; i++) {
          durable.report(
            where: 'command X',
            error: StateError('boom'),
            stackTrace: StackTrace.fromString('#0 same (x.dart:1)'),
          );
        }
        await Future<void>.delayed(Duration.zero);
        expect(persisted, hasLength(1000));
        expect(persisted.map((i) => i.signature).toSet(), hasLength(1));
      },
    );
  });

  test('Telegram alerts post the incident without payloads', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final received = <(String, Map<String, Object?>)>[];
    server.listen((request) async {
      received.add((
        request.uri.path,
        jsonDecode(await utf8.decodeStream(request)) as Map<String, Object?>,
      ));
      request.response.statusCode = 200;
      await request.response.close();
    });
    final alerts = DwTelegramAlertSink(
      botToken: 'TOKEN',
      chatId: '42',
      logger: RecordingLogger(),
      title: 'Example',
      apiBase: Uri.parse('http://127.0.0.1:${server.port}'),
    );
    await alerts.send(
      DwServerIncident(
        id: 'abc123',
        where: 'command BookSession',
        error: StateError('seats table locked'),
        stackTrace: StackTrace.current,
      ),
      suppressedNote: 'muted',
    );
    await server.close();
    expect(received.single.$1, '/botTOKEN/sendMessage');
    expect(received.single.$2['chat_id'], '42');
    final text = received.single.$2['text']! as String;
    expect(text, contains('Example: failure abc123'));
    expect(text, contains('command BookSession'));
    expect(text, contains('seats table locked'));
    expect(text, contains('muted'));
  });

  test('Telegram failures never expose the bot token', () async {
    const token = 'super-secret-bot-token';
    final logger = RecordingLogger();
    final alerts = DwTelegramAlertSink(
      botToken: token,
      chatId: '42',
      logger: logger,
      apiBase: Uri.parse('http://127.0.0.1:1'),
    );
    Object? failure;
    try {
      await alerts.send(
        DwServerIncident(
          id: 'abc123',
          where: 'command SaveOrder',
          error: StateError('down'),
          stackTrace: StackTrace.current,
        ),
      );
    } catch (error) {
      failure = error;
    }
    expect(failure, isA<DwTelegramAlertException>());
    expect('$failure', isNot(contains(token)));

    final gate = DwAlertGate(sink: alerts, logger: logger);
    gate.report(
      where: 'command SaveOrder',
      error: StateError('down'),
      stackTrace: StackTrace.current,
    );
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(RecordingLogger.lines.last, isNot(contains(token)));
  });

  test(
    'Telegram 429 exposes retry_after without exposing credentials',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((request) async {
        await request.drain<void>();
        request.response
          ..statusCode = HttpStatus.tooManyRequests
          ..headers.contentType = ContentType.json
          ..write('{"parameters":{"retry_after":37}}');
        await request.response.close();
      });
      final alerts = DwTelegramAlertSink(
        botToken: 'TOKEN',
        chatId: '42',
        logger: RecordingLogger(),
        apiBase: Uri.parse('http://127.0.0.1:${server.port}'),
      );
      await expectLater(
        alerts.send(
          DwServerIncident(
            id: 'rate-limited',
            where: 'job cleanup',
            error: StateError('failed'),
            stackTrace: StackTrace.current,
          ),
        ),
        throwsA(
          isA<DwTelegramAlertException>().having(
            (error) => error.retryAfter,
            'retryAfter',
            const Duration(seconds: 37),
          ),
        ),
      );
      await server.close();
    },
  );

  test(
    'HTTP alerts send the documented JSON contract and bearer token',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      late Map<String, Object?> body;
      late String? authorization;
      server.listen((request) async {
        authorization = request.headers.value(HttpHeaders.authorizationHeader);
        body =
            jsonDecode(await utf8.decodeStream(request))
                as Map<String, Object?>;
        request.response.statusCode = HttpStatus.noContent;
        await request.response.close();
      });
      final sink = DwHttpAlertSink(
        url: Uri.parse('http://127.0.0.1:${server.port}/alerts'),
        token: 'secret',
      );
      final first = DwServerIncident(
        id: 'incident-1',
        where: 'command SaveOrder',
        error: StateError(List.filled(5000, 'é').join()),
        stackTrace: StackTrace.fromString(List.filled(20000, 's').join()),
        accountId: 42,
        at: DateTime.utc(2026, 10, 30),
        project: 'shop',
        environment: 'production',
        version: 'abc',
      );
      await sink.send(first);
      expect(body, containsPair('kind', 'incident'));
      expect(
        utf8.encode(body['error']! as String).length,
        inInclusiveRange(4000, 4 * 1024),
      );
      expect(utf8.encode(body['stackTrace']! as String), hasLength(16 * 1024));
      await sink.send(
        DwServerIncident(
          id: first.id,
          where: first.where,
          error: 'repeated 999 times',
          stackTrace: first.stackTrace,
          at: first.at,
          repeatCount: 999,
          project: first.project,
          environment: first.environment,
          version: first.version,
        ),
      );
      await server.close();
      expect(authorization, 'Bearer secret');
      expect(body, containsPair('id', 'incident-1'));
      expect(body, containsPair('kind', 'repeat'));
      expect(body, containsPair('repeatCount', 999));
      expect(body, containsPair('project', 'shop'));
      expect(
        body.keys,
        containsAll([
          'where',
          'error',
          'stackTrace',
          'accountId',
          'at',
          'signature',
          'environment',
          'version',
        ]),
      );
    },
  );
}

final class _ThrowingAlerts implements DwAlertSink {
  @override
  Future<void> send(
    DwServerIncident incident, {
    String? suppressedNote,
  }) async => throw StateError('sink down');
}
