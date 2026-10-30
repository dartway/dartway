import 'dart:async';

import 'package:dartway_core_server/dartway_core_server.dart';
import 'package:dartway_core_server/src/alerts/dw_alert_outbox.dart';
import 'package:test/test.dart';

import 'support/test_app.dart';

void main() {
  late DwTestDatabase database;
  late DwPostgresDatabase opened;

  setUp(() async {
    database = await DwTestDatabase.create(
      admin: adminConfig(),
      prefix: 'alert_outbox',
    );
    opened = await DwPostgresDatabase.open(database.config);
    await DwMigrationRunner(
      opened.db,
      migrations: {'dw': DwAppServer.frameworkMigrations},
    ).apply();
  });

  tearDown(() async {
    await opened.close();
    await database.drop();
  });

  DwServerIncident incident([String id = 'incident-1', DateTime? at]) =>
      DwServerIncident(
        id: id,
        where: 'command SaveOrder',
        error: StateError('database unavailable'),
        stackTrace: StackTrace.fromString('#0 save (orders.dart:1)'),
        at: at ?? DateTime.now().toUtc(),
      );

  DwAlertOutbox outbox(DwAlertSink sink, {Duration? window}) => DwAlertOutbox(
    db: opened.db,
    sink: sink,
    logger: RecordingLogger(),
    window: window ?? const Duration(milliseconds: 80),
    pollInterval: const Duration(milliseconds: 10),
  );

  Future<void> waitFor(bool Function() condition) async {
    final limit = DateTime.now().add(const Duration(seconds: 5));
    while (!condition()) {
      if (DateTime.now().isAfter(limit)) {
        fail('condition was not reached before timeout');
      }
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
  }

  test(
    'a sink outage is retried and accepted exactly once after recovery',
    () async {
      final sink = _SwitchableSink()..available = false;
      final worker = outbox(sink);
      await worker.enqueue(incident());
      worker.start();
      await waitFor(() => sink.attempts > 0);
      sink.available = true;
      await waitFor(() => sink.delivered.length == 1);
      await Future<void>.delayed(const Duration(milliseconds: 100));
      await worker.stop();
      expect(sink.delivered, ['incident-1:incident']);
    },
  );

  test('Telegram tokens do not reach last_error or the worker log', () async {
    const token = 'never-persist-this-token';
    final logger = RecordingLogger();
    final worker = DwAlertOutbox(
      db: opened.db,
      sink: DwTelegramAlertSink(
        botToken: token,
        chatId: '42',
        logger: logger,
        apiBase: Uri.parse('http://127.0.0.1:1'),
      ),
      logger: logger,
      window: const Duration(hours: 1),
      pollInterval: const Duration(milliseconds: 10),
    );
    await worker.enqueue(incident());
    worker.start();
    String? lastError;
    final limit = DateTime.now().add(const Duration(seconds: 5));
    while (lastError == null && DateTime.now().isBefore(limit)) {
      final row = (await opened.db.query(
        "SELECT last_error FROM dw_alert_outbox WHERE id = 'incident-1'",
      )).single;
      lastError = row['last_error'] as String?;
      if (lastError == null) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
    }
    await worker.stop();
    expect(lastError, isNotNull);
    expect(lastError, isNot(contains(token)));
    expect(RecordingLogger.lines.join('\n'), isNot(contains(token)));
  });

  test('a new worker delivers a row left by a stopped process', () async {
    final first = outbox(_SwitchableSink());
    await first.enqueue(incident());

    final sink = _SwitchableSink();
    final restarted = outbox(sink);
    restarted.start();
    await waitFor(() => sink.delivered.isNotEmpty);
    await restarted.stop();
    expect(sink.delivered, ['incident-1:incident']);
  });

  test(
    '1000 identical incidents become one incident and repeated 999',
    () async {
      final sink = _SwitchableSink();
      final at = DateTime.utc(2026, 10, 30, 12);
      var now = at;
      final worker = DwAlertOutbox(
        db: opened.db,
        sink: sink,
        logger: RecordingLogger(),
        window: const Duration(hours: 1),
        pollInterval: const Duration(milliseconds: 10),
        clock: () => now,
      );
      for (var i = 0; i < 1000; i++) {
        await worker.enqueue(incident('incident-$i', at));
      }
      worker.start();
      await waitFor(() => sink.delivered.length == 1);
      now = at.add(const Duration(hours: 1, microseconds: 1));
      await waitFor(() => sink.delivered.length == 2);
      await worker.stop();
      expect(sink.delivered, ['incident-0:incident', 'incident-0:repeat']);
      expect(sink.incidents.last.repeatCount, 999);
    },
  );

  test(
    'an alert persists independently of a rolled-back command transaction',
    () async {
      final worker = outbox(_SwitchableSink());
      await expectLater(
        opened.db.transaction((_) async {
          await worker.enqueue(incident());
          throw StateError('roll back command');
        }),
        throwsStateError,
      );
      final rows = await opened.db.query(
        "SELECT id FROM dw_alert_outbox WHERE id = 'incident-1'",
      );
      expect(rows, hasLength(1));
    },
  );

  test('two workers never deliver the same claimed row', () async {
    final sink = _SwitchableSink(delay: const Duration(milliseconds: 40));
    final first = outbox(sink, window: const Duration(hours: 1));
    final second = outbox(sink, window: const Duration(hours: 1));
    await first.enqueue(incident());
    first.start();
    second.start();
    await waitFor(() => sink.delivered.isNotEmpty);
    await Future<void>.delayed(const Duration(milliseconds: 100));
    await first.stop();
    await second.stop();
    expect(sink.delivered, ['incident-1:incident']);
  });
}

final class _SwitchableSink implements DwAlertSink {
  _SwitchableSink({this.delay = Duration.zero});

  bool available = true;
  int attempts = 0;
  final Duration delay;
  final List<String> delivered = [];
  final List<DwServerIncident> incidents = [];

  @override
  Future<void> send(DwServerIncident incident, {String? suppressedNote}) async {
    attempts++;
    if (delay != Duration.zero) await Future<void>.delayed(delay);
    if (!available) throw StateError('sink down');
    incidents.add(incident);
    delivered.add('${incident.id}:${incident.kind}');
  }
}
