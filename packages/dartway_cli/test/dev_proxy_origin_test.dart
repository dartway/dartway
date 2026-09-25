import 'dart:io';

import 'package:dartway_cli/src/dev/dev_proxy.dart';
import 'package:dartway_core_server/dartway_core_server.dart';
import 'package:dartway_core_server/testing.dart';
import 'package:test/test.dart';

/// The proxy in front of a real `DwAppServer`: a browser page served by the
/// proxy opens the live socket through it, and the server's origin check lets
/// it in without `DW_ALLOWED_ORIGINS` — because the proxy keeps the `Host` the
/// browser sent, as the deployed Nginx does.
///
/// Needs a Postgres server named by `DW_DATABASE_*` (what `dartway test`
/// provides); skipped without one.
void main() {
  final environment = Platform.environment;
  final skip = environment['DW_DATABASE_HOST'] == null
      ? 'needs a Postgres server: set DW_DATABASE_HOST, _PORT, _NAME, _USER, '
            '_PASSWORD and _SSL'
      : false;

  group('dartway dev proxy in front of a DwAppServer', () {
    late DwTestDatabase database;
    late DwTestServer server;
    late HttpServer web;
    late DwDevProxy proxy;

    setUpAll(() async {
      database = await DwTestDatabase.create(prefix: 'cli_dev_proxy');
      server = await DwTestServer.start(
        DwAppServer(
          protocol: DwWireProtocol.core,
          migrations: const [],
          database: database.config.copyWith(maxConnections: 2),
          auth: DwAuthConfig(
            accountDeletion: DwAccountDeletion.byMember,
            normalize: (kind, raw) => raw.trim().toLowerCase(),
            deliverCode: (ctx, kind, identifier, code, accountId) async {},
          ),
          handlers: const [],
          logger: const _Silent(),
        ),
      );
      web = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      web.listen((request) {
        request.response
          ..headers.contentType = ContentType.html
          ..write('<html>app</html>')
          ..close();
      });
      proxy = DwDevProxy(
        api: server.httpBase,
        webServer: Uri.parse('http://127.0.0.1:${web.port}'),
        log: (_) {},
      );
      await proxy.start(port: 0);
    });

    tearDownAll(() async {
      await proxy.stop();
      await web.close(force: true);
      await server.stop();
      await database.drop();
    });

    Uri liveThroughProxy(String host) =>
        server.liveEndpoint.replace(host: host, port: proxy.port);

    group('through the proxy', () {
      test('a page of the proxy origin opens the live socket', () async {
        for (final host in ['localhost', '127.0.0.1']) {
          final live = await server.openLive(
            endpoint: liveThroughProxy(host),
            headers: {'origin': 'http://$host:${proxy.port}'},
          );
          expect(live.connectionId, isNotEmpty, reason: host);
          await live.close();
        }
      });

      test('a page of another origin is still refused', () async {
        await expectLater(
          server.openLive(
            endpoint: liveThroughProxy('localhost'),
            headers: {'origin': 'http://evil.example'},
          ),
          throwsA(isA<WebSocketException>()),
        );
        // Another port on the same host is another site.
        await expectLater(
          server.openLive(
            endpoint: liveThroughProxy('localhost'),
            headers: {'origin': 'http://localhost:${web.port}'},
          ),
          throwsA(isA<WebSocketException>()),
        );
      });

      test('calls and /health reach the server', () async {
        final caller = DwTestCaller(
          Uri.parse('http://localhost:${proxy.port}'),
          server.protocol,
        );
        addTearDown(caller.close);

        final health = await caller.raw('GET', '/health');
        expect((health.status, health.text), (200, 'ok'));

        final ticket = await caller.call(
          const DwRequestCode(
            kind: DwIdentifierKind.email,
            identifier: 'visitor@example.com',
          ),
          headers: {'origin': 'http://localhost:${proxy.port}'},
        );
        expect(ticket.status, 200, reason: ticket.text);
      });
    });

    test('the same page talking to the server directly is refused — the check '
        'is live, and the proxy is what passes it', () async {
      await expectLater(
        server.openLive(headers: {'origin': 'http://localhost:${proxy.port}'}),
        throwsA(isA<WebSocketException>()),
      );
    });
  }, skip: skip);
}

final class _Silent implements DwServerLogger {
  const _Silent();

  @override
  void log(
    DwLogLevel level,
    String message, {
    Object? error,
    StackTrace? stackTrace,
  }) {}

  @override
  DwServerLogger scoped(String scope) => this;
}
