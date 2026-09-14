import 'package:dartway_cli/src/deploy/nginx_upstreams.dart';
import 'package:dartway_cli/src/deploy/renderer.dart';
import 'package:dartway_cli/src/deploy/stack.dart';
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

import 'support/deploy_fixtures.dart';

YamlMap _compose(DwStack stack) =>
    loadYaml(DwStackRenderer(stack: stack).composeFile) as YamlMap;

YamlMap _service(DwStack stack, String name) =>
    (_compose(stack)['services'] as YamlMap)[name] as YamlMap;

/// The body of the `server` block for [host], as rendered.
String _serverBlock(String nginx, String host) {
  final start = nginx.indexOf(RegExp('server_name $host;'));
  expect(start, isNot(-1), reason: 'no server block for $host');
  final open = nginx.lastIndexOf('server {', start);
  var depth = 0;
  for (var index = open; index < nginx.length; index++) {
    if (nginx[index] == '{') depth++;
    if (nginx[index] == '}' && --depth == 0) {
      return nginx.substring(open, index + 1);
    }
  }
  fail('unbalanced server block for $host');
}

/// The body of `location <spec> { … }` inside [block].
String _location(String block, String spec) {
  final start = block.indexOf('location $spec {');
  expect(start, isNot(-1), reason: 'no location $spec');
  return block.substring(start, block.indexOf('    }', start));
}

