import 'dart:convert';
import 'dart:io';

import 'package:dartway_cli/src/deploy/web_cache.dart';
import 'package:dartway_cli/src/dev/dev_proxy.dart';
import 'package:dartway_cli/src/dev/web_directory.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// `dartway dev proxy --web-dir`: a built app served the way the deployed web
/// image serves it.
void main() {
  late Directory project;
  late Directory build;
  late HttpServer api;
  late DwDevProxy proxy;
  late HttpClient client;

  void write(String relative, String content) =>
      File(p.join(build.path, relative))
        ..createSync(recursive: true)
        ..writeAsStringSync(content);

  Future<DwDevProxy> startProxy({String? servingConfiguration}) async {
    final started = DwDevProxy(
      api: Uri.parse('http://localhost:${api.port}'),
      webDirectory: DwWebDirectory(
        build,
        servingConfiguration: servingConfiguration,
      ),
      log: (_) {},
    );
    await started.start(port: 0);
    return started;
  }

  setUp(() async {
    project = Directory.systemTemp.createTempSync('dw_dev_web');
    build = Directory(p.join(project.path, 'shop_flutter', 'build', 'web'));
    write('index.html', '<html>app</html>');
    write('main.dart.js', 'main();');
    write('flutter_bootstrap.js', 'bootstrap();');
    write('app.0123abcd.js', 'hashed();');
    write('assets/FontManifest.json', '[]');
    write('docs/index.html', '<html>docs</html>');
    File(p.join(project.path, 'outside.txt')).writeAsStringSync('secret');

    api = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    api.listen((request) {
      request.response
        ..write('api ${request.uri.path}')
        ..close();
    });
    proxy = await startProxy();
    client = HttpClient();
  });

  tearDown(() async {
    client.close(force: true);
    await proxy.stop();
    await api.close(force: true);
    project.deleteSync(recursive: true);
  });

  Future<HttpClientResponse> send(
    String path, {
    String method = 'GET',
    Map<String, String> headers = const {},
  }) async {
    final request = await client.openUrl(
      method,
      Uri.parse('http://127.0.0.1:${proxy.port}$path'),
    );
    headers.forEach(request.headers.set);
    return request.close();
  }

  Future<(int, String, HttpHeaders)> get(
    String path, {
    Map<String, String> headers = const {},
  }) async {
    final response = await send(path, headers: headers);
    return (
      response.statusCode,
      await utf8.decodeStream(response),
      response.headers,
    );
  }

  test(
    'a file is served with its type and the revalidating cache rule',
    () async {
      final (status, body, headers) = await get('/main.dart.js');

      expect(status, 200);
      expect(body, 'main();');
      expect(headers.contentType?.mimeType, 'application/javascript');
      expect(headers.value('cache-control'), 'no-cache');
      expect(headers.value('etag'), matches(RegExp(r'^"[0-9a-f]+-7"$')));
      expect(headers.value('last-modified'), isNotNull);
    },
  );

  test('the root is index.html', () async {
    final (status, body, headers) = await get('/');
    expect((status, body), (200, '<html>app</html>'));
    expect(headers.contentType?.mimeType, 'text/html');
    expect(headers.value('cache-control'), 'no-cache');
  });

  test('a route that is not a file is answered by the app', () async {
    final (status, body, headers) = await get('/club/42/schedule?day=mon');
    expect((status, body), (200, '<html>app</html>'));
    expect(headers.value('cache-control'), 'no-cache');
  });

  test('a directory is answered by its own index', () async {
    final (status, body, _) = await get('/docs');
    expect((status, body), (200, '<html>docs</html>'));
  });

  test(
    'a name carrying a content hash may be kept, and is not a route',
    () async {
      final (status, _, headers) = await get('/app.0123abcd.js');
      expect(status, 200);
      expect(
        headers.value('cache-control'),
        'public, max-age=31536000, immutable',
      );

      // The hashed block has no fallback, as in the image: a stale hashed name
      // is a 404, not the app's HTML under a JavaScript name.
      final (missing, _, _) = await get('/app.ffffffff.js');
      expect(missing, 404);
    },
  );

  test('revalidation is a 304 once the browser has the file', () async {
    final (_, _, first) = await get('/flutter_bootstrap.js');
    final etag = first.value('etag')!;

    final response = await send(
      '/flutter_bootstrap.js',
      headers: {'if-none-match': etag},
    );
    final body = await utf8.decodeStream(response);
    expect(response.statusCode, 304);
    expect(body, isEmpty);
    expect(response.headers.value('etag'), etag);
    expect(response.headers.value('cache-control'), 'no-cache');
  });

  test('HEAD answers the headers only; other methods are refused', () async {
    final head = await send('/main.dart.js', method: 'HEAD');
    expect(head.statusCode, 200);
    expect(head.contentLength, 'main();'.length);
    expect(await head.fold<int>(0, (n, chunk) => n + chunk.length), 0);

    final post = await send('/main.dart.js', method: 'POST');
    await post.drain<void>();
    expect(post.statusCode, 405);
    expect(post.headers.value('allow'), 'GET, HEAD');
  });

  test('nothing outside the build is reachable', () async {
    // Raw request lines: a client library would normalise them first.
    Future<String> raw(String target) async {
      final socket = await Socket.connect('127.0.0.1', proxy.port);
      socket.write(
        'GET $target HTTP/1.1\r\nhost: localhost\r\nconnection: close\r\n\r\n',
      );
      return utf8.decodeStream(socket);
    }

    for (final target in [
      '/../../outside.txt',
      '/%2e%2e/%2e%2e/outside.txt',
      '/..%2F..%2Foutside.txt',
      '/..%5C..%5Coutside.txt',
    ]) {
      final answer = await raw(target);
      expect(answer, isNot(contains('secret')), reason: target);
      expect(
        answer,
        anyOf(startsWith('HTTP/1.1 400'), contains('<html>app</html>')),
        reason: target,
      );
    }
  });

  test('the framework paths still go to the API', () async {
    final (status, body, _) = await get('/dw/Anything');
    expect((status, body), (200, 'api /dw/Anything'));
    final (_, health, _) = await get('/health');
    expect(health, 'api /health');
  });

  test('a build that is not there says so', () async {
    File(p.join(build.path, 'index.html')).deleteSync();
    final (status, body, _) = await get('/some/route');
    expect(status, 404);
    expect(body, contains('build the app first'));
  });

  test(
    'the project\'s own web image configuration decides the headers',
    () async {
      File(p.join(project.path, 'shop_server', 'pubspec.yaml'))
        ..createSync(recursive: true)
        ..writeAsStringSync('name: shop_server\n');
      Directory(p.join(project.path, 'shop_shared')).createSync();
      File(
        p.join(project.path, 'shop_flutter', 'nginx.conf'),
      ).writeAsStringSync(r'''
server {
  location / {
    try_files $uri /index.html;
    add_header Cache-Control "no-cache, private";
  }
  location /assets/ {
    expires -1;
  }
}
''');
      File(
        p.join(project.path, 'shop_flutter', 'Dockerfile'),
      ).writeAsStringSync(
        'FROM nginx\nCOPY shop_flutter/nginx.conf /etc/nginx/conf.d/default.conf\n',
      );

      final configuration = DwWebDirectory.projectServingConfiguration(build);
      expect(configuration, contains('no-cache, private'));

      await proxy.stop();
      proxy = await startProxy(servingConfiguration: configuration);

      final (_, _, page) = await get('/main.dart.js');
      expect(page.value('cache-control'), 'no-cache, private');
      final (_, _, asset) = await get('/assets/FontManifest.json');
      expect(asset.value('cache-control'), 'no-cache');
      // `/assets/` has no fallback in that configuration.
      final (missing, _, _) = await get('/assets/missing.json');
      expect(missing, 404);
    },
  );

  test('the built-in rules are the template\'s nginx.conf', () {
    // The copy in the CLI is what a project without a readable configuration
    // gets. It must say what the template ships, block for block.
    final template = File(
      p.join('..', '..', 'template', 'dartway_starter_flutter', 'nginx.conf'),
    );
    expect(template.existsSync(), isTrue, reason: template.path);
    final shipped = dwParseNginxLocations(template.readAsStringSync());
    final builtIn = dwParseNginxLocations(dwTemplateWebServing);

    expect(
      [for (final l in builtIn) (l.modifier, l.pattern)],
      [for (final l in shipped) (l.modifier, l.pattern)],
    );
    for (final path in [
      ...dwFlutterEntryPoints,
      '/some/route',
      '/app.0123abcd.js',
      '/assets/fonts/x.9f2b1c4e.woff2',
    ]) {
      final a = dwLocationFor(shipped, path);
      final b = dwLocationFor(builtIn, path);
      expect(
        (b?.cacheControl, b?.triesFiles),
        (a?.cacheControl, a?.triesFiles),
        reason: path,
      );
    }
  });
}
