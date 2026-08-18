import 'package:dartway_studio_bridge/dartway_studio_bridge.dart';
import 'package:flutter_test/flutter_test.dart';

StudioScreenSpec _screen(String path, String? parent, String title) =>
    StudioScreenSpec(path: path, parentPath: parent, title: title, purpose: '');

void main() {
  final manifest = StudioProjectManifest(
    projectName: 'Demo',
    zones: [
      StudioZoneSpec(
        label: 'Club',
        rootPath: '/schedule',
        access: StudioZoneAccess.signedIn,
        screens: [
          _screen('/schedule', null, 'Schedule'),
          _screen('/schedule/profile', '/schedule', 'Profile'),
          _screen(
            '/schedule/profile/services',
            '/schedule/profile',
            'Services',
          ),
          _screen('/member/:memberId', '/schedule', 'Member'),
          _screen('/schedule/day/:date', '/schedule', 'Day'),
          _screen('/schedule/day/today', '/schedule', 'Today'),
        ],
      ),
      StudioZoneSpec(
        label: 'Auth',
        rootPath: '/auth',
        access: StudioZoneAccess.signedOut,
        screens: [_screen('/auth', null, 'Sign in')],
      ),
    ],
  );
  final index = StudioManifestIndex(manifest);

  group('specForPath', () {
    test('exact match', () {
      expect(index.specForPath('/schedule/profile')!.title, 'Profile');
    });

    test('deepest non-root prefix for nested location', () {
      // No exact spec for the edit sub-route → deepest declared prefix wins.
      expect(
        index.specForPath('/schedule/profile/edit')!.path,
        '/schedule/profile',
      );
    });

    test('unknown path with no root spec returns null', () {
      expect(index.specForPath('/nowhere'), isNull);
    });

    test('an address resolves to the template it is an instance of', () {
      // The manifest declares a template, the app reports an address. Without
      // this every parameterized screen resolves to nothing, and silently:
      // the caller gets null and substitutes something of its own.
      expect(index.specForPath('/member/7')!.title, 'Member');
      expect(index.specForPath('/schedule/day/2026-08-16')!.title, 'Day');
    });

    test('a literal screen wins over a template that also fits', () {
      // `/schedule/day/today` is a screen of its own, not a parameter value.
      expect(index.specForPath('/schedule/day/today')!.title, 'Today');
    });

    test('a template describes one screen, not the subtree under it', () {
      // `/member/:memberId` has one segment more than the first address and
      // one less than the second — it must be neither of them.
      expect(index.specForPath('/member'), isNull);
      expect(index.specForPath('/member/7/orders'), isNull);
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
      expect(index.crumbLabel(services), 'Profile › Services');
    });

    test('a direct child of the zone root keeps only its own title', () {
      final profile = index.specForPath('/schedule/profile')!;
      expect(index.crumbLabel(profile), 'Profile');
    });

    test('the zone root keeps its own title', () {
      final schedule = index.specForPath('/schedule')!;
      expect(index.crumbLabel(schedule), 'Schedule');
    });
  });
}
