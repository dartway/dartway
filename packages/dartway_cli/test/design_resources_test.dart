import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:dartway_cli/src/checker/dw_check_type.dart';
import 'package:dartway_cli/src/checker/dw_flutter_inspector.dart';
import 'package:dartway_cli/src/commands/check_command.dart';
import 'package:dartway_cli/src/design_resources.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

// Risks 4/5: the checker must accept the symlink asset contract and reject
// copies that silently drift from Studio. No compiler checks either rule.
void main() {
  late Directory root;
  late Directory app;

  void write(String path, String text) {
    File(p.join(root.path, path))
      ..createSync(recursive: true)
      ..writeAsStringSync(text);
  }

  setUp(() {
    root = Directory.systemTemp.createTempSync('dw_design_');
    app = Directory(p.join(root.path, 'sample_flutter'))..createSync();
    write('.dartway/design.json', '{}');
    write('dw_studio/ui_kit/resources/brand.svg', '<svg>brand</svg>');
    write('sample_flutter/pubspec.yaml', '''
name: sample_flutter
flutter:
  assets:
    - dw_studio/ui_kit/resources/
''');
    write('sample_flutter/lib/ui_kit/assets/app_icon.dart', '''
part of '../../ui_kit.dart';
enum AppIcon { brand('dw_studio/ui_kit/resources/brand.svg'); }
''');
    Link(p.join(app.path, 'dw_studio')).createSync('../dw_studio');
  });

  tearDown(() => root.deleteSync(recursive: true));

  Future<DwFlutterInspector> inspect([String? type]) async {
    final inspector = DwFlutterInspector(
      packageDir: app,
      filterType: type == null
          ? null
          : DwCheckType.values.singleWhere((t) => t.name == type),
    );
    await inspector.run();
    return inspector;
  }

  test('linked design and app-owned dictionary entries pass', () async {
    write('sample_flutter/assets/local.svg', '<svg>local</svg>');
    write('sample_flutter/lib/ui_kit/assets/app_icon.dart', '''
part of '../../ui_kit.dart';
enum AppIcon {
  brand('dw_studio/ui_kit/resources/brand.svg'),
  local('assets/local.svg');
}
''');
    final result = await inspect();
    expect(result.findingTypes, isEmpty);
  });

  test('a copied resource fails and names the design key', () async {
    write('sample_flutter/assets/quiz/renamed.svg', '<svg>brand</svg>');
    final result = await inspect();
    expect(
      result.findingTypes.map((t) => t.name),
      contains('designResourceCopied'),
    );
    expect(
      result.findingMessages.join('\n'),
      contains('assets/quiz/renamed.svg'),
    );
    expect(
      result.findingMessages.join('\n'),
      contains('dw_studio/ui_kit/resources/brand.svg'),
    );
    final previous = Directory.current;
    Directory.current = app;
    try {
      final runner = CommandRunner<int>('dartway', 'test')
        ..addCommand(CheckCommand());
      expect(await runner.run(['check', '--type', 'designResourceCopied']), 1);
    } finally {
      Directory.current = previous;
    }
  });

  test('missing linked asset is reported with either quote style', () async {
    write('sample_flutter/lib/ui_kit/assets/app_icon.dart', '''
part of '../../ui_kit.dart';
enum AppIcon { brand("dw_studio/ui_kit/resources/missing.svg"); }
''');
    final result = await inspect();
    expect(result.findingTypes, contains(DwCheckType.assetPathMissing));
  });

  test('a design path in a feature is forbidden', () async {
    write('sample_flutter/lib/shared/picture.dart', '''
const picture = 'dw_studio/ui_kit/resources/brand.svg';
''');
    final result = await inspect();
    expect(result.findingTypes, contains(DwCheckType.forbiddenAssetPath));
  });

  test('dictionary reference requires the pubspec resources folder', () async {
    write('sample_flutter/pubspec.yaml', 'name: sample_flutter\n');
    final result = await inspect();
    expect(
      result.findingTypes.map((t) => t.name),
      contains('designResourcesInvalid'),
    );
    expect(result.findingMessages.join('\n'), contains('pubspec.yaml'));
  });

  for (final state in ['absent', 'directory', 'wrong target', 'dangling']) {
    test('$state design link fails', () async {
      Link(p.join(app.path, 'dw_studio')).deleteSync();
      if (state == 'directory') {
        Directory(p.join(app.path, 'dw_studio')).createSync();
      } else if (state != 'absent') {
        Directory(p.join(root.path, 'other')).createSync();
        Link(
          p.join(app.path, 'dw_studio'),
        ).createSync(state == 'dangling' ? '../missing' : '../other');
      }
      final result = await inspect();
      expect(
        result.findingTypes.map((t) => t.name),
        contains('designResourcesInvalid'),
      );
    });
  }

  for (final config in ['{', '[]', '{"path":"../outside"}', '{"path":42}']) {
    test('invalid config $config is diagnosed', () async {
      write('.dartway/design.json', config);
      final result = await inspect();
      expect(
        result.findingTypes.map((t) => t.name),
        contains('designResourcesInvalid'),
      );
    });
  }

  test('nested configured source uses its basename as the link', () async {
    write('.dartway/design.json', '{"path":"design/published"}');
    write('design/published/ui_kit/resources/x.svg', '<svg>x</svg>');
    Link(p.join(app.path, 'published')).createSync('../design/published');
    write('sample_flutter/pubspec.yaml', '''
name: sample_flutter
flutter:
  assets:
    - published/ui_kit/resources/
''');
    write('sample_flutter/lib/ui_kit/assets/app_icon.dart', '''
part of '../../ui_kit.dart';
enum AppIcon { x('published/ui_kit/resources/x.svg'); }
''');
    expect((await inspect()).findingTypes, isEmpty);
  });

  test('no config leaves the new rules off', () async {
    File(p.join(root.path, '.dartway/design.json')).deleteSync();
    Link(p.join(app.path, 'dw_studio')).deleteSync();
    write('sample_flutter/assets/copy.svg', '<svg>brand</svg>');
    final result = await inspect();
    expect(result.findingTypes, isEmpty);
  });

  test(
    '--fix creates the link and wires the template Docker context once',
    () async {
      Link(p.join(app.path, 'dw_studio')).deleteSync();
      write('sample_flutter/Dockerfile', '''
FROM scratch
WORKDIR /workspace
COPY sample_flutter/ sample_flutter/
WORKDIR /workspace/sample_flutter
''');
      write('.dockerignore', '**\n!*_flutter/\n!*_flutter/**\n**/*.log\n');
      final broken = await inspect();
      expect(broken.findingTypes, contains(DwCheckType.designResourcesInvalid));
      final previous = Directory.current;
      Directory.current = app;
      try {
        final runner = CommandRunner<int>('dartway', 'test')
          ..addCommand(CheckCommand());
        expect(
          await runner.run([
            'check',
            '--type',
            'designResourcesInvalid',
            '--fix',
          ]),
          0,
        );
        final dockerfile = File(p.join(app.path, 'Dockerfile'));
        final ignore = File(p.join(root.path, '.dockerignore'));
        final first = (
          dockerfile.readAsStringSync(),
          ignore.readAsStringSync(),
        );
        expect(
          await runner.run([
            'check',
            '--type',
            'designResourcesInvalid',
            '--fix',
          ]),
          0,
        );
        expect((
          dockerfile.readAsStringSync(),
          ignore.readAsStringSync(),
        ), first);
        expect(
          Link(p.join(app.path, 'dw_studio')).targetSync(),
          '../dw_studio',
        );
        expect(
          await File(
            p.join(app.path, 'dw_studio/ui_kit/resources/brand.svg'),
          ).readAsString(),
          '<svg>brand</svg>',
        );
      } finally {
        Directory.current = previous;
      }
    },
  );

  test('--fix preserves an existing directory or wrong symlink', () {
    final design = DwDesignResources.read(app)!;
    Link(p.join(app.path, 'dw_studio')).deleteSync();
    Directory(p.join(app.path, 'dw_studio')).createSync();
    expect(design.createLink(), isNull);
    expect(Directory(p.join(app.path, 'dw_studio')).existsSync(), isTrue);
    Directory(p.join(app.path, 'dw_studio')).deleteSync();
    Link(p.join(app.path, 'dw_studio')).createSync('../missing');
    expect(design.createLink(), isNull);
    expect(Link(p.join(app.path, 'dw_studio')).targetSync(), '../missing');
  });

  for (final copy in [
    'COPY dw_studio/ui_kit/resources/ /wrong/',
    'COPY dw_studio/elsewhere/ dw_studio/elsewhere/',
    'COPY --from=other /dw_studio/ /workspace/dw_studio/',
  ]) {
    test('Docker must copy the resources to the link target: $copy', () async {
      write(
        'sample_flutter/Dockerfile',
        'FROM scratch\nWORKDIR /workspace\n$copy\n',
      );
      final result = await inspect('designResourcesInvalid');
      expect(
        result.findingMessages.join('\n'),
        contains('Dockerfile must copy'),
      );
    });
  }

  test('an ignored nested resource is diagnosed', () async {
    write(
      'sample_flutter/Dockerfile',
      'FROM scratch\nWORKDIR /workspace\nCOPY dw_studio/ dw_studio/\n',
    );
    write(
      '.dockerignore',
      '**\n!dw_studio/\n!dw_studio/**\ndw_studio/ui_kit/resources/*.svg\n',
    );
    final result = await inspect('designResourcesInvalid');
    expect(
      result.findingMessages.join('\n'),
      contains('.dockerignore excludes dw_studio/ui_kit/resources/brand.svg'),
    );
  });

  test('a copy after the Flutter build cannot satisfy its inputs', () async {
    write('sample_flutter/Dockerfile', '''
FROM scratch AS build
WORKDIR /workspace
COPY sample_flutter/ sample_flutter/
RUN flutter build web --release
FROM scratch
COPY dw_studio/ /workspace/dw_studio/
''');
    final result = await inspect('designResourcesInvalid');
    expect(result.findingMessages.join('\n'), contains('Dockerfile must copy'));
  });

  test('a custom build workspace resolves the same relative link', () async {
    write('sample_flutter/Dockerfile', '''
FROM scratch AS build
WORKDIR /app
COPY ["dw_studio/ui_kit/resources/", "dw_studio/ui_kit/resources/"]
COPY sample_flutter/ sample_flutter/
WORKDIR /app/sample_flutter
RUN flutter build web --release
''');
    expect((await inspect('designResourcesInvalid')).findingTypes, isEmpty);
  });

  test('Docker receives the resource at the relative symlink target', () async {
    write('sample_flutter/Dockerfile', '''
FROM scratch
WORKDIR /workspace
COPY sample_flutter/ sample_flutter/
WORKDIR /workspace/sample_flutter
''');
    write('.dockerignore', '**\n!*_flutter/\n!*_flutter/**\n');
    final design = DwDesignResources.read(app)!;
    design.prepareDocker();
    final output = Directory.systemTemp.createTempSync('dw_design_image_');
    addTearDown(() => output.deleteSync(recursive: true));
    final result = await Process.run('docker', [
      'build',
      '-f',
      p.join(app.path, 'Dockerfile'),
      '--output',
      'type=local,dest=${output.path}',
      root.path,
    ]);
    expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
    expect(
      File(
        p.join(
          output.path,
          'workspace/sample_flutter/dw_studio/ui_kit/resources/brand.svg',
        ),
      ).readAsStringSync(),
      '<svg>brand</svg>',
    );
  }, tags: ['docker']);
}
