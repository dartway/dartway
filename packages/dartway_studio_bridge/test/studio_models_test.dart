import 'package:dartway_studio_bridge/dartway_studio_bridge.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('StudioScreenSpec', () {
    const spec = StudioScreenSpec(
      path: '/schedule/profile',
      parentPath: '/schedule',
      title: 'Profile',
      purpose: 'why',
      discussionQuestions: ['q1'],
    );

    test('json round-trip preserves all fields', () {
      final decoded = StudioScreenSpec.fromJson(spec.toJson());
      expect(decoded.path, '/schedule/profile');
      expect(decoded.parentPath, '/schedule');
      expect(decoded.title, 'Profile');
      expect(decoded.discussionQuestions.single, 'q1');
    });

    test('omits parentPath when null', () {
      const root = StudioScreenSpec(
        path: '/schedule',
        title: 'Schedule',
        purpose: '',
      );
      expect(root.toJson().containsKey('parentPath'), isFalse);
      expect(StudioScreenSpec.fromJson(root.toJson()).parentPath, isNull);
    });

    test('fromJson tolerates missing and non-string list items', () {
      final decoded = StudioScreenSpec.fromJson(const {
        'path': '/x',
        'discussionQuestions': ['ok', 1, null],
      });
      expect(decoded.title, '');
      expect(decoded.discussionQuestions, ['ok']);
    });
  });

  group('StudioZoneSpec', () {
    test('access enum round-trips and defaults to any', () {
      const zone = StudioZoneSpec(
        label: 'Auth',
        rootPath: '/auth',
        access: StudioZoneAccess.signedOut,
        screens: [],
      );
      expect(StudioZoneSpec.fromJson(zone.toJson()).access,
          StudioZoneAccess.signedOut);
      expect(
        StudioZoneSpec.fromJson(const {'rootPath': '/x'}).access,
        StudioZoneAccess.any,
      );
    });

  });

  group('StudioSessionState', () {
    test('json round-trip with a signed-in user', () {
      const session = StudioSessionState(
        isSignedIn: true,
        userIdentifier: '79990000002',
        displayLabel: 'Maria',
        isBusy: true,
      );
      final decoded = StudioSessionState.fromJson(session.toJson());
      expect(decoded.isSignedIn, isTrue);
      expect(decoded.userIdentifier, '79990000002');
      expect(decoded.displayLabel, 'Maria');
      expect(decoded.isBusy, isTrue);
    });

    test('signedOut constant is empty', () {
      expect(StudioSessionState.signedOut.isSignedIn, isFalse);
      expect(StudioSessionState.signedOut.userIdentifier, isNull);
    });
  });

  group('StudioProjectManifest', () {
    test('json round-trip with zones and locales', () {
      const manifest = StudioProjectManifest(
        projectName: 'Demo',
        zones: [
          StudioZoneSpec(
            label: 'Club',
            rootPath: '/schedule',
            access: StudioZoneAccess.signedIn,
            screens: [
              StudioScreenSpec(
                path: '/schedule',
                title: 'Schedule',
                purpose: '',
              ),
            ],
          ),
        ],
        features: [
          StudioFeatureInfo(
            id: 'schedule/session-list',
            title: 'Session list',
            description: 'Realtime list',
          ),
        ],
        supportedLocales: ['en', 'ru'],
      );
      final decoded = StudioProjectManifest.fromJson(manifest.toJson());
      expect(decoded.projectName, 'Demo');
      expect(decoded.zones.single.access, StudioZoneAccess.signedIn);
      expect(decoded.zones.single.screens.single.path, '/schedule');
      expect(decoded.features.single.id, 'schedule/session-list');
      expect(decoded.supportedLocales, ['en', 'ru']);
    });

    test('features and supportedLocales default to empty', () {
      final decoded = StudioProjectManifest.fromJson(const {'projectName': 'x'});
      expect(decoded.features, isEmpty);
      expect(decoded.supportedLocales, isEmpty);
    });
  });
}
