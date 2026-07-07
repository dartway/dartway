import 'package:dartway_studio_bridge/dartway_studio_bridge.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('StudioText', () {
    test('resolve picks the language', () {
      const text = StudioText('Schedule', 'Расписание');
      expect(text.resolve(StudioLanguage.en), 'Schedule');
      expect(text.resolve(StudioLanguage.ru), 'Расписание');
    });

    test('json round-trip', () {
      const text = StudioText('a', 'б');
      final decoded = StudioText.fromJson(text.toJson());
      expect(decoded.en, 'a');
      expect(decoded.ru, 'б');
    });

    test('fromJson tolerates missing fields', () {
      final decoded = StudioText.fromJson(const {});
      expect(decoded.en, '');
      expect(decoded.ru, '');
    });
  });

  group('StudioScreenSpec', () {
    const spec = StudioScreenSpec(
      path: '/schedule/profile',
      parentPath: '/schedule',
      title: StudioText('Profile', 'Профиль'),
      purpose: StudioText('why', 'зачем'),
      featureSpec: [StudioText('f1', 'ф1')],
      discussionQuestions: [StudioText('q1', 'в1')],
    );

    test('json round-trip preserves all fields', () {
      final decoded = StudioScreenSpec.fromJson(spec.toJson());
      expect(decoded.path, '/schedule/profile');
      expect(decoded.parentPath, '/schedule');
      expect(decoded.title.en, 'Profile');
      expect(decoded.featureSpec.single.ru, 'ф1');
      expect(decoded.discussionQuestions.single.en, 'q1');
    });

    test('omits parentPath when null', () {
      const root = StudioScreenSpec(
        path: '/schedule',
        title: StudioText('Schedule', 'Расписание'),
        purpose: StudioText('', ''),
      );
      expect(root.toJson().containsKey('parentPath'), isFalse);
      expect(StudioScreenSpec.fromJson(root.toJson()).parentPath, isNull);
    });
  });

  group('StudioZoneSpec', () {
    test('access enum round-trips and defaults to any', () {
      const zone = StudioZoneSpec(
        label: StudioText('Auth', 'Авторизация'),
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
    test('json round-trip with zones and personas', () {
      const manifest = StudioProjectManifest(
        projectName: 'Demo',
        zones: [
          StudioZoneSpec(
            label: StudioText('Club', 'Клуб'),
            rootPath: '/schedule',
            access: StudioZoneAccess.signedIn,
            screens: [
              StudioScreenSpec(
                path: '/schedule',
                title: StudioText('Schedule', 'Расписание'),
                purpose: StudioText('', ''),
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
      );
      final decoded = StudioProjectManifest.fromJson(manifest.toJson());
      expect(decoded.projectName, 'Demo');
      expect(decoded.zones.single.access, StudioZoneAccess.signedIn);
      expect(decoded.zones.single.screens.single.path, '/schedule');
      expect(decoded.personas.single.identifier, '79990000003');
    });
  });
}
