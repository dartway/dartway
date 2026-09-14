import 'dart:io';

import 'package:dartway_cli/src/deploy/outside_probe.dart';
import 'package:test/test.dart';

/// A stand-in for a deployed host: answers by path, as configured per test,
/// and records the Host header each request arrived with.
class _Site {
  late HttpServer server;
  final hosts = <String>[];
  Future<void> Function(HttpRequest request)? handler;

  Future<void> start() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      hosts.add(request.headers.value('host') ?? '');
      await handler!(request);
    });
  }

  DwOutsideProbe get probe => DwOutsideProbe(
    connectTo: (host: InternetAddress.loopbackIPv4.address, port: server.port),
    timeout: const Duration(seconds: 3),
  );
}

void main() {
  late _Site site;

  setUp(() async {
    site = _Site();
    await site.start();
  });
  tearDown(() => site.server.close(force: true));

  Future<void> text(
    HttpRequest request,
    int status,
    String body, {
    Map<String, String> headers = const {},
  }) async {
    request.response.statusCode = status;
    headers.forEach(request.response.headers.set);
    request.response.write(body);
    await request.response.close();
  }

  group('health', () {
    test('passes on 200 ok, reached under the public host name', () async {
      site.handler = (r) => text(r, 200, 'ok');
      final result = await site.probe.health('http://api.example.com');
      expect(result.passed, isTrue, reason: result.detail);
      expect(site.hosts.single, 'api.example.com');
    });

    test(
      'a proxy answering for a server it cannot reach is a failure',
      () async {
        site.handler = (r) => text(r, 502, '<html>Bad Gateway</html>');
        final result = await site.probe.health('http://api.example.com');
        expect(result.passed, isFalse);
        expect(result.detail, contains('502'));
      },
    );
  });

  group('app index', () {
    const index =
        '<!DOCTYPE html><html><head></head><body>'
        '<script src="flutter_bootstrap.js" async></script></body></html>';

    Future<void> page(HttpRequest r, {String? cacheControl}) => text(
      r,
      200,
      index,
      headers: {'content-type': 'text/html', 'cache-control': ?cacheControl},
    );

    test('passes on the Flutter page served for revalidation', () async {
      site.handler = (r) => page(r, cacheControl: 'no-cache');
      final result = await site.probe.appIndex('http://app.example.com');
      expect(result.passed, isTrue, reason: result.detail);
    });

    test('fails on a page a browser may keep across a deploy', () async {
      site.handler = (r) => page(r, cacheControl: 'max-age=2592000');
      final result = await site.probe.appIndex('http://app.example.com');
      expect(result.passed, isFalse);
      expect(result.detail, contains('max-age=2592000'));
    });

    test('fails on a default page that is not the app', () async {
      site.handler = (r) => text(
        r,
        200,
        '<html><body>Welcome to nginx!</body></html>',
        headers: {'content-type': 'text/html', 'cache-control': 'no-cache'},
      );
      final result = await site.probe.appIndex('http://app.example.com');
      expect(result.passed, isFalse);
      expect(result.detail, contains('does not load Flutter'));
    });
  });

  group('live upgrade', () {
    test('passes on 101 followed by the documented dw. close', () async {
      String? origin;
      site.handler = (request) async {
        origin = request.headers.value('origin');
        final socket = await WebSocketTransformer.upgrade(request);
        await socket.close(4026, 'dw.protocolUnsupported');
      };
      final result = await site.probe.liveUpgrade(
        'http://app.example.com',
        browserOrigin: 'http://app.example.com',
      );
      expect(result.passed, isTrue, reason: result.detail);
      expect(result.detail, contains('4026'));
      expect(origin, 'http://app.example.com');
      expect(site.hosts.single, 'app.example.com');
    });

    test('a 101 from something that is not the server is a failure', () async {
      site.handler = (request) async {
        final socket = await WebSocketTransformer.upgrade(request);
        await socket.close(1000, 'bye');
      };
      final result = await site.probe.liveUpgrade('http://app.example.com');
      expect(result.passed, isFalse);
      expect(result.detail, contains('nothing from a DartWay server'));
    });

    test('a proxy that dropped the Upgrade headers is a failure', () async {
      site.handler = (r) => text(r, 400, 'a WebSocket upgrade is expected');
      final result = await site.probe.liveUpgrade('http://app.example.com');
      expect(result.passed, isFalse);
      expect(result.detail, contains('refused'));
    });
  });

  group('storage CORS', () {
    Future<void> preflight(HttpRequest r, {required String allowOrigin}) =>
        text(
          r,
          204,
          '',
          headers: {
            'access-control-allow-origin': allowOrigin,
            'access-control-allow-methods': 'PUT',
            'access-control-allow-headers':
                r.headers.value('access-control-request-headers') ?? '',
          },
        );

    test('passes when the app origin may PUT with the bound headers', () async {
      site.handler = (r) => preflight(r, allowOrigin: 'http://app.example.com');
      final result = await site.probe.storageCors(
        storageOrigin: 'http://files.example.com',
        bucket: 'shop',
        appOrigin: 'http://app.example.com',
      );
      expect(result.passed, isTrue, reason: result.detail);
    });

    test('fails when the rule admits some other origin', () async {
      site.handler = (r) => preflight(r, allowOrigin: 'https://other.example');
      final result = await site.probe.storageCors(
        storageOrigin: 'http://files.example.com',
        bucket: 'shop',
        appOrigin: 'http://app.example.com',
      );
      expect(result.passed, isFalse);
      expect(result.detail, contains('refuse every upload'));
    });
  });
}
