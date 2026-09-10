import 'dart:io';

import 'package:dartway_cli/src/vendor_framework.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// A monorepo small enough to read: two packages that depend on each other by
/// caret, one of them a workspace member.
Directory _monorepo() {
  final root = Directory.systemTemp.createTempSync('dw_monorepo');
  void package(String name, String extra) {
    final dir = Directory(p.join(root.path, 'packages', name))
      ..createSync(recursive: true);
    File(p.join(dir.path, 'pubspec.yaml')).writeAsStringSync(
      'name: $name\nversion: 0.13.0\nresolution: workspace\n$extra',
    );
    File(p.join(dir.path, 'lib', '$name.dart'))
      ..createSync(recursive: true)
      ..writeAsStringSync('// $name\n');
    // Build output has no business travelling into a build context.
    Directory(p.join(dir.path, '.dart_tool'))..createSync();
  }

  package('dartway_core', 'dependencies:\n  dartway_extra: ^0.13.0\n');
  package('dartway_extra', '');
  // Flutter-only, and nothing in the server package reaches it. An override is
  // resolved whether or not anything depends on it, so this is what a
  // whole-set override drags into a pure-Dart image.
  package('dartway_telegram', 'dependencies:\n  flutter:\n    sdk: flutter\n');
  return root;
}

/// A created project: one package with a Dockerfile shaped like the real ones.
Directory _project() {
  final root = Directory.systemTemp.createTempSync('dw_project');
  final server = Directory(p.join(root.path, 'shop_server'))
    ..createSync(recursive: true);
  File(p.join(server.path, 'pubspec.yaml')).writeAsStringSync(
    'name: shop_server\n'
    'dependencies:\n'
    '  dartway_core: ^0.13.0\n',
  );
  File(p.join(server.path, 'Dockerfile')).writeAsStringSync('''
FROM dart:3.12.0 AS build
WORKDIR /workspace
COPY shop_shared/ shop_shared/
COPY shop_server/ shop_server/

WORKDIR /workspace/shop_server
RUN dart pub get
RUN dart compile exe bin/main.dart -o /server

FROM alpine:latest
COPY --from=build /server /app/server
COPY shop_server/config/ /app/config/
''');
  File(p.join(root.path, '.dockerignore')).writeAsStringSync(
    '**\n\n!shop_server/\n!shop_server/**\n',
  );
  return root;
}

void main() {
  late Directory monorepo;
  late Directory project;

  setUp(() {
    monorepo = _monorepo();
    project = _project();
  });

  tearDown(() {
    monorepo.deleteSync(recursive: true);
    project.deleteSync(recursive: true);
  });

  test('the packages travel into the project', () {
    vendorFramework(project: project, monorepo: monorepo);

    expect(
      File(
        p.join(project.path, vendorDirName, 'dartway_core', 'pubspec.yaml'),
      ).existsSync(),
      isTrue,
    );
    // A path dependency is resolved from the pubspec, and .dart_tool would
    // multiply the build context by the number of packages.
    expect(
      Directory(
        p.join(project.path, vendorDirName, 'dartway_core', '.dart_tool'),
      ).existsSync(),
      isFalse,
    );
  });

  test('workspace resolution is stripped from the copies', () {
    vendorFramework(project: project, monorepo: monorepo);

    // Inside the project there is no workspace root, and the line asks pub for
    // one — the copy would refuse to resolve with it.
    expect(
      File(
        p.join(project.path, vendorDirName, 'dartway_core', 'pubspec.yaml'),
      ).readAsStringSync(),
      isNot(contains('resolution: workspace')),
    );
  });

  test('every package of the project is overridden onto the copies', () {
    vendorFramework(project: project, monorepo: monorepo);

    final pubspec = File(
      p.join(project.path, 'shop_server', 'pubspec.yaml'),
    ).readAsStringSync();

    expect(pubspec, contains('dependency_overrides:'));
    expect(pubspec, contains('path: ../$vendorDirName/dartway_core'));
    // Including the ones the project never names itself: the framework's own
    // dependencies carry the same unpublished carets, and the entry package's
    // overrides are what govern the whole resolution.
    expect(pubspec, contains('path: ../$vendorDirName/dartway_extra'));
  });

  test('a package the project does not reach is left alone', () {
    // `dart pub get` resolves an override whether or not anything depends on
    // it, so overriding the whole set puts `flutter: sdk` in front of the
    // pure-Dart server image and the solve fails with exit code 69.
    vendorFramework(project: project, monorepo: monorepo);

    expect(
      File(
        p.join(project.path, 'shop_server', 'pubspec.yaml'),
      ).readAsStringSync(),
      isNot(contains('dartway_telegram')),
    );
  });

  test('running twice leaves one override block', () {
    vendorFramework(project: project, monorepo: monorepo);
    vendorFramework(project: project, monorepo: monorepo);

    final pubspec = File(
      p.join(project.path, 'shop_server', 'pubspec.yaml'),
    ).readAsStringSync();

    expect('dependency_overrides:'.allMatches(pubspec), hasLength(1));
  });

  test('the build context admits the copies', () {
    vendorFramework(project: project, monorepo: monorepo);

    final dockerignore = File(
      p.join(project.path, '.dockerignore'),
    ).readAsStringSync();

    expect(dockerignore, contains('!$vendorDirName/**'));
  });

  test('the Dockerfile copies them in, and only in the build stage', () {
    vendorFramework(project: project, monorepo: monorepo);

    final lines = File(
      p.join(project.path, 'shop_server', 'Dockerfile'),
    ).readAsLinesSync();
    final copy = lines.indexOf('COPY $vendorDirName/ $vendorDirName/');
    final resolve = lines.indexWhere((line) => line.contains('pub get'));
    final runtimeStage = lines.lastIndexWhere(
      (line) => line.startsWith('FROM '),
    );

    // Before the resolution that reads them, and above the second stage: the
    // runtime image has no use for a package directory, and the web image ends
    // with a COPY of its own that must not be mistaken for the anchor.
    expect(copy, greaterThan(0));
    expect(copy, lessThan(resolve));
    expect(copy, lessThan(runtimeStage));
  });

  test('a directory that is not a monorepo is refused by name', () {
    expect(
      () => vendorFramework(project: project, monorepo: project),
      throwsA(
        isA<ArgumentError>().having(
          (e) => e.message,
          'message',
          contains('packages/'),
        ),
      ),
    );
  });
}
