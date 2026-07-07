import 'package:dartway_studio_bridge/dartway_studio_bridge.dart';
import 'package:flutter_test/flutter_test.dart';

StudioScreenSpec _screen(String path, String? parent, String title) =>
    StudioScreenSpec(
      path: path,
      parentPath: parent,
      title: StudioText(title, title),
      purpose: const StudioText('', ''),
    );

void main() {
  final manifest = StudioProjectManifest(
    projectName: 'Demo',
    zones: [
      StudioZoneSpec(
        label: const StudioText('Club', 'Клуб'),
        rootPath: '/schedule',
        access: StudioZoneAccess.signedIn,
        screens: [
          _screen('/schedule', null, 'Schedule'),
          _screen('/schedule/profile', '/schedule', 'Profile'),
          _screen('/schedule/profile/services', '/schedule/profile', 'Services'),
        ],
      ),
      StudioZoneSpec(
        label: const StudioText('Auth', 'Авторизация'),
        rootPath: '/auth',
        access: StudioZoneAccess.signedOut,
        screens: [_screen('/auth', null, 'Sign in')],
      ),
    ],
  );
  final index = StudioManifestIndex(manifest);

  group('specForPath', () {
    test('exact match', () {
      expect(index.specForPath('/schedule/profile')!.title.en, 'Profile');
    });

    test('deepest non-root prefix for nested location', () {
      // No exact spec for the edit sub-route → deepest declared prefix wins.
      expect(index.specForPath('/schedule/profile/edit')!.path,
          '/schedule/profile');
    });

    test('unknown path with no root spec returns null', () {
      expect(index.specForPath('/nowhere'), isNull);
    });
  });

  group('zoneOf', () {
    test('finds the owning zone', () {
      final services = index.specForPath('/schedule/profile/services')!;
      expect(index.zoneOf(services).access, StudioZoneAccess.signedIn);
      final auth = index.specForPath('/auth')!;
      expect(index.zoneOf(auth).access, StudioZoneAccess.signedOut);
    });
  });

  group('crumbLabel', () {
    test('builds the parent chain but drops the zone root', () {
      final services = index.specForPath('/schedule/profile/services')!;
      expect(index.crumbLabel(services, StudioLanguage.en),
          'Profile › Services');
    });

    test('a direct child of the zone root keeps only its own title', () {
      final profile = index.specForPath('/schedule/profile')!;
      expect(index.crumbLabel(profile, StudioLanguage.en), 'Profile');
    });

    test('the zone root keeps its own title', () {
      final schedule = index.specForPath('/schedule')!;
      expect(index.crumbLabel(schedule, StudioLanguage.en), 'Schedule');
    });
  });
}
