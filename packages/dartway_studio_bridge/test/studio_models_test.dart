import 'package:dartway_studio_bridge/dartway_studio_bridge.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('StudioScreenSpec', () {
    const spec = StudioScreenSpec(
      path: '/schedule/profile',
      parentPath: '/schedule',
      title: 'Profile',
      purpose: 'why',
      featureSpec: ['f1'],
      discussionQuestions: ['q1'],
    );

    test('json round-trip preserves all fields', () {
      final decoded = StudioScreenSpec.fromJson(spec.toJson());
      expect(decoded.path, '/schedule/profile');
      expect(decoded.parentPath, '/schedule');
      expect(decoded.title, 'Profile');
      expect(decoded.featureSpec.single, 'f1');
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
        'featureSpec': ['ok', 1, null],
      });
      expect(decoded.title, '');
      expect(decoded.featureSpec, ['ok']);
      expect(decoded.discussionQuestions, isEmpty);
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

    test('allowedPersonaIds round-trips and defaults to empty', () {
      const zone = StudioZoneSpec(
        label: 'Admin',
        rootPath: '/admin',
        allowedPersonaIds: ['admin-alex'],
        screens: [],
      );
      expect(StudioZoneSpec.fromJson(zone.toJson()).allowedPersonaIds,
          ['admin-alex']);
      expect(
        StudioZoneSpec.fromJson(const {'rootPath': '/x'}).allowedPersonaIds,
        isEmpty,
      );
    });
  });

  group('StudioSessionState', () {
    test('json round-trip with a persona', () {
      const session = StudioSessionState(
        isSignedIn: true,
        activePersonaId: 'coach-maria',
        displayLabel: 'Maria',
        isBusy: true,
      );
      final decoded = StudioSessionState.fromJson(session.toJson());
      expect(decoded.isSignedIn, isTrue);
      expect(decoded.activePersonaId, 'coach-maria');
      expect(decoded.displayLabel, 'Maria');
      expect(decoded.isBusy, isTrue);
    });

    test('signedOut constant is empty', () {
      expect(StudioSessionState.signedOut.isSignedIn, isFalse);
      expect(StudioSessionState.signedOut.activePersonaId, isNull);
    });
  });

  group('StudioProjectManifest', () {
    test('json round-trip with zones, personas and locales', () {
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
        personas: [
          StudioPersonaSpec(
            id: 'client-ivan',
            label: 'Client · Ivan',
            identifier: '79990000003',
          ),
        ],
        supportedLocales: ['en', 'ru'],
      );
      final decoded = StudioProjectManifest.fromJson(manifest.toJson());
      expect(decoded.projectName, 'Demo');
      expect(decoded.zones.single.access, StudioZoneAccess.signedIn);
      expect(decoded.zones.single.screens.single.path, '/schedule');
      expect(decoded.personas.single.identifier, '79990000003');
      expect(decoded.supportedLocales, ['en', 'ru']);
    });

    test('supportedLocales defaults to empty', () {
      final decoded = StudioProjectManifest.fromJson(const {'projectName': 'x'});
      expect(decoded.supportedLocales, isEmpty);
    });
  });
}
