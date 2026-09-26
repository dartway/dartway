import 'package:dartway_cli/src/deploy/deploy_target.dart';
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

import 'support/deploy_fixtures.dart';

Matcher _refusal(List<String> fragments) => throwsA(
  isA<StateError>().having(
    (error) => error.message,
    'message',
    allOf([for (final fragment in fragments) contains(fragment)]),
  ),
);

void main() {
  group('deploy/config.yaml', () {
    test('what the project requires is declared once, above the machines', () {
      const text = '''
requires:
  secrets: [SMS_API_TOKEN]
  files: [fcm.json]

staging:
  host: 203.0.113.10
  ssh_user: root
  deploy_user: deployer
  os: ubuntu
  repo: git@github.com:acme/shop.git
  branch: master
  ssl_email: ops@example.com
  api_domain: api.example.com
  app_domain: app.example.com
  requires:
    secrets: [SENTRY_DSN]
''';

      final target = DwDeployTarget.parse(text, environment: 'staging');

      expect(target.requiredSecrets, ['SMS_API_TOKEN', 'SENTRY_DSN']);
      expect(target.requiredSecretFiles, ['fcm.json']);
    });

    test('a bad name is named where it was written', () {
      const text = '''
requires:
  secrets: [sms_api_token]

staging:
  host: 203.0.113.10
  ssh_user: root
  deploy_user: deployer
  os: ubuntu
  repo: git@github.com:acme/shop.git
  branch: master
  ssl_email: ops@example.com
  api_domain: api.example.com
  app_domain: app.example.com
''';

      expect(
        () => DwDeployTarget.parse(text, environment: 'staging'),
        _refusal(['deploy/config.yaml > requires > secrets', 'sms_api_token']),
      );
    });

    test('"local" is not a deployment, and says what it is instead', () {
      expect(
        () => DwDeployTarget.parse(
          '${configYaml()}\nlocal:\n  DW_DATABASE_PORT: 8090\n',
          environment: 'local',
        ),
        _refusal(['not a deployment', 'dartway secret list --env local']),
      );
    });

    test('neither "local" nor "requires" is offered as an environment', () {
      final document = loadYaml('''
requires:
  secrets: [SMS_API_TOKEN]
local:
  DW_DATABASE_PORT: 8090
staging:
  host: 203.0.113.10
production:
  host: 203.0.113.11
''');

      expect(DwDeployTarget.deployableIn(document as YamlMap), [
        'staging',
        'production',
      ]);
    });

    test('an unknown environment lists the deployable ones only', () {
      expect(
        () => DwDeployTarget.parse(
          '${configYaml()}\nlocal:\n  DW_DATABASE_PORT: 8090\n',
          environment: 'produciton',
        ),
        _refusal(['Declared: staging']),
      );
    });

    test('a complete environment reads into the stack it describes', () {
      final target = targetFrom(
        extra:
            '  site:\n    domain: example.com\n    source: app_site/build/\n'
            '  storage: bundled\n  storage_domain: files.example.com\n'
            '  firewall_ports: [5432]\n'
            '  requires:\n    secrets: [SMS_API_TOKEN]\n    files: [fcm.json]\n',
      );

      expect(target.apiDomain, 'api.example.com');
      expect(target.appDomain, 'app.example.com');
      expect(target.site!.source, 'app_site/build');
      expect(target.storage, DwStorageMode.bundled);
      expect(target.servedDomains, [
        'api.example.com',
        'app.example.com',
        'example.com',
        'files.example.com',
      ]);
      expect(target.appDir, '/home/deployer/shop');
      expect(target.runtimeConfigDir, '/home/deployer/.config/shop');
    });

    test('an external site is recorded and not served', () {
      final target = targetFrom(
        extra: '  site:\n    domain: example.com\n    source: none\n',
      );
      expect(target.site!.deployed, isFalse);
      expect(target.servedDomains, isNot(contains('example.com')));
    });

    // A key the deploy does not read is a setting somebody believes is in
    // force. The two here are exactly what an older config carries.
    test('an unknown key is refused by name, with the known ones', () {
      expect(
        () => targetFrom(
          extra: '  web_app_domain: app.example.com\n  server_entrypoint: x\n',
        ),
        _refusal([
          'unknown key "web_app_domain"',
          'unknown key "server_entrypoint"',
          'known: api_domain, app_domain',
        ]),
      );
    });

    test('every problem is reported at once', () {
      expect(
        () => DwDeployTarget.parse('''
staging:
  host: 203.0.113.10
  storage: bundled
  requires:
    secrets: [smsToken]
    files: ['*.json']
''', environment: 'staging'),
        _refusal([
          'missing required key "ssh_user"',
          'missing required key "api_domain"',
          '"storage: bundled" needs "storage_domain"',
          '"smsToken" is not a secret name',
          '"*.json" is not a file name',
        ]),
      );
    });

    test('two roles on one host are refused, because nginx routes by name', () {
      expect(
        () => targetFrom(
          extra: '  storage: bundled\n  storage_domain: APP.example.com\n',
        ),
        _refusal(['app_domain and storage_domain are both']),
      );
    });

    test('a storage domain without bundled storage is refused', () {
      expect(
        () => targetFrom(
          extra: '  storage: external\n  storage_domain: files.example.com\n',
        ),
        _refusal(['only read with "storage: bundled"']),
      );
    });

    test('a site outside the repository is refused', () {
      expect(
        () => targetFrom(
          extra: '  site:\n    domain: example.com\n    source: ../site\n',
        ),
        _refusal(['must be a directory inside the repository']),
      );
    });

    test('a domain that is not a host name is refused', () {
      expect(
        () => DwDeployTarget.parse(
          configYaml().replaceFirst('api.example.com', 'https://api'),
          environment: 'staging',
        ),
        _refusal(['api_domain "https://api" is not a host name']),
      );
    });

    test('an undeclared environment names the declared ones', () {
      expect(
        () => DwDeployTarget.parse(configYaml(), environment: 'production'),
        _refusal(['No "production" environment', 'Declared: staging']),
      );
    });
  });

  group('secret names', () {
    test('are environment variables in upper case', () {
      expect(dwIsSecretKeyName('SMS_API_TOKEN'), isTrue);
      expect(dwIsSecretKeyName('_PRIVATE'), isTrue);
      expect(dwIsSecretKeyName('smsToken'), isFalse);
      expect(dwIsSecretKeyName('1PASSWORD'), isFalse);
      expect(dwIsSecretKeyName('A-B'), isFalse);
    });

    // Compose reads COMPOSE_* out of `.env` as its own settings.
    test('refuse what Compose would read as its own setting', () {
      expect(dwIsSecretKeyName('COMPOSE_PROJECT_NAME'), isFalse);
    });

    test('a secret file is one name of the flat store', () {
      expect(dwIsSecretFileName('fcm-service-account.json'), isTrue);
      expect(dwIsSecretFileName('dir/fcm.json'), isFalse);
      expect(dwIsSecretFileName('*.json'), isFalse);
      expect(dwIsSecretFileName('secrets.env'), isFalse);
    });
  });
}
