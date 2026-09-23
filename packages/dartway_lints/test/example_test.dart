import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// The plugin, loaded by a real analysis server over real Flutter code.
///
/// The rule tests prove the matching on stand-ins; this proves the rest — that
/// the server loads `lib/main.dart`, that `BuildContext` is Flutter's, that a
/// rule's diagnostics reach `dart analyze`. `example/` marks every diagnostic
/// it must produce with `// expect_lint: <rule>` on the line above, and the
/// analyzer has to produce exactly those: a missing one is a rule that stopped
/// matching, an extra one a rule that matches too much.
void main() {
  final example = p.join(Directory.current.path, 'example');

  test('dart analyze reports exactly what example/ marks', () async {
    final rules = {
      'deep_relative_import',
      'forbidden_provider_scope',
      'forbidden_ui_style_usage',
    };

    final expected = <String>{};
    for (final file in Directory(example)
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'))
        .where((file) => !file.path.contains('.dart_tool'))) {
      final lines = file.readAsLinesSync();
      for (var index = 0; index < lines.length; index++) {
        final marker = RegExp(
          r'^\s*// expect_lint: (\w+)\s*$',
        ).firstMatch(lines[index]);
        if (marker != null) {
          expected.add(
            '${p.relative(file.path, from: example)}:${index + 2}: '
            '${marker[1]}',
          );
        }
      }
    }
    expect(expected, isNotEmpty, reason: 'the fixture marks nothing');

    final result = await Process.run('dart', [
      'analyze',
      '--format=machine',
    ], workingDirectory: example);
    // SEVERITY|TYPE|CODE|FILE|LINE|COLUMN|LENGTH|MESSAGE
    final reported = <String>{
      for (final line in '${result.stdout}\n${result.stderr}'.split('\n'))
        if (line.split('|') case [
          _,
          _,
          final code,
          final file,
          final lineNumber,
          ...,
        ] when rules.contains(code.toLowerCase()))
          '${p.relative(file, from: example)}:$lineNumber: '
              '${code.toLowerCase()}',
    };
    expect(
      reported,
      expected,
      reason: 'analyzer output:\n${result.stdout}${result.stderr}',
    );
  });
}
