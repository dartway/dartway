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
}

final class _ThrowingAlerts implements DwAlertSink {
  @override
  Future<void> send(
    DwServerIncident incident, {
    String? suppressedNote,
  }) async => throw StateError('sink down');
}
