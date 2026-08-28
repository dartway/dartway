import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

/// Every path dependency of a template package is copied by the image that
/// builds it.
///
/// The images are built from the project root and name package directories one
/// by one. A directory that is never named does not enter the build context,
/// so `pub get` inside the image fails on a dependency whose folder is not
/// there — as exit code 66, three layers from the cause, pointing at neither
/// the Dockerfile nor the package.
///
/// **Nothing else can catch it.** Repository checks compile the server and
/// build the app *inside the checkout*, where the path resolves; the images are
/// built only by `dartway deploy`, on the server. A project stays green and
/// cannot ship, and the two facts do not meet until somebody deploys. That is
/// what happened when a shared package was added by hand to a real project.
void main() {
  /// The repository's `template/`, found by walking up rather than by a fixed
  /// number of `..`: this suite is run both from the package directory and from
  /// the workspace root, and a hard-coded depth is right in exactly one of them.
  final template = () {
    var dir = Directory.current.absolute;
    while (true) {
      final candidate = Directory(
        p.join(dir.path, 'template', 'dartway_starter_server'),
      );
      if (candidate.existsSync()) {
        return Directory(p.join(dir.path, 'template'));
      }
      final up = dir.parent;
      if (up.path == dir.path) {
        throw StateError('no template/ above ${Directory.current.path}');
      }
      dir = up;
    }
  }();

  /// Package directories a Dockerfile copies into its context.
  Set<String> copiedBy(File dockerfile) => {
    for (final line in dockerfile.readAsLinesSync())
      if (RegExp(r'^\s*COPY\s+([a-z0-9_]+)/\s').firstMatch(line)
          case final match?)
        match.group(1)!,
  };

  /// Sibling packages [pubspec] depends on by path.
  Set<String> pathDepsOf(File pubspec) {
    final document = loadYaml(pubspec.readAsStringSync());
    final dependencies = document is YamlMap ? document['dependencies'] : null;
    if (dependencies is! YamlMap) {
      return const {};
    }
    return {
      for (final entry in dependencies.entries)
        if (entry.value is YamlMap && (entry.value as YamlMap)['path'] != null)
          entry.key.toString(),
    };
  }

  for (final package in const ['dartway_starter_server', 'dartway_starter_flutter']) {
    test('$package: the image copies every package it depends on', () {
      final dockerfile = File(p.join(template.path, package, 'Dockerfile'));
      final pubspec = File(p.join(template.path, package, 'pubspec.yaml'));
      expect(dockerfile.existsSync(), isTrue, reason: dockerfile.path);

      final copied = copiedBy(dockerfile);
      expect(
        copied,
        contains(package),
        reason: 'the image does not copy the package it builds',
      );

      // Transitive: the client is a path dependency of flutter, and whatever
      // the client itself pulls in by path has to be in the context too.
      final pending = <String>{...pathDepsOf(pubspec)};
      final needed = <String>{};
      while (pending.isNotEmpty) {
        final name = pending.first;
        pending.remove(name);
        if (!needed.add(name)) {
          continue;
        }
        final nested = File(p.join(template.path, name, 'pubspec.yaml'));
        if (nested.existsSync()) {
          pending.addAll(pathDepsOf(nested));
        }
      }

      expect(
        needed.difference(copied),
        isEmpty,
        reason:
            'path dependencies missing from the build context of $package. '
            'Add a COPY line for each, or pub inside the image fails on a '
            'directory that is not there.',
      );
    });
  }

  test('the shared package is wired into both halves', () {
    // The skeleton ships it deliberately: the guidance used to describe a
    // package a project had to assemble by hand, and the one hint it gave
    // about that package was wrong.
    for (final package in const [
      'dartway_starter_server',
      'dartway_starter_flutter',
    ]) {
      expect(
        pathDepsOf(File(p.join(template.path, package, 'pubspec.yaml'))),
        contains('dartway_starter_shared'),
        reason: package,
      );
    }
  });

  test('the shared package depends on nothing', () {
    // The constraint is the whole design. The server does not depend on the
    // client package — it carries its own generated copy — so a shared package
    // that reached for the protocol would serve exactly one of the two sides.
    final document = loadYaml(
      File(
        p.join(template.path, 'dartway_starter_shared', 'pubspec.yaml'),
      ).readAsStringSync(),
    );
    final dependencies = (document as YamlMap)['dependencies'];
    expect(dependencies, anyOf(isNull, isEmpty));
  });
}
