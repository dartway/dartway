import 'dart:io';

import 'package:dartway_cli/src/checker/dw_check_type.dart';
import 'package:dartway_cli/src/checker/dw_flutter_inspector.dart';
import 'package:dartway_cli/src/checker/dw_route_names.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// Route names are global in `DwAppRouter`; two zones naming a route alike
/// compile and fail on the first frame. The check reads the zones (#240).
void main() {
  String zone(String name, String values) =>
      '''
enum $name implements DwNavigationRoute<AppRouterState> {
$values

  const $name(this.descriptor);

  @override
  final DwNavigationRouteDescriptor<AppRouterState> descriptor;
}
''';

  group('reading a zone', () {
    test('names every value, whatever its descriptor holds', () {
      final routes = DwRouteNames.routesIn(
        'router.dart',
        zone('AppZone', '''
  // survey(...) in a comment is not a route
  home(DwNavigationRouteDescriptor.zoneRoot(pageWidget: HomePage())),
  @Deprecated('use profile')
  me(DwNavigationRouteDescriptor.simple(pageWidget: Page(title: 'a, b; {c}'), parent: home)),
  profile(
    DwNavigationRouteDescriptor.simple(pageWidget: ProfilePage(), parent: home),
  );'''),
      );
      expect(routes.map((r) => r.route), ['home', 'me', 'profile']);
      expect(routes.map((r) => r.zone).toSet(), {'AppZone'});
    });

    test('an enum that is not a zone is not read', () {
      expect(
        DwRouteNames.routesIn('x.dart', 'enum UserRole { admin, member }'),
        isEmpty,
      );
    });
  });

  group('dartway check', () {
    late Directory sandbox;

    setUp(() {
      sandbox = Directory.systemTemp.createTempSync('dw_route_names');
      File(p.join(sandbox.path, 'pubspec.yaml'))
        ..createSync(recursive: true)
        ..writeAsStringSync('name: sandbox_flutter\n');
    });
    tearDown(() => sandbox.deleteSync(recursive: true));

    Future<DwFlutterInspector> inspect(Map<String, String> files) async {
      for (final MapEntry(key: path, value: content) in files.entries) {
        File(p.join(sandbox.path, 'lib', path))
          ..createSync(recursive: true)
          ..writeAsStringSync(content);
      }
      final inspector = DwFlutterInspector(packageDir: sandbox);
      await inspector.run();
      return inspector;
    }

    test('fails on one name in two zones, naming both declarations', () async {
      final inspector = await inspect({
        'core/router/app_zone.dart': zone(
          'AppZone',
          '  home(x),\n  survey(y);',
        ),
        'core/router/admin_zone.dart': zone(
          'AdminZone',
          '  admin(x),\n  survey(y);',
        ),
      });
      expect(inspector.findingTypes, contains(DwCheckType.routeNameDuplicated));
      expect(
        inspector.findingMessages.join('\n'),
        allOf(contains('AppZone.survey'), contains('AdminZone.survey')),
      );
    });

    test('distinct names pass', () async {
      final inspector = await inspect({
        'core/router/app_zone.dart': zone(
          'AppZone',
          '  home(x),\n  survey(y);',
        ),
        'core/router/admin_zone.dart': zone(
          'AdminZone',
          '  admin(x),\n  surveyEditor(y);',
        ),
      });
      expect(
        inspector.findingTypes,
        isNot(contains(DwCheckType.routeNameDuplicated)),
      );
    });
  });
}
