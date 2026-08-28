import 'package:dartway_cli/src/deploy/nginx_upstreams.dart';
import 'package:test/test.dart';

void main() {
  group('what a snippet expects the stack to provide', () {
    test('a service named by proxy_pass is an upstream', () {
      expect(
        DwNginxUpstreams.namesIn('''
location /files/ {
  proxy_pass http://minio:9000;
}
'''),
        {'minio'},
      );
    });

    test('an address or a domain is not a service, and neither is a variable', () {
      // Each of these is a legitimate proxy target that no Compose stack
      // declares. A check that reported them would be switched off in a week.
      expect(
        DwNginxUpstreams.namesIn('''
proxy_pass http://127.0.0.1:8080;
proxy_pass https://files.example.com;
proxy_pass http://localhost:3000;
proxy_pass http://\$upstream_from_map;
proxy_pass unix:/var/run/app.sock;
'''),
        isEmpty,
      );
    });

    test('an alias the file defines is read through its own servers', () {
      // `storage` is not a service — it is a name this file invents. What has
      // to exist is what the block points at.
      expect(
        DwNginxUpstreams.namesIn('''
upstream storage {
  server minio:9000;
  server minio_backup:9000;
}
location / {
  proxy_pass http://storage;
}
'''),
        {'minio', 'minio_backup'},
      );
    });

    test('a commented-out directive is not a requirement', () {
      expect(
        DwNginxUpstreams.namesIn('# proxy_pass http://minio:9000;\n'),
        isEmpty,
      );
    });

    test('grpc and fastcgi name backends the same way', () {
      expect(
        DwNginxUpstreams.namesIn(
          'grpc_pass grpc://backend:50051;\nfastcgi_pass php:9000;\n',
        ),
        {'backend', 'php'},
      );
    });
  });

  group('snippets against a stack', () {
    test('names the file and the service that is missing', () {
      expect(
        DwNginxUpstreams.missing(
          snippets: {
            'app/storage.conf': 'proxy_pass http://minio:9000;',
            'api/extra.conf': 'proxy_pass http://backend:8080;',
          },
          services: {'backend', 'web', 'nginx'},
        ),
        ['app/storage.conf: minio'],
      );
    });

    test('agreement is empty, not a message', () {
      expect(
        DwNginxUpstreams.missing(
          snippets: {'api/extra.conf': 'proxy_pass http://backend:8080;'},
          services: {'backend'},
        ),
        isEmpty,
      );
    });
  });

  test('a compose --services listing is one name per line', () {
    expect(
      DwNginxUpstreams.servicesInListing('backend\nminio\nnginx\n\n'),
      {'backend', 'minio', 'nginx'},
    );
  });
}
