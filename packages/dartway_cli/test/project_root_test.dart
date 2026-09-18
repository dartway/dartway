import 'dart:io';

import 'package:dartway_cli/src/project_layout.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// Where a command run from inside a project finds the project.
///
/// `dart run dartway_cli:dartway <command>` runs from the package that pins
/// the CLI — the Flutter one — and `deploy` used to read the working
/// directory, telling a person standing in their own project that there was
/// no DartWay project anywhere.
void main() {
  late Directory temp;
  late Directory project;

  setUp(() {
    temp = Directory.systemTemp.createTempSync('dw_project_root_');
    project = Directory(p.join(temp.path, 'shop'))..createSync();
    for (final package in ['shop_server', 'shop_shared', 'shop_flutter']) {
      final directory = Directory(p.join(project.path, package))
        ..createSync(recursive: true);
      File(p.join(directory.path, 'pubspec.yaml'))
          .writeAsStringSync('name: $package\n');
    }
  });
  tearDown(() => temp.deleteSync(recursive: true));

  String? rootFrom(String path) =>
      findPackageProjectRoot(Directory(path))?.path;

  test('the project root answers itself', () {
    expect(rootFrom(project.path), project.path);
  });

  test('a command run from any package of the project finds the project', () {
    for (final package in ['shop_server', 'shop_shared', 'shop_flutter']) {
      expect(
        rootFrom(p.join(project.path, package)),
        project.path,
        reason: 'from $package',
      );
    }
  });

  test('and from a directory inside a package', () {
    final deep = Directory(p.join(project.path, 'shop_flutter', 'lib', 'app'))
      ..createSync(recursive: true);
    expect(rootFrom(deep.path), project.path);
  });

  test('the project is the directory that holds the packages, not the package '
      'the command happened to stand in', () {
    // Even for a single package: what a deploy reads — deploy/config.yaml,
    // the Dockerfiles of its siblings — lives beside it, not inside it.
    final lone = Directory(p.join(temp.path, 'solo', 'lonely_server'))
      ..createSync(recursive: true);
    File(p.join(lone.path, 'pubspec.yaml')).writeAsStringSync('name: x\n');
    expect(rootFrom(lone.path), p.dirname(lone.path));
  });

  test('outside a project there is none, and the caller says so rather than '
      'guessing', () {
    expect(rootFrom(temp.path), isNull);
  });
}
