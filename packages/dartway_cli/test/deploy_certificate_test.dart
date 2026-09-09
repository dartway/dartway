import 'dart:io';

import 'package:dartway_cli/src/deploy/deploy_runner.dart';
import 'package:dartway_cli/src/deploy/deploy_target.dart';
import 'package:dartway_cli/src/deploy/serverpod_config.dart';
import 'package:dartway_cli/src/deploy/ssh_runner.dart';
import 'package:test/test.dart';

/// An SSH runner that records what it was asked to run and answers nothing.
class _RecordingSsh extends DwSshRunner {
  _RecordingSsh()
    : super(host: '203.0.113.10', user: 'root', identityFile: null);

  final List<String> issued = [];

  @override
  Future<DwSshResult> run(String command) async {
    issued.add(command);
    return const DwSshResult(exitCode: 0, stdout: '', stderr: '');
  }

  @override
  Future<DwSshResult> runAs(String deployUser, String command) => run(command);
}

DwDeployTarget _target() => DwDeployTarget(
  environment: 'staging',
  host: '203.0.113.10',
  sshUser: 'root',
  deployUser: 'deployer',
  os: 'ubuntu',
  repo: 'git@github.com:acme/shop.git',
  branch: 'master',
  sslEmail: 'ops@example.com',
  webAppDomain: 'app.example.com',
  requiredSecretFiles: const [],
);

DwServerpodConfig _serverpod({String? apiPublicHost = 'api.example.com'}) =>
    DwServerpodConfig(
      environment: 'staging',
      relativePath: 'shop_server/config/staging.yaml',
      apiServer: DwServerEndpoint(
        name: 'apiServer',
        port: 8080,
        publicHost: apiPublicHost,
        publicPort: 443,
        publicScheme: 'https',
      ),
      insightsServer: DwServerEndpoint(
        name: 'insightsServer',
        port: 8081,
        publicHost: 'insights.example.com',
        publicPort: 443,
        publicScheme: 'https',
      ),
      webServer: DwServerEndpoint(
        name: 'webServer',
        port: 8082,
        publicHost: 'srv.example.com',
        publicPort: 443,
        publicScheme: 'https',
      ),
      databaseHost: 'postgres',
      databasePort: 5432,
      databaseName: 'shop',
      databaseUser: 'shop',
      redisEnabled: false,
      redisHost: null,
    );

DwDeployRunner _runner(
  _RecordingSsh ssh, {
  String? apiPublicHost = 'api.example.com',
}) =>
    DwDeployRunner(
      ssh: ssh,
      target: _target(),
      serverpod: _serverpod(apiPublicHost: apiPublicHost),
      stdout: stdout,
    );

void main() {
  group('the deployment issues its own certificate', () {
    test('the step runs after the stack is up and before nginx restarts', () {
      final ids = _runner(
        _RecordingSsh(),
      ).steps(skipGitUpdate: false).map((step) => step.id).toList();

      expect(ids, contains('certificate'));
      expect(ids.indexOf('certificate'), greaterThan(ids.indexOf('up')));
      expect(
        ids.indexOf('certificate'),
        lessThan(ids.indexOf('restart-proxy')),
      );
    });

    test('it asks for one certificate covering every served name', () async {
      final ssh = _RecordingSsh();
      await _runner(ssh).issueCertificate();

      final command = ssh.issued.single;
      expect(command, contains('certbot certonly --webroot'));
      expect(command, contains("--cert-name 'api.example.com'"));
      for (final domain in [
        'api.example.com',
        'insights.example.com',
        'srv.example.com',
        'app.example.com',
      ]) {
        expect(command, contains("-d '$domain'"));
      }
      expect(command, contains("--email 'ops@example.com'"));
    });

    test('a lineage certbot already manages is left alone', () async {
      final ssh = _RecordingSsh();
      await _runner(ssh).issueCertificate();

      // Non-empty, not merely present: a failed attempt leaves the renewal
      // config behind empty, and certbot then issues under `<name>-0001`,
      // which nginx never names.
      expect(
        ssh.issued.single,
        contains('test -s /etc/letsencrypt/renewal/api.example.com.conf'),
      );
    });

    test('the bootstrap certificate is cleared out of the way first', () async {
      final ssh = _RecordingSsh();
      await _runner(ssh).issueCertificate();

      // certonly refuses to write into a live directory that exists, and the
      // self-signed bootstrap certificate is written into exactly that one.
      expect(
        ssh.issued.single,
        contains('rm -rf /etc/letsencrypt/live/api.example.com'),
      );
    });

    test('a config with no public API host fails and issues nothing', () async {
      final ssh = _RecordingSsh();
      final result = await _runner(ssh, apiPublicHost: null).issueCertificate();

      expect(result.ok, isFalse);
      expect(result.stderr, contains('publicHost'));
      expect(ssh.issued, isEmpty);
    });
  });
}
