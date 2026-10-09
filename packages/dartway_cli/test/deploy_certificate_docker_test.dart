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
  late File failing;
  late File issuing;
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
  /// does, with [arguments] as its positional parameters; returns what it
  /// printed.
  String inCertbot(String script, [List<String> arguments = const []]) {
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
    return result.stdout as String;
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

  /// The one-day self-signed certificate `deploy setup` writes straight into
  /// the live directory, with nothing else of a lineage beside it.
  void bootstrap() => inCertbot(
    r'''
set -e
name=$1
le=/etc/letsencrypt
rm -rf "$le/live/$name" "$le/archive/$name" "$le/renewal/$name.conf" "$le/dw-bootstrap/$name"
mkdir -p "$le/live/$name"
openssl req -x509 -nodes -newkey rsa:2048 -days 1 \
  -keyout "$le/live/$name/privkey.pem" \
  -out "$le/live/$name/fullchain.pem" \
  -subj "/CN=$name" 2>/dev/null
''',
    [stack.target.apiDomain],
  );

  /// The sha256 of the live certificate and key, `missing` for one absent.
  String liveBytes() => inCertbot(
    r'''
for file in fullchain privkey; do
  path=/etc/letsencrypt/live/$1/$file.pem
  if [ -e "$path" ]; then sha256sum <"$path"; else echo missing; fi
done
''',
    [stack.target.apiDomain],
  );

  /// Which of a lineage's paths exist under the certificate's name, the
  /// bootstrap's stash among them.
  List<String> present() => inCertbot(
    r'''
le=/etc/letsencrypt
for path in "live/$1" "archive/$1" "renewal/$1.conf" "dw-bootstrap/$1"; do
  if [ -e "$le/$path" ]; then echo "$path"; fi
done
''',
    [stack.target.apiDomain],
  ).split('\n').where((line) => line.isNotEmpty).toList();

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
    failing = File(p.join(fake.path, 'fail'));
    issuing = File(p.join(fake.path, 'issue'));
    final certbot = File(p.join(fake.path, 'certbot'))
      ..writeAsStringSync(
        '#!/bin/sh\n'
        'echo "\$*" >>/dw-fake/asked\n'
        // A failing certbot, running first whatever residue the test wants
        // it to leave behind.
        'if [ -e /dw-fake/fail ]; then sh /dw-fake/fail; exit 1; fi\n'
        // A succeeding one, writing whatever the test wants it to issue.
        'if [ -e /dw-fake/issue ]; then sh /dw-fake/issue; fi\n',
      );
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
  });

  // dartway/dartway#436: certonly will not write into the live directory the
  // bootstrap occupies, and a failed issuance used to leave none at all —
  // nginx then refused to start at its next restart.
  group('a first issuance over the bootstrap certificate', () {
    late final name = stack.target.apiDomain;
    tearDown(() {
      if (failing.existsSync()) failing.deleteSync();
      if (issuing.existsSync()) issuing.deleteSync();
    });

    test('that fails leaves the bootstrap certificate byte for byte', () async {
      bootstrap();
      final before = liveBytes();
      failing.writeAsStringSync('');

      final step = await runner.issueCertificate();
      expect(step.ok, isFalse);
      expect(
        step.stderr,
        contains('the self-signed certificate is back in place'),
      );
      expect(askedOfCertbot().single, startsWith('certonly'));
      expect(liveBytes(), before);
      expect(liveBytes(), isNot(contains('missing')));
      expect(present(), ['live/$name']);
    });

    test('that fails leaving residue puts the bootstrap back without '
        'it', () async {
      bootstrap();
      final before = liveBytes();
      failing.writeAsStringSync(
        ': >/etc/letsencrypt/renewal/$name.conf\n'
        'mkdir -p /etc/letsencrypt/archive/$name\n',
      );

      final step = await runner.issueCertificate();
      expect(step.ok, isFalse);
      askedOfCertbot();
      expect(liveBytes(), before);
      expect(present(), ['live/$name']);

      // The next deploy still reads the lineage as unmanaged, and asks for a
      // new certificate rather than an extension.
      failing.deleteSync();
      final next = await runner.issueCertificate();
      expect(next.ok, isTrue, reason: next.stderr);
      expect(next.stdout, isNot(contains('extending')));
      expect(next.stdout, isNot(contains('already manages')));
      expect(askedOfCertbot().single, isNot(contains('--expand')));
    });

    test('that succeeds replaces it, and keeps no stash', () async {
      bootstrap();
      final before = liveBytes();
      // A new lineage in the place certbot writes one: a new key and
      // certificate under live/, and the renewal config that marks it managed.
      issuing.writeAsStringSync(
        'set -e\n'
        'le=/etc/letsencrypt\n'
        'mkdir -p \$le/live/$name \$le/renewal\n'
        'openssl req -x509 -nodes -newkey rsa:2048 -days 90 '
        '-keyout \$le/live/$name/privkey.pem '
        '-out \$le/live/$name/fullchain.pem -subj /CN=$name 2>/dev/null\n'
        'echo "cert = \$le/live/$name/fullchain.pem" >\$le/renewal/$name.conf\n',
      );

      final step = await runner.issueCertificate();
      expect(step.ok, isTrue, reason: step.stderr);
      expect(step.stdout, isNot(contains('extending')));
      final request = askedOfCertbot().single;
      expect(request, startsWith('certonly'));
      expect(request, isNot(contains('--expand')));
      final after = liveBytes();
      expect(after, isNot(contains('missing')));
      final [fullchain, privkey] = after.trim().split('\n');
      final [oldFullchain, oldPrivkey] = before.trim().split('\n');
      expect(fullchain, isNot(oldFullchain));
      expect(privkey, isNot(oldPrivkey));
      expect(present(), ['live/$name', 'renewal/$name.conf']);
    });

    test('after a run stopped with the bootstrap set aside, and failing, '
        'restores it from the stash', () async {
      bootstrap();
      final before = liveBytes();
      inCertbot(
        'mkdir -p /etc/letsencrypt/dw-bootstrap && '
        'mv /etc/letsencrypt/live/\$1 /etc/letsencrypt/dw-bootstrap/\$1',
        [name],
      );
      expect(present(), ['dw-bootstrap/$name']);
      failing.writeAsStringSync('');

      final step = await runner.issueCertificate();
      expect(step.ok, isFalse);
      askedOfCertbot();
      expect(liveBytes(), before);
      expect(present(), ['live/$name']);
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
