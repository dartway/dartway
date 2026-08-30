import 'dart:io';

import 'package:dartway_cli/src/checker/dw_l10n_wiring.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// The law says every project is localized. Nothing checked it, and the gap is
/// the quiet kind: an app with none of the wiring compiles, passes its tests
/// and looks finished — around 450 strings written straight into 150 widget
/// files in the case that produced this rule, with nobody having broken
/// anything, because the rule described a starting state that never arrived.
void main() {
  late Directory sandbox;

  setUp(() => sandbox = Directory.systemTemp.createTempSync('dw_l10n'));
  tearDown(() => sandbox.deleteSync(recursive: true));

  var packageCount = 0;

  /// A Flutter package with the pieces named in [with_] present.
  ///
  /// A fresh directory each time, deliberately: reusing one leaves the previous
  /// call's `l10n.yaml` on disk, and the rule then reads a package nobody
  /// described — which is how this helper first reported a pass for a package
  /// missing the very file it was asked to omit.
  Directory packageWith(Set<String> with_) {
    final dir = Directory(p.join(sandbox.path, 'app${packageCount++}'))
      ..createSync();
    Directory(p.join(dir.path, 'lib')).createSync();

    File(p.join(dir.path, 'pubspec.yaml')).writeAsStringSync(
      [
        'name: app',
        'dependencies:',
        '  flutter:',
        '    sdk: flutter',
        if (with_.contains('dependency')) '  flutter_localizations:',
        if (with_.contains('dependency')) '    sdk: flutter',
        'flutter:',
        if (with_.contains('generate')) '  generate: true',
        '  uses-material-design: true',
      ].join('\n'),
    );

    if (with_.contains('l10n.yaml')) {
      File(
        p.join(dir.path, 'l10n.yaml'),
      ).writeAsStringSync('arb-dir: lib/l10n\n');
    }
    if (with_.contains('arb')) {
      Directory(p.join(dir.path, 'lib', 'l10n')).createSync(recursive: true);
      File(
        p.join(dir.path, 'lib', 'l10n', 'app_en.arb'),
      ).writeAsStringSync('{"@@locale": "en"}');
    }
    return dir;
  }

  const everything = {'dependency', 'generate', 'l10n.yaml', 'arb'};

  test('a wired package has nothing to say', () {
    expect(
      DwL10nWiringInspector.missingPieces(packageWith(everything)),
      isEmpty,
    );
  });

  test('an app with none of it names all four', () {
    // The case the rule exists for: a project that reached the methodology by
    // another road and never had the wiring to lose.
    expect(
      DwL10nWiringInspector.missingPieces(packageWith(const {})),
      hasLength(4),
    );
  });

  test('each missing piece is named on its own', () {
    for (final piece in everything) {
      final missing = DwL10nWiringInspector.missingPieces(
        packageWith(everything.difference({piece})),
      );

      // The half-wired state is the one that produces the strangest errors, so
      // the finding has to say which piece rather than "not wired".
      expect(missing, hasLength(1), reason: piece);
    }
  });

  test('the named piece is actionable, not a diagnosis', () {
    final missing = DwL10nWiringInspector.missingPieces(
      packageWith(everything.difference({'generate'})),
    );

    expect(missing.single, contains('generate: true'));
    expect(missing.single, contains('gen-l10n'));
  });

  test('a package with no pubspec is not this rule\'s business', () {
    final dir = Directory(p.join(sandbox.path, 'empty'))..createSync();
    expect(DwL10nWiringInspector.missingPieces(dir), isEmpty);
  });

  test('the skeleton passes its own rule', () {
    // The rule and the thing it judges ship together; if the skeleton fails it,
    // every new project starts red and the check teaches itself to be ignored.
    var dir = Directory.current.absolute;
    while (!Directory(
      p.join(dir.path, 'template', 'dartway_starter_flutter'),
    ).existsSync()) {
      dir = dir.parent;
    }

    expect(
      DwL10nWiringInspector.missingPieces(
        Directory(p.join(dir.path, 'template', 'dartway_starter_flutter')),
      ),
      isEmpty,
    );
  });
}
