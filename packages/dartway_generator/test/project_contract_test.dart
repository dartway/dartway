import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'support/temp_project.dart';

void main() {
  test(
    'regeneration cannot hide a required field at the same contract line',
    () async {
      final project = TempProject.create(['app_shared']);
      project.writeFile('app_shared/lib/src/item.dart', itemSource());
      await project.generateClean();
      git(project, ['init', '-b', 'main']);
      git(project, ['add', 'app_shared']);
      git(project, [
        '-c',
        'user.name=Fixture',
        '-c',
        'user.email=fixture@example.test',
        'commit',
        '-m',
        'baseline',
      ]);
      git(project, ['checkout', '-b', 'feature']);
      project.writeFile(
        'app_shared/lib/src/item.dart',
        itemSource(requiredTitle: true),
      );
      await project.generateClean();
      project.writeFile('app_shared/bin/probe.dart', r'''
import '../lib/src/item.dart';
void main() {
  try { $ItemRecordFromJson({'id': 1}); } catch (_) { print('required field rejects installed client JSON'); return; }
  throw StateError('accepted missing required field');
}
''');
      final codec = await project.runScript('app_shared', 'bin/probe.dart');
      expect(codec.exitCode, 0, reason: '${codec.stderr}');
      expect(codec.stdout, contains('rejects installed client JSON'));
      final result = await generatorCli(project, ['--check']);
      expect(result.exitCode, 3, reason: '${result.stdout}${result.stderr}');
      expect(
        '${result.stdout}${result.stderr}',
        contains('project contract incompatible'),
      );
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}

String itemSource({bool requiredTitle = false}) =>
    '''
import 'package:dartway_core_shared/dartway_core_shared.dart';
part 'item.dw.dart';
final class ItemRecord extends DwDataObject with _\$ItemRecord {
  const ItemRecord({required this.id, ${requiredTitle ? 'required this.title' : ''}});
  @override
  final int id;
  ${requiredTitle ? 'final String title;' : ''}
}
''';

String git(TempProject project, List<String> arguments) {
  final result = Process.runSync(
    'git',
    arguments,
    workingDirectory: project.root,
  );
  expect(result.exitCode, 0, reason: '${result.stdout}${result.stderr}');
  return '${result.stdout}'.trim();
}

Future<ProcessResult> generatorCli(
  TempProject project,
  List<String> arguments,
) => Process.run(dartExecutable, [
  '--packages=${p.join(generatorRoot, '.dart_tool/package_config.json')}',
  p.join(generatorRoot, 'bin/dartway_generator.dart'),
  '--project',
  project.root,
  ...arguments,
], workingDirectory: project.root);
