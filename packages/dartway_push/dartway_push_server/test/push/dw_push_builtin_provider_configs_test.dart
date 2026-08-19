import 'dart:io';

import 'package:dartway_push_server/dartway_push_server.dart';
import 'package:test/test.dart';

const _serviceAccount =
    '{"type":"service_account","project_id":"demo-project",'
    '"client_email":"push@demo-project.iam.gserviceaccount.com"}';

void main() {
  group('Built-in push provider configs', () {
    late Directory root;
    late String previousCwd;

    // `fromPasswords` reads the service account by a relative path, because
    // that path has to mean the same thing here and inside the container. So a
    // test for it is a test about the working directory.
    setUp(() {
      previousCwd = Directory.current.path;
      root = Directory.systemTemp.createTempSync('dw_push_config_');
      Directory('${root.path}/config').createSync();
      Directory.current = root;
    });

    tearDown(() {
      Directory.current = previousCwd;
      root.deleteSync(recursive: true);
    });

    void writeServiceAccount([String contents = _serviceAccount]) => File(
      '${root.path}/${DwFcmPushProviderConfig.defaultServiceAccountFile}',
    ).writeAsStringSync(contents);

    test('constructs FCM config from a password key and a mounted file', () {
      writeServiceAccount();

      final config = DwFcmPushProviderConfig.fromPasswords({
        'fcmProjectId': 'demo-project',
      });

      expect(config.projectId, 'demo-project');
      expect(config.serviceAccountJson, _serviceAccount);
      expect(config.isConfigured, isTrue);
    });

    test('an environment that declares no project id wants no push', () {
      final config = DwFcmPushProviderConfig.fromPasswords(const {});

      expect(config.isConfigured, isFalse);
      expect(config.projectId, isNull);
    });

    // The finding this whole change is about: a declared provider with a
    // missing credential used to answer `isConfigured == false`, which is the
    // same answer as "we do not send push here". From inside a running server
    // the two were indistinguishable.
    test('a declared provider whose file never arrived fails loudly', () {
      expect(
        () => DwFcmPushProviderConfig.fromPasswords({
          'fcmProjectId': 'demo-project',
        }),
        throwsA(
          isA<DwPushProviderConfigurationException>().having(
            (error) => error.toString(),
            'message',
            allOf(
              contains(DwFcmPushProviderConfig.defaultServiceAccountFile),
              contains('put-file'),
            ),
          ),
        ),
      );
    });

    test('a service account without a project id configures nothing', () {
      expect(
        () => DwFcmPushProviderConfig(
          projectId: null,
          serviceAccountJson: _serviceAccount,
        ),
        throwsA(isA<DwPushProviderConfigurationException>()),
      );
    });

    // A YAML value that lost its quotes, a truncated upload, the wrong file
    // entirely — all of them reach the constructor as a string, and all of
    // them used to reach the first send instead.
    test('a service account that is not a JSON object is refused', () {
      for (final broken in ['not json at all', '"a string"', '[1, 2]']) {
        expect(
          () => DwFcmPushProviderConfig(
            projectId: 'demo-project',
            serviceAccountJson: broken,
          ),
          throwsA(isA<DwPushProviderConfigurationException>()),
          reason: broken,
        );
      }
    });

    test('a path of the app own choosing is honoured', () {
      File('${root.path}/config/other.json').writeAsStringSync(_serviceAccount);

      final config = DwFcmPushProviderConfig.fromPasswords(
        {'fcmProjectId': 'demo-project'},
        serviceAccountFile: 'config/other.json',
      );

      expect(config.serviceAccountJson, _serviceAccount);
    });

    test('constructs RuStore config from app passwords keys', () {
      final config = DwRuStorePushProviderConfig.fromPasswords({
        'rustorePushProjectId': 'demo-project',
        'rustorePushServiceToken': 'rustore-service-token',
      });

      expect(config.projectId, 'demo-project');
      expect(config.serviceToken, 'rustore-service-token');
    });

    test('RuStore is silent about an environment that declares it not', () {
      expect(
        DwRuStorePushProviderConfig.fromPasswords(const {}).isConfigured,
        isFalse,
      );
    });

    test('a declared RuStore provider missing its token fails loudly', () {
      expect(
        () => DwRuStorePushProviderConfig.fromPasswords({
          'rustorePushProjectId': 'demo-project',
        }),
        throwsA(
          isA<DwPushProviderConfigurationException>().having(
            (error) => error.toString(),
            'message',
            contains('service token'),
          ),
        ),
      );
    });

    test(
      'allows explicit constructor values for built-in provider configs',
      () {
        final fcm = DwFcmPushProviderConfig(
          projectId: 'demo-project',
          serviceAccountJson: _serviceAccount,
          webpushIcon: '/icons/push.png',
          androidIcon: 'ic_notification',
          androidColor: '#102030',
        );
        final ruStore = DwRuStorePushProviderConfig(
          projectId: 'demo-project',
          serviceToken: 'rustore-service-token',
          androidIcon: 'ic_notification',
          androidColor: '#102030',
        );

        expect(fcm.projectId, 'demo-project');
        expect(fcm.webpushIcon, '/icons/push.png');
        expect(fcm.androidIcon, 'ic_notification');
        expect(fcm.androidColor, '#102030');
        expect(ruStore.projectId, 'demo-project');
        expect(ruStore.androidIcon, 'ic_notification');
        expect(ruStore.androidColor, '#102030');
      },
    );
  });
}
