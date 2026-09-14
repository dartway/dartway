import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// `dartway create` over this repository's own template: what a stranger's
/// project is named after, and what it resolves against.
///
/// Whether the result builds, tests and runs is a question for a real
/// toolchain and is answered outside this suite; this one holds the renames
/// and the pubspecs, which are the part `create` itself writes.
///
/// The CLI runs as a process of its own, in a folder of its own: `create`
/// works in the current directory, and the current directory of this process
/// is shared by every suite running beside this one.
void main() {
  final repository = () {
    var dir = Directory.current.absolute;
    while (!Directory(p.join(dir.path, 'template')).existsSync() ||
        !Directory(p.join(dir.path, 'packages')).existsSync()) {
      final up = dir.parent;
      if (up.path == dir.path) {
        throw StateError('not inside the monorepo');
      }
      dir = up;
    }
    return dir;
  }();

  late Directory sandbox;

  setUp(() {
    sandbox = Directory.systemTemp.createTempSync('dw_create');
  });

  tearDown(() {
    sandbox.deleteSync(recursive: true);
  });

  final cli = p.join(
    repository.path,
    'packages',
    'dartway_cli',
    'bin',
    'dartway.dart',
  );

  Future<ProcessResult> dartway(List<String> arguments) => Process.run(
    Platform.resolvedExecutable,
    [cli, ...arguments],
    workingDirectory: sandbox.path,
  );

  Future<Directory> create(List<String> arguments) async {
    final result = await dartway(['create', ...arguments, '--no-git']);
    expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
    return Directory(p.join(sandbox.path, arguments.first));
  }

  String read(Directory project, String path) =>
      File(p.join(project.path, path)).readAsStringSync();

  test('everything is named after the project, and nothing after the '
      'template', () async {
    final project = await create([
      'shop_floor',
      '--local-repo',
      repository.path,
    ]);

    for (final package in ['shared', 'server', 'flutter']) {
      expect(
        File(
          p.join(project.path, 'shop_floor_$package', 'pubspec.yaml'),
        ).existsSync(),
        isTrue,
        reason: package,
      );
    }
    expect(
      read(project, 'shop_floor_shared/lib/generated/dw_protocol.dart'),
      contains('final DwWireProtocol shopFloorProtocol'),
    );
    expect(
      read(project, 'shop_floor_server/lib/generated/dw_schema.dart'),
      allOf(
        contains('final DwDatabaseSchema shopFloorSchema'),
        contains('extension ShopFloorDb'),
      ),
    );
    expect(
      read(project, 'shop_floor_server/lib/src/files.dart'),
      allOf(
        contains("defaultPublicBucket = 'shop-floor-public'"),
        contains("defaultPrivateBucket = 'shop-floor-private'"),
      ),
    );
    expect(
      read(project, 'shop_floor_shared/lib/src/shop_floor_refusal.dart'),
      contains('enum ShopFloorRefusal'),
    );

    final leftovers = [
      for (final entity in project.listSync(recursive: true))
        if (entity is File &&
            !entity.path.contains('${p.separator}.claude${p.separator}') &&
            _isText(entity) &&
            RegExp(
              'dartway_starter|DartwayStarter|dartwayStarter|dartway-starter',
            ).hasMatch(entity.readAsStringSync()))
          p.relative(entity.path, from: project.path),
    ];
    expect(leftovers, isEmpty);
  });

  test(
    'without --framework-path the pubspecs resolve from pub.dev: no '
    'overrides, the framework family and the tools as dev dependencies',
    () async {
      final project = await create(['shop', '--local-repo', repository.path]);
      for (final package in ['shop_shared', 'shop_server', 'shop_flutter']) {
        expect(
          read(project, '$package/pubspec.yaml'),
          isNot(contains('dependency_overrides')),
          reason: package,
        );
      }
      expect(
        read(project, 'shop_server/pubspec.yaml'),
        allOf(
          contains('dartway_core_server: ^0.20.0-dev.1'),
          contains('dartway_generator: ^0.20.0-dev.1'),
        ),
      );
      expect(
        read(project, 'shop_flutter/pubspec.yaml'),
        allOf(
          contains('dartway_core_flutter: ^0.20.0-dev.1'),
          contains('dartway_cli:'),
        ),
      );
    },
  );

  test('--framework-path overrides exactly the framework packages each '
      'package reaches, onto the checkout', () async {
    final project = await create(['shop', '--framework-path', repository.path]);
    Set<String> overridden(String package) {
      final lines = read(project, '$package/pubspec.yaml').split('\n');
      final start = lines.indexOf('dependency_overrides:');
      if (start < 0) return {};
      return {
        for (final line in lines.skip(start + 1))
          if (RegExp(r'^  ([a-z_]+):$').firstMatch(line) case final match?)
            match.group(1)!,
      };
    }

    expect(overridden('shop_shared'), {'dartway_core_shared'});
    expect(overridden('shop_server'), {
      'dartway_client',
      'dartway_core_server',
      'dartway_core_shared',
      'dartway_generator',
      'dartway_orm',
    });
    expect(overridden('shop_flutter'), {
      'dartway_cli',
      'dartway_client',
      'dartway_core_flutter',
      'dartway_core_shared',
      'dartway_lints',
      'dartway_router',
      'dartway_shared_preferences',
    });
    expect(
      read(project, 'shop_server/pubspec.yaml'),
      contains("path: '${p.join(repository.path, 'packages', 'dartway_orm')}'"),
    );
  });

  test('a name that cannot become a bucket name is refused', () async {
    for (final name in ['shop__floor', 'shop_', 'a' * 56]) {
      final result = await dartway(['create', name, '--no-git']);
      expect(result.exitCode, 64, reason: name);
      expect(Directory(p.join(sandbox.path, name)).existsSync(), isFalse);
    }
  });
}

bool _isText(File file) {
  const binary = {'.png', '.jpg', '.ico', '.jar', '.webp', '.ttf'};
  return !binary.contains(p.extension(file.path));
}
