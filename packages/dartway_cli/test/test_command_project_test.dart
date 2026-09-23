import 'dart:io';

import 'package:dartway_cli/src/commands/test_command.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late Directory root;

  setUp(() {
    root = Directory.systemTemp.createTempSync('dw_test_project');
    for (final package in ['shop_shared', 'shop_server', 'shop_flutter']) {
      File(p.join(root.path, package, 'pubspec.yaml'))
        ..createSync(recursive: true)
        ..writeAsStringSync('name: $package\n');
    }
  });

  tearDown(() => root.deleteSync(recursive: true));

  test('`dartway test` finds the project from the package that pins the CLI '
      '(#289)', () {
    for (final from in [
      root,
      Directory(p.join(root.path, 'shop_flutter')),
      Directory(p.join(root.path, 'shop_server')),
    ]) {
      final layout = TestCommand.projectOf(from);
      expect(
        p.canonicalize(layout.serverPackageDir.path),
        p.canonicalize(p.join(root.path, 'shop_server')),
        reason: from.path,
      );
    }
  });
}
