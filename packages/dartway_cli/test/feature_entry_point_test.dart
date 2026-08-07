import 'dart:io';

import 'package:dartway_cli/src/checker/dw_check_type.dart';
import 'package:dartway_cli/src/checker/dw_flutter_inspector.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// What a zone folder's entry point has to be.
///
/// Both findings here were written after a real project ran clean while
/// breaking the rule in ten places. The old widget test matched a list of base
/// class names, so `ConsumerStatefulWidget` — every form and dialog — was
/// invisible; and a folder that declared no widget at all passed *because* it
/// was not a widget. Each gap hid the other.
void main() {
  late Directory sandbox;

  setUp(() {
    sandbox = Directory.systemTemp.createTempSync('dw_feature_entry');
  });

  tearDown(() {
    sandbox.deleteSync(recursive: true);
  });

  /// Writes a one-feature app zone and returns the findings for it.
  Future<Set<DwCheckType>> checkZoneFeature(String entryPointSource) async {
    File(p.join(sandbox.path, 'pubspec.yaml'))
      ..createSync(recursive: true)
      ..writeAsStringSync('name: sandbox_flutter\n');

    File(p.join(sandbox.path, 'lib', 'app', 'thing', 'thing.dart'))
      ..createSync(recursive: true)
      ..writeAsStringSync(entryPointSource);

    final inspector = DwFlutterInspector(packageDir: sandbox);
    await inspector.run();
    return inspector.findingTypes;
  }

  group('a feature declares a widget, and the widget declares a spec', () {
    test('a widget with a spec is what the rule wants', () async {
      final findings = await checkZoneFeature('''
class ThingPage extends StatelessWidget implements DwFeature {
  DwFeatureSpec get dwFeature => const DwFeatureSpec(id: 'thing');
}
''');

      expect(findings, isNot(contains(DwCheckType.notAFeature)));
      expect(findings, isNot(contains(DwCheckType.featureSpecMissing)));
    });

    test('a widget without a spec is asked for one', () async {
      final findings = await checkZoneFeature('''
class ThingPage extends StatelessWidget {}
''');

      expect(findings, contains(DwCheckType.featureSpecMissing));
    });
  });

  group('the base class is a shape, not a list of remembered names', () {
    // The regression this file exists for. `ConsumerStatefulWidget` is what a
    // feature with a controller or a text field extends, so the check was blind
    // exactly where a passport says the most.
    for (final baseClass in [
      'StatelessWidget',
      'StatefulWidget',
      'ConsumerWidget',
      'ConsumerStatefulWidget',
      'HookConsumerWidget',
      'HookWidget',
    ]) {
      test('$baseClass without a spec is caught', () async {
        final findings = await checkZoneFeature('''
class ThingPage extends $baseClass {}
''');

        expect(
          findings,
          contains(DwCheckType.featureSpecMissing),
          reason: '$baseClass has to read as a widget',
        );
        expect(findings, isNot(contains(DwCheckType.notAFeature)));
      });
    }
  });

  group('a zone folder that declares no widget is not a feature', () {
    test('a bare provider is reported', () async {
      final findings = await checkZoneFeature('''
final thingProvider = Provider<bool>((ref) => false);
''');

      expect(findings, contains(DwCheckType.notAFeature));
      // Not both: a folder that is not a feature is not asked for a passport.
      expect(findings, isNot(contains(DwCheckType.featureSpecMissing)));
    });

    test('an extension is reported', () async {
      final findings = await checkZoneFeature('''
extension ThingLabel on Thing {
  String get label => 'thing';
}
''');

      expect(findings, contains(DwCheckType.notAFeature));
    });

    test('a private widget does not make the folder a feature', () async {
      // Only a public class counts: a file whose sole widget is private has no
      // entry point for anyone to import.
      final findings = await checkZoneFeature('''
final thingProvider = Provider<bool>((ref) => false);

class _ThingView extends StatelessWidget {}
''');

      expect(findings, contains(DwCheckType.notAFeature));
    });
  });
}
