@Tags(['docker'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:dartway_cli/src/deploy/compose_files.dart';
import 'package:dartway_cli/src/deploy/deploy_runner.dart';
import 'package:dartway_cli/src/deploy/renderer.dart';
import 'package:dartway_cli/src/deploy/stack.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'support/deploy_fixtures.dart';

/// The two facts the certificate step rests on, proven against the pinned
/// images rather than against a fake that answers the way someone remembers
/// them answering (dartway/dartway#433):
///
/// - which hosts the certificate covers, read in the real certbot image — the
///   previous reading parsed a line certbot 5 no longer prints, and every
///   deploy asked Let's Encrypt to extend a certificate that already named
///   every host;
/// - that the proxy a previous deploy left running answers the ACME challenge
///   for a host added to the configuration since, which is what lets the step
///   run before anything of the new deploy is started.
///
/// Nothing here reaches Let's Encrypt: the lineages are made locally, and the
/// one-off certbot container the step runs finds a recorder named `certbot`
/// first on its `PATH` (through the project override the step names, as a
/// project's own would be), so what the step would have asked is read back
/// while everything before it — Compose, the image, `openssl` — is real.
void main() {
  late Directory dir;
  late String project;
  late DwStack stack;
  late DwDeployRunner runner;
  late File asked;
  late File projectOverride;
  late String fakeOverride;

  /// What the step asked of certbot since the last call, one line per ask.
  List<String> askedOfCertbot() {
    if (!asked.existsSync()) return [];
    final lines = asked
        .readAsLinesSync()
        .where((line) => line.isNotEmpty)
        .toList();
    asked.deleteSync();
    return lines;
  }

  ProcessResult compose(List<String> arguments) => Process.runSync('docker', [
    'compose',
    '-p',
    project,
    ...arguments,
  ], workingDirectory: dir.path);

  /// Runs [script] in a one-off certbot container of the stack, as the step
  /// does, with [arguments] as its positional parameters.
  void inCertbot(String script, [List<String> arguments = const []]) {
    final result = compose([
      'run',
      '--rm',
      '-T',
      '--entrypoint',
      'sh',
      DwStack.certbotService,
      '-c',
      script,
      '--',
      ...arguments,
    ]);
    if (result.exitCode != 0) fail('certbot container: ${result.stderr}');
  }

  /// A lineage the way certbot lays one out — renewal config, archive, live
  /// symlinks — for a certificate naming [hosts], signed by a throwaway CA.
  void lineage(List<String> hosts) => inCertbot(
    r'''
set -e
name=$1
cd "$(mktemp -d)"
openssl req -x509 -nodes -newkey rsa:2048 -days 30 -keyout ca.key -out ca.pem -subj '/CN=Throwaway CA' 2>/dev/null
openssl req -nodes -newkey rsa:2048 -keyout key.pem -out req.csr -subj "/CN=$name" 2>/dev/null
san=$(for host in "$@"; do printf 'DNS:%s,' "$host"; done)
printf 'subjectAltName=%s\n' "${san%,}" >ext.cnf
openssl x509 -req -in req.csr -CA ca.pem -CAkey ca.key -CAcreateserial -days 83 -out cert.pem -extfile ext.cnf 2>/dev/null
le=/etc/letsencrypt
rm -rf "$le/live/$name" "$le/archive/$name" "$le/renewal/$name.conf"
mkdir -p "$le/archive/$name" "$le/live/$name" "$le/renewal"
cp cert.pem "$le/archive/$name/cert1.pem"
cp ca.pem "$le/archive/$name/chain1.pem"
cat cert.pem ca.pem >"$le/archive/$name/fullchain1.pem"
cp key.pem "$le/archive/$name/privkey1.pem"
for file in cert chain fullchain privkey; do
  ln -s "../../archive/$name/${file}1.pem" "$le/live/$name/$file.pem"
done
cat >"$le/renewal/$name.conf" <<CONF
archive_dir = $le/archive/$name
cert = $le/live/$name/cert.pem
privkey = $le/live/$name/privkey.pem
chain = $le/live/$name/chain.pem
fullchain = $le/live/$name/fullchain.pem

[renewalparams]
authenticator = webroot
webroot_path = /var/www/certbot,
server = https://acme-v02.api.letsencrypt.org/directory
CONF
''',
    [stack.target.apiDomain, ...hosts],
  );

  setUpAll(() {
    dir = Directory.systemTemp.createTempSync('dw_certificate_');
    project = p.basename(dir.path).toLowerCase();
    stack = stackFrom();
    File(
      p.join(dir.path, 'docker-compose.yml'),
    ).writeAsStringSync(DwStackRenderer(stack: stack).composeFile);
    File(p.join(dir.path, '.env')).writeAsStringSync(
      stack.requiredSecretKeys.map((key) => "$key='dw-test'\n").join(),
    );
    final fake = Directory(p.join(dir.path, 'fake'))..createSync();
    asked = File(p.join(fake.path, 'asked'));
    final certbot = File(p.join(fake.path, 'certbot'))
      ..writeAsStringSync('#!/bin/sh\necho "\$*" >>/dw-fake/asked\n');
    Process.runSync('chmod', ['+x', certbot.path]);
    projectOverride = File(p.join(dir.path, DwComposeFiles.projectOverride))
      ..createSync(recursive: true);
    // The image's own PATH, with the recorder in front of it.
    fakeOverride =
        """
services:
  ${DwStack.certbotService}:
    environment:
      PATH: /dw-fake:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
    volumes:
      - ${fake.path}:/dw-fake
""";
    projectOverride.writeAsStringSync(fakeOverride);
    runner = DwDeployRunner(ssh: LocalShell(), stack: stack, appDir: dir.path);
  });

  tearDownAll(() {
    compose(['down', '--volumes', '--remove-orphans']);
    dir.deleteSync(recursive: true);
  });

  // First, while nothing of the project exists: a first deploy, where
  // `setup` has started no proxy.
  group('through the proxy still serving, with no container of the project '
      'at all', () {
    test('the step exits 0 and asks nothing of certbot', () async {
      final containers = Process.runSync('docker', [
        'ps',
        '-aq',
        '--filter',
        'label=com.docker.compose.project=$project',
      ]);
      expect((containers.stdout as String).trim(), isEmpty);

      final step = await runner.issueCertificate(throughServingProxy: true);
      expect(step.ok, isTrue, reason: step.stderr);
      expect(step.stdout, contains('no proxy is running'));
      expect(askedOfCertbot(), isEmpty);
    });

    test('a Compose that cannot answer fails the step instead', () async {
      projectOverride.writeAsStringSync('services: [\n');
      addTearDown(() => projectOverride.writeAsStringSync(fakeOverride));

      final step = await runner.issueCertificate(throughServingProxy: true);
      expect(step.ok, isFalse);
      expect(step.stdout, isNot(contains('no proxy is running')));
      expect(askedOfCertbot(), isEmpty);
    });
  });

  group('the coverage read in ${DwStack.certbotImage}', () {
    test('a certificate naming every served host asks nothing', () async {
      lineage(stack.target.servedDomains);

      final step = await runner.issueCertificate();
      expect(step.ok, isTrue, reason: step.stderr);
      expect(step.stdout, contains('already manages'));
      expect(askedOfCertbot(), isEmpty);
    });

    test('a host the certificate does not name is asked for, and only '
        'it', () async {
      lineage([stack.target.apiDomain]);

      final step = await runner.issueCertificate();
      expect(step.ok, isTrue, reason: step.stderr);
      expect(
        step.stdout,
        contains(
          'extending ${stack.target.apiDomain} to: '
          '${stack.target.appDomain}\n',
        ),
      );
      final request = askedOfCertbot().single;
      expect(request, startsWith('certonly'));
      expect(request, contains('--expand'));
      for (final host in stack.target.servedDomains) {
        expect(request, contains('-d $host'));
      }
    });

    test('the bootstrap certificate is replaced by an issued one', () async {
      inCertbot(
        'rm -f /etc/letsencrypt/renewal/${stack.target.apiDomain}.conf',
      );

      final step = await runner.issueCertificate();
      expect(step.ok, isTrue, reason: step.stderr);
      expect(step.stdout, isNot(contains('extending')));
      final request = askedOfCertbot().single;
      expect(request, startsWith('certonly'));
      expect(request, isNot(contains('--expand')));
    });
  });

  test('the proxy a previous deploy rendered answers the ACME challenge for a '
      'host added since', () async {
    // The proxy as a deploy configured for api and app left it running; the
    // configuration being deployed adds a storage host it has never heard of.
    lineage(stack.target.servedDomains);
    const token = 'dw-challenge-token';
    inCertbot(
      'mkdir -p /var/www/certbot/.well-known/acme-challenge && '
      'echo $token >/var/www/certbot/.well-known/acme-challenge/$token',
    );
    File(
      p.join(dir.path, 'nginx.conf'),
    ).writeAsStringSync(DwStackRenderer(stack: stack).nginxFile);
    for (final snippets in ['http', 'api', 'app']) {
      Directory(
        p.join(dir.path, 'nginx.d', snippets),
      ).createSync(recursive: true);
    }
    // A project's own port-80 server: it takes the hosts it names, and only
    // those — it is included after ours, so it is not the default.
    File(p.join(dir.path, 'nginx.d', 'http', 'legacy.conf')).writeAsStringSync(
      'server {\n'
      '    listen 80;\n'
      '    server_name legacy.example.com;\n'
      '    return 410;\n'
      '}\n',
    );
    final name = '$project-nginx';
    final started = Process.runSync('docker', [
      'run',
      '-d',
      '--rm',
      '--name',
      name,
      '-p',
      '127.0.0.1::80',
      // The upstreams resolve once, at start; nothing here proxies to them.
      '--add-host',
      '${DwStack.serverService}:127.0.0.1',
      '--add-host',
      '${DwStack.webService}:127.0.0.1',
      '-v',
      '${p.join(dir.path, 'nginx.conf')}:/etc/nginx/conf.d/default.conf:ro',
      '-v',
      '${p.join(dir.path, 'nginx.d')}:/etc/nginx/dartway:ro',
      '-v',
      '${project}_certbot_data:/etc/letsencrypt:ro',
      '-v',
      '${project}_certbot_www:/var/www/certbot:ro',
      stack.resolvedImage(DwStack.nginxImage),
    ]);
    expect(started.exitCode, 0, reason: '${started.stderr}');
    addTearDown(() => Process.runSync('docker', ['rm', '-f', name]));
    final port =
        (Process.runSync('docker', ['port', name, '80/tcp']).stdout as String)
            .trim()
            .split(':')
            .last;

    Future<(int, String)> get(String host, String path) async {
      final client = HttpClient();
      try {
        for (var attempt = 0; ; attempt++) {
          try {
            final request = await client.get('127.0.0.1', int.parse(port), path)
              ..followRedirects = false
              ..headers.host = host;
            final response = await request.close();
            return (
              response.statusCode,
              await response.transform(utf8.decoder).join(),
            );
          } on IOException {
            // The published port answers before nginx inside it does.
            if (attempt == 40) {
              final log = Process.runSync('docker', ['logs', name]);
              fail('nginx did not answer: ${log.stdout}${log.stderr}');
            }
            await Future<void>.delayed(const Duration(milliseconds: 250));
          }
        }
      } finally {
        client.close(force: true);
      }
    }

    const challenge = '/.well-known/acme-challenge/$token';
    for (final host in [stack.target.apiDomain, 'files.example.com']) {
      final (status, body) = await get(host, challenge);
      expect(status, 200, reason: '$host$challenge');
      expect(body.trim(), token);
    }
    // The same server block, not a fallback that happens to serve files.
    final (status, _) = await get('files.example.com', '/');
    expect(status, 301);
    final (legacy, _) = await get('legacy.example.com', challenge);
    expect(legacy, 410);
  });
}
