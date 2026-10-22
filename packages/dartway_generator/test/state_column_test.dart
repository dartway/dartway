import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'support/temp_project.dart';

void main() {
  final fixture = p.join(
    frameworkPackages,
    'dartway_orm',
    'test',
    'fixtures',
    'state',
  );
  test(
    'state metadata survives generation and compiles at the ORM boundary',
    () async {
      final project = TempProject.create(['fixture_server']);
      project.writeFile(
        'fixture_server/lib/work_item.dart',
        File(p.join(fixture, 'work_item.dart')).readAsStringSync(),
      );
      await project.generateClean();
      expectReference(
        project.readFile('fixture_server/lib/work_item.dw.dart'),
        p.join(fixture, 'work_item.dw.dart'),
      );
      expect(await project.analyze('fixture_server'), isNull);
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );

  for (final declaration in ['String', 'WorkStatus?']) {
    test('refuses a $declaration state field', () async {
      final project = TempProject.create(['fixture_server']);
      final source = File(p.join(fixture, 'work_item.dart')).readAsStringSync();
      project.writeFile(
        'fixture_server/lib/work_item.dart',
        source.replaceAll(
          'final WorkStatus status;',
          'final $declaration status;',
        ),
      );
      final report = await project.generate();
      expect(
        report.diagnostics.map((d) => d.message).join('\n'),
        contains('non-null enum'),
      );
    });
  }
  for (final entry in <String, String>{
    'empty initial set': 'initial: {},',
    'state on the primary key':
        '@DwStateColumn(workTransitions)\n  final int id;',
  }.entries) {
    test('refuses ${entry.key}', () async {
      final project = TempProject.create(['fixture_server']);
      var source = File(p.join(fixture, 'work_item.dart')).readAsStringSync();
      source = entry.key == 'empty initial set'
          ? source.replaceAll('initial: {WorkStatus.open},', entry.value)
          : source.replaceAll('final int id;', entry.value);
      project.writeFile('fixture_server/lib/work_item.dart', source);
      final report = await project.generate();
      expect(
        report.diagnostics.map((d) => d.message).join('\n'),
        contains(
          entry.key == 'empty initial set' ? 'nonempty initial' : 'primary key',
        ),
      );
    });
  }
}
