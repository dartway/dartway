import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:dartway_cli/src/commands/sync_command.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late Directory root;
  late List<String> regenerated;

  String git(List<String> args) {
    final result = Process.runSync('git', args, workingDirectory: root.path);
    if (result.exitCode != 0) {
      fail('git ${args.join(' ')}: ${result.stderr}');
    }
    return result.stdout as String;
  }

  void write(String path, String contents) {
    File(p.join(root.path, path))
      ..createSync(recursive: true)
      ..writeAsStringSync(contents);
  }

  String read(String path) => File(p.join(root.path, path)).readAsStringSync();

  String migration(String id, String name) =>
      '''
// dart format off
class $name extends DwDatabaseMigration {
  const $name();
  @override
  String get id => '$id';
}
''';

  String registry(List<(String, String)> migrations) {
    final buffer = StringBuffer()
      ..writeln(
        '// Maintained by `migrate create`: one entry per migration file in this',
      )
      ..writeln('// directory, in id order.')
      ..writeln(
        "import 'package:dartway_core_server/dartway_core_server.dart';",
      )
      ..writeln();
    for (final (id, _) in migrations) {
      buffer.writeln("import 'package:app_server/src/migrations/m$id.dart';");
    }
    buffer
      ..writeln()
      ..writeln('final List<DwDatabaseMigration> appMigrations = [');
    for (final (_, name) in migrations) {
      buffer.writeln('  const $name(),');
    }
    buffer.writeln('];');
    return buffer.toString();
  }

  String arb(Map<String, Object> entries) =>
      '${const JsonEncoder.withIndent('  ').convert(entries)}\n';

  const migrations = 'app_server/lib/src/migrations';

  Future<int> sync([List<String> args = const []]) async {
    final runner = CommandRunner<int>('dartway', '')
      ..addCommand(
        SyncCommand(
          regenerate: (project) async {
            regenerated.add(project);
            return 0;
          },
        ),
      );
    final previous = Directory.current;
    Directory.current = root;
    try {
      return (await runner.run(['sync', ...args]))!;
    } finally {
      Directory.current = previous;
    }
  }

  setUp(() {
    root = Directory.systemTemp.createTempSync('dw_sync_');
    regenerated = [];
    git(['init', '-q', '-b', 'develop']);
    git(['config', 'user.email', 'test@example.com']);
    git(['config', 'user.name', 'Test']);
    write('app_shared/pubspec.yaml', 'name: app_shared\n');
    write('app_server/pubspec.yaml', 'name: app_server\n');
    write('app_shared/lib/generated/dw_protocol.dart', '// base\n');
    write('app_server/pubspec.lock', '# base\n');
    write('app_shared/lib/src/item.dart', 'class Item {}\n');
    write(
      '$migrations/m20261001_000000_initial.dart',
      migration('20261001_000000_initial', 'M20261001000000Initial'),
    );
    write(
      '$migrations/migrations.dart',
      registry([('20261001_000000_initial', 'M20261001000000Initial')]),
    );
    write(
      'app_flutter/lib/l10n/app_en.arb',
      arb({
        'title': 'Studio',
        '@title': {'description': 'Title.'},
      }),
    );
    git(['add', '-A']);
    git(['commit', '-qm', 'base']);
    git(['branch', 'task']);

    // Another task merged into develop first.
    write('app_shared/lib/generated/dw_protocol.dart', '// develop\n');
    write('app_server/pubspec.lock', '# develop\n');
    write(
      '$migrations/m20261003_000000_develop.dart',
      migration('20261003_000000_develop', 'M20261003000000Develop'),
    );
    write(
      '$migrations/migrations.dart',
      registry([
        ('20261001_000000_initial', 'M20261001000000Initial'),
        ('20261003_000000_develop', 'M20261003000000Develop'),
      ]),
    );
    write(
      'app_flutter/lib/l10n/app_en.arb',
      arb({
        'title': 'Studio',
        '@title': {'description': 'Title.'},
        'leave': 'Leave',
      }),
    );
    git(['add', '-A']);
    git(['commit', '-qm', 'develop']);

    // This task, written against the base.
    git(['checkout', '-q', 'task']);
    write('app_shared/lib/generated/dw_protocol.dart', '// task\n');
    write('app_server/pubspec.lock', '# task\n');
    write(
      '$migrations/m20261002_000000_task.dart',
      migration('20261002_000000_task', 'M20261002000000Task'),
    );
    write(
      '$migrations/migrations.dart',
      registry([
        ('20261001_000000_initial', 'M20261001000000Initial'),
        ('20261002_000000_task', 'M20261002000000Task'),
      ]),
    );
    write(
      'app_flutter/lib/l10n/app_en.arb',
      arb({
        'title': 'Studio',
        '@title': {'description': 'Title.'},
        'join': 'Join',
      }),
    );
  });

  tearDown(() => root.deleteSync(recursive: true));

  test('derived conflicts resolve themselves and the merge commits', () async {
    git(['add', '-A']);
    git(['commit', '-qm', 'task']);

    expect(await sync(['develop']), 0);

    expect(git(['status', '--porcelain']), isEmpty);
    expect(git(['log', '-1', '--format=%P']).trim().split(' '), hasLength(2));
    expect(regenerated, hasLength(1));
    expect(
      read('$migrations/migrations.dart'),
      registry([
        ('20261001_000000_initial', 'M20261001000000Initial'),
        ('20261002_000000_task', 'M20261002000000Task'),
        ('20261003_000000_develop', 'M20261003000000Develop'),
      ]),
    );
    expect(jsonDecode(read('app_flutter/lib/l10n/app_en.arb')), {
      'title': 'Studio',
      '@title': {'description': 'Title.'},
      'join': 'Join',
      'leave': 'Leave',
    });
    expect(read('app_shared/lib/generated/dw_protocol.dart'), '// develop\n');
  });

  test('a conflict in a source stops for the author, then continues', () async {
    write('app_shared/lib/src/item.dart', 'class Item { int task = 0; }\n');
    git(['add', '-A']);
    git(['commit', '-qm', 'task']);
    git(['checkout', '-q', 'develop']);
    write('app_shared/lib/src/item.dart', 'class Item { int develop = 0; }\n');
    git(['commit', '-qam', 'develop item']);
    git(['checkout', '-q', 'task']);

    expect(await sync(['develop']), 1);
    expect(regenerated, isEmpty);
    expect(
      git(['diff', '--name-only', '--diff-filter=U']).trim(),
      'app_shared/lib/src/item.dart',
    );

    write('app_shared/lib/src/item.dart', 'class Item { int both = 0; }\n');
    git(['add', 'app_shared/lib/src/item.dart']);
    expect(await sync(['--continue']), 0);
    expect(git(['status', '--porcelain']), isEmpty);
    expect(
      read('$migrations/migrations.dart'),
      contains('M20261003000000Develop'),
    );
  });

  test(
    'a translation both sides changed differently stays a conflict',
    () async {
      write(
        'app_flutter/lib/l10n/app_en.arb',
        arb({
          'title': 'Task',
          '@title': {'description': 'Title.'},
        }),
      );
      git(['add', '-A']);
      git(['commit', '-qm', 'task']);
      git(['checkout', '-q', 'develop']);
      write(
        'app_flutter/lib/l10n/app_en.arb',
        arb({
          'title': 'Develop',
          '@title': {'description': 'Title.'},
        }),
      );
      git(['commit', '-qam', 'develop title']);
      git(['checkout', '-q', 'task']);

      expect(await sync(['develop']), 1);
      expect(
        git(['diff', '--name-only', '--diff-filter=U']).trim(),
        'app_flutter/lib/l10n/app_en.arb',
      );
    },
  );

  test('refuses to merge into a tree with uncommitted changes', () async {
    expect(await sync(['develop']), 1);
    expect(regenerated, isEmpty);
  });
}
