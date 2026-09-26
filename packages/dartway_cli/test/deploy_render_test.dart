import 'dart:convert';

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
  group('pinned images (what deploy check resolves against a registry)', () {
    test('no storage: Postgres, nginx and certbot, nothing storage-shaped', () {
      final images = stackFrom().pinnedImages;
      expect(images.map((e) => e.$1), ['Postgres', 'nginx', 'certbot']);
      expect(images.map((e) => e.$2), [
        DwStack.postgresImage,
        DwStack.nginxImage,
        DwStack.certbotImage,
      ]);
    });

    test('bundled storage adds the storage and its init image', () {
      final images = stackVariants()['bundled storage and a site']!.pinnedImages;
      expect(images.map((e) => e.$1), [
        'Postgres',
        'nginx',
        'certbot',
        'storage',
        'storage-init',
      ]);
      expect(images, contains(('storage', DwStack.storageImage)));
      expect(images, contains(('storage-init', DwStack.storageInitImage)));
    });

    test('external storage pulls no storage image at all', () {
      final images =
          stackVariants()['external storage, external site, files']!.pinnedImages;
      expect(images.map((e) => e.$1), ['Postgres', 'nginx', 'certbot']);
    });

    test('plain HTTP (the local proof) never resolves certbot — nothing '
        'issues a certificate', () {
      final images = stackFrom(
        front: const DwPlainHttpFront(18080),
      ).pinnedImages;
      expect(images.map((e) => e.$1), ['Postgres', 'nginx']);
    });

    // `deploy check` has to ask the registry about exactly what `deploy run`
    // pulls (#331 M4) — a mirror serving Postgres and nginx just fine says
    // nothing about whether rustfs/rustfs or amazon/aws-cli, neither of
    // which the mirror serves (DwStack.mirrorServes), still resolve upstream.
    test(
      'a registry mirror is applied the same way the renderer applies it: '
      'the official images, and nothing that already names an organisation',
      () {
        final unmirrored = stackVariants()['bundled storage and a site']!.pinnedImages;
        final mirrored = stackFrom(
          extra:
              '  site:\n    domain: example.com\n    source: app_site/build\n'
              '  storage: bundled\n  storage_domain: files.example.com\n'
              '  registry_mirror: mirror.gcr.io\n',
        ).pinnedImages;
        expect(
          mirrored,
          containsAll([
            ('Postgres', 'mirror.gcr.io/${DwStack.postgresImage}'),
            ('nginx', 'mirror.gcr.io/${DwStack.nginxImage}'),
          ]),
        );
        expect(
          mirrored.where((e) => e.$1 == 'certbot').single.$2,
          unmirrored.where((e) => e.$1 == 'certbot').single.$2,
        );
        expect(
          mirrored.where((e) => e.$1 == 'storage').single.$2,
          DwStack.storageImage,
        );
        expect(
          mirrored.where((e) => e.$1 == 'storage-init').single.$2,
          DwStack.storageInitImage,
        );
      },
    );
  });

  group('the rendered compose file', () {
    for (final MapEntry(key: variant, value: stack)
        in stackVariants().entries) {
      test('$variant: is YAML with the services the stack needs', () {
        final services = (_compose(stack)['services'] as YamlMap).keys.toSet();
        expect(services, containsAll(['postgres', 'server', 'web', 'nginx']));
        expect(
          services.contains('storage') && services.contains('storage-init'),
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

    test('the web image is given the app origin it calls, and the one Studio '
        'signs for', () {
      final web = _service(stackFrom(), 'web');
      final args = (web['build'] as YamlMap)['args'] as YamlMap;
      expect(args['DW_BACKEND_URL'], 'https://app.example.com');
      // Without it every app keeps its own address as a default in its
      // Dockerfile, where a stand rename makes it quietly wrong.
      expect(args['STUDIO_APP_ORIGIN'], 'https://app.example.com');
    });

    test('storage: the CORS origin, and the server reaching it by the URL '
        'browsers sign', () {
      final stack = stackVariants()['bundled storage and a site']!;
      final script =
          (_service(stack, 'storage-init')['command'] as YamlList).single
              as String;
      final corsStep = script
          .split('; ')
          .singleWhere(
            (step) => step.contains('dw-cors.json') && step.startsWith('printf'),
          );
      final cors =
          jsonDecode(
                RegExp(
                  "printf '%s' '(.*)' >",
                ).firstMatch(corsStep)!.group(1)!,
              )
              as Map<String, Object?>;
      final rule = (cors['CORSRules']! as List).single as Map;
      expect(rule['AllowedOrigins'], ['https://app.example.com']);
      expect(rule['AllowedMethods'], ['GET', 'PUT']);
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

    test('storage: no console on a deployment — parity with the old '
        'MINIO_BROWSER: off', () {
      final stack = stackVariants()['bundled storage and a site']!;
      final storage = _service(stack, 'storage');
      expect(
        (storage['environment'] as YamlMap)['RUSTFS_CONSOLE_ENABLE'],
        'false',
      );
    });

    test('storage: two buckets — the public one reads objects to anyone and '
        'lists to no one, the private one reads nothing unsigned — and the '
        'server is given both', () {
      final stack = stackVariants()['bundled storage and a site']!;
      expect(stack.publicBucketName, 'shop-public');
      expect(stack.privateBucketName, 'shop-private');
      final script =
          (_service(stack, 'storage-init')['command'] as YamlList).single
              as String;
      final steps = script.split('; ');
      expect(
        steps,
        containsAllInOrder([
          'set -e',
          'aws --endpoint-url http://storage:9000 s3 mb s3://shop-public',
          'aws --endpoint-url http://storage:9000 s3 mb s3://shop-private',
          'aws --endpoint-url http://storage:9000 s3api put-bucket-policy '
              '--bucket shop-public --policy file:///tmp/dw-public-read.json',
          'aws --endpoint-url http://storage:9000 s3api delete-bucket-policy '
              '--bucket shop-private',
        ]),
      );
      // A policy, never a canned ACL: that would also grant s3:ListBucket.
      expect(script, isNot(contains('--acl')));
      final policyStep = steps.singleWhere(
        (step) =>
            step.contains('dw-public-read.json') && step.startsWith('printf'),
      );
      final policy =
          jsonDecode(
                RegExp(
                  "printf '%s' '(.*)' >",
                ).firstMatch(policyStep)!.group(1)!,
              )
              as Map<String, Object?>;
      final statement = (policy['Statement']! as List).single as Map;
      expect(statement['Effect'], 'Allow');
      expect(statement['Principal'], {
        'AWS': ['*'],
      });
      expect(statement['Action'], ['s3:GetObject']);
      expect(statement['Resource'], ['arn:aws:s3:::shop-public/*']);
      // The probe object the outside check reads, in both buckets.
      for (final bucket in ['shop-public', 'shop-private']) {
        expect(
          script,
          contains(
            'aws --endpoint-url http://storage:9000 s3 cp - '
            's3://$bucket/${DwStack.visibilityProbeKey}',
          ),
        );
      }

      final environment = Map.of(
        _service(stack, 'server')['environment'] as YamlMap,
      );
      expect(
        environment,
        containsPair('DW_STORAGE_PUBLIC_BUCKET', 'shop-public'),
      );
      expect(
        environment,
        containsPair(
          'DW_STORAGE_PUBLIC_BASE_URL',
          'https://files.example.com/shop-public',
        ),
      );
      expect(
        environment,
        containsPair('DW_STORAGE_PRIVATE_BUCKET', 'shop-private'),
      );
      expect(environment.containsKey('DW_STORAGE_BUCKET'), isFalse);
      expect(
        stack.reservedSecretKeys,
        containsAll([
          'DW_STORAGE_PUBLIC_BUCKET',
          'DW_STORAGE_PUBLIC_BASE_URL',
          'DW_STORAGE_PRIVATE_BUCKET',
        ]),
      );
    });

    test('external storage: the buckets are the project\'s to name, not '
        'required secrets', () {
      final stack = stackVariants()['external storage, external site, files']!;
      expect(
        stack.requiredSecretKeys,
        containsAll([
          'DW_STORAGE_ENDPOINT',
          'DW_STORAGE_ACCESS_KEY',
          'DW_STORAGE_SECRET_KEY',
        ]),
      );
      expect(
        stack.requiredSecretKeys.where((key) => key.contains('BUCKET')),
        isEmpty,
      );
      expect(
        Map.of(
          _service(stack, 'server')['environment'] as YamlMap,
        ).keys.where((key) => '$key'.startsWith('DW_STORAGE_')),
        isEmpty,
      );
    });

    test('a registry mirror serves the official images and nothing else', () {
      final stack = stackFrom(
        extra:
            '  storage: bundled\n  storage_domain: files.example.com\n'
            '  registry_mirror: mirror.gcr.io\n',
      );
      String image(String service) =>
          _service(stack, service)['image'] as String;
      expect(image('postgres'), 'mirror.gcr.io/${DwStack.postgresImage}');
      expect(image('nginx'), 'mirror.gcr.io/${DwStack.nginxImage}');
      expect(image('storage'), DwStack.storageImage);
      expect(image('storage-init'), DwStack.storageInitImage);
      expect(image('certbot'), DwStack.certbotImage);
    });

    test('a site is mounted from the checkout, read-only', () {
      final nginx = _service(stackVariants()['bundled storage and a site']!, 'nginx');
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
    final stack = stackVariants()['bundled storage and a site']!;
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

    test('storage: streamed to the bundled storage with the signed host '
        'intact', () {
      final storage = _serverBlock(nginx, 'files.example.com');
      expect(storage, contains('proxy_pass http://storage:9000;'));
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
