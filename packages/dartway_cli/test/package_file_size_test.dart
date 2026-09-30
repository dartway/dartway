import 'dart:io';

import 'package:dartway_cli/src/checker/dw_check_tally.dart';
import 'package:dartway_cli/src/checker/dw_check_type.dart';
import 'package:dartway_cli/src/checker/dw_package_file_size.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// The server and the shared package are held to the Flutter package's file
/// length, and what is not written by hand, or is data, is passed over (#383).
void main() {
  late Directory sandbox;

  setUp(() {
    sandbox = Directory.systemTemp.createTempSync('dw_package_file_size');
  });

  tearDown(() {
    sandbox.deleteSync(recursive: true);
  });

  /// A file of [count] lines, as the checker counts them.
  String lines(int count) => List.filled(count, 'final x = 1;').join('\n');

  /// A seed data file of [count] lines: constants building drafts.
  String seed(int count) => [
    "import 'package:acme_server/src/catalog/catalog_rows.dart';",
    '',
    'const exerciseCatalogue = [',
    for (var i = 0; i < count - 5; i++) "  NewExerciseRow(slug: 's$i'),",
    '];',
  ].join('\n');

  DwPackageFileSizeInspector inspect(
    Map<String, String> files, {
    DwCheckType? filterType,
    DwCheckTally? tally,
  }) {
    for (final MapEntry(key: path, value: source) in files.entries) {
      File(p.join(sandbox.path, path))
        ..parent.createSync(recursive: true)
        ..writeAsStringSync(source);
    }
    final inspector = DwPackageFileSizeInspector(
      serverPackageDir: Directory(p.join(sandbox.path, 'acme_server')),
      sharedPackageDir: Directory(p.join(sandbox.path, 'acme_shared')),
      filterType: filterType,
    );
    expect(inspector.run(tally: tally), 0, reason: 'length fails nothing');
    return inspector;
  }

  test('the Flutter thresholds and severities, in both packages', () {
    final tally = DwCheckTally();
    final inspector = inspect({
      'acme_server/lib/src/chat/chat_handlers.dart': lines(351),
      'acme_server/lib/src/chat/chat_objects.dart': lines(201),
      'acme_server/lib/src/chat/chat_rows.dart': lines(200),
      'acme_shared/lib/src/issues.dart': lines(400),
      'acme_shared/lib/src/chat.dart': lines(250),
    }, tally: tally);
    expect(inspector.tooLongFindings, [
      contains('acme_server/lib/src/chat/chat_handlers.dart is 351 lines'),
      allOf(
        contains('acme_shared/lib/src/issues.dart is 400 lines'),
        contains('src/<feature>/<feature>_<part>.dart'),
      ),
    ]);
    expect(inspector.longFindings, [
      contains('chat_objects.dart is 201 lines'),
      contains('acme_shared/lib/src/chat.dart is 250 lines'),
    ]);
    expect(tally.counts, {DwCheckType.fileTooLong: 2, DwCheckType.fileLong: 2});
    expect(tally.errors, 0);
    expect(DwCheckType.fileTooLong.severity, DwCheckSeverity.warning);
    expect(DwCheckType.fileLong.severity, DwCheckSeverity.info);
  });

  test('generated code, migrations, seed data and tests are passed over', () {
    final inspector = inspect({
      'acme_server/lib/generated/dw_schema.dart': lines(900),
      'acme_server/lib/src/chat/chat_rows.dw.dart': lines(900),
      'acme_shared/lib/generated/dw_protocol.dart': lines(900),
      'acme_shared/lib/src/chat.dw.dart': lines(900),
      'acme_server/lib/src/migrations/m20260930_000000_initial.dart': lines(
        900,
      ),
      'acme_server/lib/src/catalog/catalog_exercises_rows.dart': seed(900),
      'acme_server/test/src/chat/chat_acceptance_test.dart': lines(900),
    });
    expect(inspector.tooLongFindings, isEmpty);
    expect(inspector.longFindings, isEmpty);
  });

  test('a seed file with anything but constants is measured', () {
    final withHandlers =
        '${seed(400)}\n'
        'final handlers = <DwCallHandler>[\n'
        '  DwCallHandler.list(handle: (ctx, r) => []),\n'
        '];';
    final withFunction =
        '${seed(400)}\n'
        'List<NewExerciseRow> more() {\n'
        '  return const [];\n'
        '}';
    final withFinal =
        '${seed(400)}\n'
        'final extra = [NewExerciseRow(slug: DateTime.now().toString())];';
    final inspector = inspect({
      'acme_server/lib/src/a/a_handlers.dart': withHandlers,
      'acme_server/lib/src/b/b_rows.dart': withFunction,
      'acme_server/lib/src/c/c_rows.dart': withFinal,
    });
    expect(inspector.tooLongFindings, hasLength(3));
  });

  test('seed data is recognised by what the file declares', () {
    expect(dwIsSeedDataFile(seed(20)), isTrue);
    expect(dwIsSeedDataFile('const limit = 3;'), isFalse, reason: 'no drafts');
    expect(
      dwIsSeedDataFile('${seed(20)}\nclass Helper {}'),
      isFalse,
      reason: 'a class',
    );
    expect(
      dwIsSeedDataFile('${seed(20)}\nconst pick = () => 1;'),
      isFalse,
      reason: 'a closure',
    );
  });

  test('another --type turns it off', () {
    final inspector = inspect({
      'acme_server/lib/src/chat/chat_handlers.dart': lines(400),
    }, filterType: DwCheckType.invalidSharedLayout);
    expect(inspector.tooLongFindings, isEmpty);
  });
}
