import 'package:dartway_push_server/dartway_push_server.dart';
import 'package:test/test.dart';

void main() {
  group('Built-in push provider configs', () {
    test('constructs FCM config from app passwords keys', () {
      final config = DwFcmPushProviderConfig.fromPasswords({
        'fcmProjectId': 'demo-project',
        'fcmServiceAccountJson':
            '{"type":"service_account","project_id":"demo-project"}',
      });

      expect(config.projectId, 'demo-project');
      expect(
        config.serviceAccountJson,
        '{"type":"service_account","project_id":"demo-project"}',
      );
    });

    test('constructs RuStore config from app passwords keys', () {
      final config = DwRuStorePushProviderConfig.fromPasswords({
        'rustorePushProjectId': 'demo-project',
        'rustorePushServiceToken': 'rustore-service-token',
      });

      expect(config.projectId, 'demo-project');
      expect(config.serviceToken, 'rustore-service-token');
    });

    test(
      'allows explicit constructor values for built-in provider configs',
      () {
        final fcm = DwFcmPushProviderConfig(
          projectId: 'demo-project',
          serviceAccountJson:
              '{"type":"service_account","project_id":"demo-project"}',
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
