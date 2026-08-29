import 'dart:io';

import 'package:dartway_cli/src/build_context.dart';
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

  for (final package in const [
    'dartway_starter_server',
    'dartway_starter_flutter',
  ]) {
    test('$package: the image copies every package it depends on', () {
      final dockerfile = File(p.join(template.path, package, 'Dockerfile'));
      expect(dockerfile.existsSync(), isTrue, reason: dockerfile.path);

      final copied = readsOf(dockerfile).directories;
      expect(
        copied,
        contains(package),
        reason: 'the image does not copy the package it builds',
      );

      // Transitive: the client is a path dependency of flutter, and whatever
      // the client itself pulls in by path has to be in the context too.
      final needed = packagesNeededBy(template, package);

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

  for (final package in const [
    'dartway_starter_server',
    'dartway_starter_flutter',
  ]) {
    test('$package: .dockerignore admits everything the image copies', () {
      // A COPY line and an allow-list entry are two statements of one fact, and
      // they fail in opposite directions. A missing COPY fails as `pub get`
      // exit code 66, three layers deep; a missing allow-list entry fails
      // earlier and louder — `"/<package>": not found` at the COPY itself —
      // but only for whoever builds the image, and nothing in this repository
      // builds them. `web-compile.yml` compiles the Flutter web target from
      // source; the images are built by `dartway deploy`, on a server, by a
      // person. So the loud failure went unheard for as long as nobody
      // deployed a fresh skeleton.
      final admitted = admittedBy(File(p.join(template.path, '.dockerignore')));
      if (admitted == null) return;

      final copied = readsOf(
        File(p.join(template.path, package, 'Dockerfile')),
      ).directories;

      expect(
        copied.difference(admitted),
        isEmpty,
        reason:
            'the $package image copies directories that .dockerignore keeps '
            'out of the build context. The COPY fails outright — add the pair '
            'of `!<name>/` and `!<name>/**` lines for each.',
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
        pathDependenciesOf(
          File(p.join(template.path, package, 'pubspec.yaml')),
        ),
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