void main() {
  group('the rendered compose file', () {
    for (final MapEntry(key: variant, value: stack)
        in stackVariants().entries) {
      test('$variant: is YAML with the services the stack needs', () {
        final services = (_compose(stack)['services'] as YamlMap).keys.toSet();
        expect(services, containsAll(['postgres', 'server', 'web', 'nginx']));
        expect(
          services.contains('minio') && services.contains('minio-init'),
          stack.target.storageDomain != null,
        );
        expect(services, contains('certbot'));
      });

      // The contract every rendered upstream is held to on the server, held
      // here for every shape of stack before any server sees one.
      test('$variant: every nginx upstream is a rendered service', () {
        final renderer = DwStackRenderer(stack: stack);
        final services = (_compose(stack)['services'] as YamlMap).keys
            .map((key) => '$key')
            .toSet();
        expect(
          DwNginxUpstreams.missing(
            snippets: {'nginx.conf': renderer.nginxFile},
            services: services,
          ),
          isEmpty,
        );
      });
    }

    test('the server is configured by its environment alone', () {
      final server = _service(stackFrom(), 'server');
      expect(server['env_file'], ['.env']);
      expect(Map.of(server['environment'] as YamlMap), {
        'PORT': '8080',
        'DW_DATABASE_HOST': 'postgres',
        'DW_DATABASE_PORT': '5432',
        'DW_DATABASE_NAME': 'shop',
        'DW_DATABASE_USER': 'shop',
        'DW_DATABASE_SSL': 'false',
      });
      expect(
        (server['build'] as YamlMap)['dockerfile'],
        'shop_server/Dockerfile',
      );
      // Never published: the proxy is the only way in.
      expect(server.containsKey('ports'), isFalse);
    });

    test('the server is healthy only when /health answers, and waits for the '
        'database', () {
      final server = _service(stackFrom(), 'server');
      final health = server['healthcheck'] as YamlMap;
      expect(health['test'], contains('http://127.0.0.1:8080/health'));
      expect(
        ((server['depends_on'] as YamlMap)['postgres'] as YamlMap)['condition'],
        'service_healthy',
      );
      expect(server['stop_grace_period'], isNotNull);
    });

    test(
      'a missing secret stops Compose instead of initialising with nothing',
      () {
        final postgres = _service(stackFrom(), 'postgres');
        expect(
          (postgres['environment'] as YamlMap)['POSTGRES_PASSWORD'],
          startsWith(r'${DW_DATABASE_PASSWORD:?'),
        );
      },
    );

    test('the web image is given the app origin it calls', () {
      final web = _service(stackFrom(), 'web');
      expect(
        ((web['build'] as YamlMap)['args'] as YamlMap)['DW_BACKEND_URL'],
        'https://app.example.com',
      );
    });

    test('MinIO: the bucket, the CORS origin, and the server reaching storage '
        'by the URL browsers sign', () {
      final stack = stackVariants()['minio and a site']!;
      final minio = _service(stack, 'minio');
      expect(
        (minio['environment'] as YamlMap)['MINIO_API_CORS_ALLOW_ORIGIN'],
        'https://app.example.com',
      );
      final init = _service(stack, 'minio-init');
      expect((init['command'] as YamlList).single, contains('dw/shop'));
      expect(
        Map.of(_service(stack, 'server')['environment'] as YamlMap),
        containsPair('DW_STORAGE_ENDPOINT', 'https://files.example.com'),
      );
      final nginx = _service(stack, 'nginx');
      expect(
        ((nginx['networks'] as YamlMap)['default'] as YamlMap)['aliases'],
        ['files.example.com'],
      );
    });

    test('a site is mounted from the checkout, read-only', () {
      final nginx = _service(stackVariants()['minio and a site']!, 'nginx');
      expect(nginx['volumes'], contains('./app_site/build:/srv/site:ro'));
    });

    test('a declared file is mounted read-only into the server', () {
      final server = _service(
        stackVariants()['external storage, external site, files']!,
        'server',
      );
      expect(server['volumes'], [
        '/home/deployer/.config/shop/fcm.json:/run/secrets/fcm.json:ro',
      ]);
    });

    test('plain HTTP publishes one loopback port and drops TLS', () {
      final stack = stackFrom(front: const DwPlainHttpFront(18080));
      final nginx = _service(stack, 'nginx');
      expect(nginx['ports'], ['127.0.0.1:18080:18080']);
      expect(
        (_compose(stack)['services'] as YamlMap).containsKey('certbot'),
        isFalse,
      );
      expect(stack.appOrigin, 'http://app.example.com:18080');
    });
  });

  group('the rendered nginx configuration', () {
    final stack = stackVariants()['minio and a site']!;
    final nginx = DwStackRenderer(stack: stack).nginxFile;

    test('app: files from the web image, calls and health to the server', () {
      final app = _serverBlock(nginx, 'app.example.com');
      expect(_location(app, '/'), contains('proxy_pass http://web:80;'));
      expect(
        _location(app, '/dw/'),
        contains('proxy_pass http://server:8080;'),
      );
      expect(
        _location(app, '= /health'),
        contains('proxy_pass http://server:8080;'),
      );
    });

    test('app and api: /dw/live upgrades and stays open', () {
      for (final host in ['app.example.com', 'api.example.com']) {
        final live = _location(_serverBlock(nginx, host), '= /dw/live');
        expect(live, contains('proxy_pass http://server:8080;'), reason: host);
        expect(live, contains(r'proxy_set_header Upgrade $http_upgrade;'));
        expect(
          live,
          contains(r'proxy_set_header Connection $connection_upgrade;'),
        );
        expect(live, contains('proxy_read_timeout 1h;'), reason: host);
      }
    });

    // The live socket admits a browser whose Origin is the host the upgrade
    // was sent to — port included, which `$host` would drop.
    test('the server sees the Host the client sent, port included', () {
      final app = _serverBlock(nginx, 'app.example.com');
      expect(
        _location(app, '/dw/'),
        contains(r'proxy_set_header Host $http_host;'),
      );
      expect(_location(app, '/dw/'), isNot(contains(r'Host $host;')));
    });

    test('api: everything to the server', () {
      final api = _serverBlock(nginx, 'api.example.com');
      expect(_location(api, '/'), contains('proxy_pass http://server:8080;'));
    });

    test('the proxy lets the server refuse an oversized call itself', () {
      for (final host in ['app.example.com', 'api.example.com']) {
        expect(
          _serverBlock(nginx, host),
          contains('client_max_body_size ${DwStackRenderer.bodyLimit};'),
        );
      }
    });

    test('site: static files with revalidation', () {
      final site = _serverBlock(nginx, 'example.com');
      expect(site, contains('root /srv/site;'));
      expect(site, contains('Cache-Control "no-cache"'));
      expect(site, isNot(contains('proxy_pass')));
    });

    test('storage: streamed to MinIO with the signed host intact', () {
      final storage = _serverBlock(nginx, 'files.example.com');
      expect(storage, contains('proxy_pass http://minio:9000;'));
      expect(storage, contains('client_max_body_size 0;'));
      expect(storage, contains(r'proxy_set_header Host $http_host;'));
    });

    test('TLS: one certificate for every host, and a redirect on 80', () {
      for (final host in stack.target.servedDomains) {
        expect(
          _serverBlock(nginx, host),
          contains('/etc/letsencrypt/live/api.example.com/fullchain.pem'),
        );
      }
      expect(
        nginx,
        contains(
          'server_name api.example.com app.example.com example.com '
          'files.example.com;',
        ),
      );
      expect(nginx, contains(r'return 301 https://$host$request_uri;'));
    });

    test('an external site gets no server block', () {
      final external = DwStackRenderer(
        stack: stackVariants()['external storage, external site, files']!,
      ).nginxFile;
      expect(external, isNot(contains('server_name example.com;')));
    });

    test(
      'plain HTTP listens on the published port and names no certificate',
      () {
        final plain = DwStackRenderer(
          stack: stackFrom(front: const DwPlainHttpFront(18080)),
        ).nginxFile;
        expect(plain, contains('listen 18080;'));
        expect(plain, isNot(contains('ssl')));
        expect(plain, isNot(contains('acme-challenge')));
      },
    );
  });
}
