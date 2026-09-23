import 'dart:io';

import 'package:dartway_cli/src/checker/dw_check_tally.dart';
import 'package:dartway_cli/src/checker/dw_check_type.dart';
import 'package:dartway_cli/src/checker/dw_flutter_inspector.dart';
import 'package:dartway_cli/src/checker/dw_layout.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// `By check` counts every section's findings, and adds up to the verdict.
///
/// A layout error was printed in its own section, counted in `Errors: 4`, and
/// missing from the tally, which named three — the summary a reader copied
/// into a ticket (#287).
void main() {
  late Directory sandbox;

  setUp(() => sandbox = Directory.systemTemp.createTempSync('dw_check_tally'));
  tearDown(() => sandbox.deleteSync(recursive: true));

  test('a layout finding is in the tally, and the tally sums to the '
      'errors counted', () async {
    final package = Directory(p.join(sandbox.path, 'shop_flutter'));
    for (final (path, content) in [
      ('pubspec.yaml', 'name: shop_flutter\n'),
      ('lib/main.dart', 'void main() {}\n'),
      ('lib/shop_app.dart', 'class ShopApp {}\n'),
      // Neither of the two files allowed at the root of lib/.
      ('lib/app_version.dart', "const appVersion = '1.0.0';\n"),
    ]) {
      File(p.join(package.path, path))
        ..createSync(recursive: true)
        ..writeAsStringSync(content);
    }

    final tally = DwCheckTally();
    final errors =
        DwLayoutInspector(flutterPackageDir: package).run(tally: tally) +
        await DwFlutterInspector(packageDir: package).run(tally: tally);

    expect(tally.counts[DwCheckType.invalidTopLevelLayout], 1);
    expect(tally.errors, errors);
    expect(
      tally.summary,
      contains('• [ERROR] invalidTopLevelLayout — 1'),
    );
  });
}
