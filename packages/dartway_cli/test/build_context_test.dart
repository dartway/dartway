import 'dart:io';

import 'package:dartway_cli/src/build_context.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late Directory root;

  setUp(() => root = Directory.systemTemp.createTempSync('dw_context_'));
  tearDown(() => root.deleteSync(recursive: true));

  void write(String path, String content) {
    final file = File(p.join(root.path, path));
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(content);
  }

  /// A package that depends on [dependencies] by path.
  void package(String name, {List<String> dependencies = const []}) {
    write(
      '$name/pubspec.yaml',
      [
        'name: $name',
        if (dependencies.isNotEmpty) 'dependencies:',
        for (final dependency in dependencies)
          '  $dependency:\n    path: ../$dependency',
      ].join('\n'),
    );
  }

  group('readsOf', () {
    test('names the directories a Dockerfile takes from the context', () {
      write('app/Dockerfile', '''
FROM dart:stable AS build
COPY shared/ shared/
COPY app/ app/
''');
      final reads = readsOf(File(p.join(root.path, 'app', 'Dockerfile')));
      expect(reads.directories, {'shared', 'app'});
      expect(reads.wholeContext, isFalse);
    });

    test('reads `COPY . .` as the whole context, not as a parse failure', () {
      // Named in the issue: a Dockerfile that takes everything satisfies every
      // package, and must not be reported as one that names nothing.
      write('app/Dockerfile', 'FROM alpine\nCOPY . .\n');
      final reads = readsOf(File(p.join(root.path, 'app', 'Dockerfile')));
      expect(reads.wholeContext, isTrue);
      expect(reads.directories, isEmpty);
    });

    test('does not count a copy from an earlier stage', () {
      // Also named in the issue. `--from` reads a stage's filesystem, not the
      // context; counting it would let a multi-stage file claim directories
      // that were never sent to the daemon.
      write('app/Dockerfile', '''
FROM dart:stable AS build
COPY app/ app/
FROM alpine
COPY --from=build /workspace/shared/ shared/
COPY --from=build /server /app/server
''');
      final reads = readsOf(File(p.join(root.path, 'app', 'Dockerfile')));
      expect(reads.directories, {'app'});
    });

    test('survives flags before the source and several sources at once', () {
      write('app/Dockerfile', 'FROM alpine\nCOPY --chown=1:1 a/ b/ dest/\n');
      expect(
        readsOf(File(p.join(root.path, 'app', 'Dockerfile'))).directories,
        {'a', 'b'},
      );
    });
  });

  group('admittedBy', () {
    test('lists what a deny-by-default ignore file lets back in', () {
      write('.dockerignore', '# a comment\n**\n!app/\n!app/**\n!shared/\n');
      expect(admittedBy(File(p.join(root.path, '.dockerignore'))), {
        'app',
        'shared',
      });
    });

    test('answers null when the file does not deny by default', () {
      // Then everything is in the context already: there is nothing to admit
      // and no way to get this wrong, so the check has nothing to say.
      write('.dockerignore', '**/.dart_tool/\n**/build/\n');
      expect(admittedBy(File(p.join(root.path, '.dockerignore'))), isNull);
    });

    test('answers null when there is no ignore file', () {
      expect(admittedBy(File(p.join(root.path, '.dockerignore'))), isNull);
    });
  });

  group('packagesNeededBy', () {
    test('follows path dependencies through', () {
      // The real shape: the Flutter package depends on the client, and the
      // client pulls in shared. A check that stopped at the first level would
      // pass the case it exists for.
      package('app', dependencies: ['client']);
      package('client', dependencies: ['shared']);
      package('shared');
      expect(packagesNeededBy(root, 'app'), {'client', 'shared'});
    });

    test('does not loop on a cycle', () {
      package('a', dependencies: ['b']);
      package('b', dependencies: ['a']);
      expect(packagesNeededBy(root, 'a'), {'a', 'b'});
    });
  });

  group('buildContextProblems', () {
    setUp(() {
      package('server', dependencies: ['shared']);
      package('shared');
    });

    test('says nothing when every package reaches the image', () {
      write(
        'server/Dockerfile',
        'FROM alpine\nCOPY shared/ shared/\nCOPY server/ server/\n',
      );
      write(
        '.dockerignore',
        '**\n!server/\n!server/**\n!shared/\n!shared/**\n',
      );
      expect(
        buildContextProblems(projectRoot: root, packages: ['server']),
        isEmpty,
      );
    });

    test('names a dependency the Dockerfile never copies', () {
      write('server/Dockerfile', 'FROM alpine\nCOPY server/ server/\n');
      expect(buildContextProblems(projectRoot: root, packages: ['server']), [
        'server/Dockerfile does not copy shared',
      ]);
    });

    test('names a directory the ignore file keeps out', () {
      // The failure that shipped: both Dockerfiles copied the shared package
      // and the ignore file never admitted it, so the COPY failed outright —
      // on the server, at deploy time, and nowhere else.
      write(
        'server/Dockerfile',
        'FROM alpine\nCOPY shared/ shared/\nCOPY server/ server/\n',
      );
      write('.dockerignore', '**\n!server/\n!server/**\n');
      expect(buildContextProblems(projectRoot: root, packages: ['server']), [
        '.dockerignore keeps shared out of the server build context',
      ]);
    });

    test('a whole-context copy still answers to the ignore file', () {
      // `COPY . .` cannot miss a package, but the context it copies is still
      // only what the ignore file admitted.
      write('server/Dockerfile', 'FROM alpine\nCOPY . .\n');
      write('.dockerignore', '**\n!server/\n!server/**\n');
      expect(buildContextProblems(projectRoot: root, packages: ['server']), [
        '.dockerignore keeps shared out of the server build context',
      ]);
    });

    test('a whole-context copy with nothing denied is simply fine', () {
      write('server/Dockerfile', 'FROM alpine\nCOPY . .\n');
      expect(
        buildContextProblems(projectRoot: root, packages: ['server']),
        isEmpty,
      );
    });

    test('a package with no Dockerfile is not this check\'s business', () {
      expect(
        buildContextProblems(projectRoot: root, packages: ['shared']),
        isEmpty,
      );
    });
  });
}
