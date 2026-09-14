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
/// **Nothing else can catch it cheaply.** Repository checks compile the server
/// and build the app *inside the checkout*, where the path resolves; the images
/// are built by `dartway deploy` on a server, and by the local stack proof. A project stays green and
/// cannot ship, and the two facts do not meet until somebody deploys. That is
/// what happened when a shared package was added by hand to a real project.
void main() {
  /// The repository root, found by walking up rather than by a fixed number
  /// of `..`: this suite is run both from the package directory and from the
  /// workspace root, and a hard-coded depth is right in exactly one of them.
  final repository = () {
    var dir = Directory.current.absolute;
    while (true) {
      if (Directory(p.join(dir.path, 'template')).existsSync() &&
          Directory(p.join(dir.path, 'example')).existsSync()) {
        return dir;
      }
      final up = dir.parent;
      if (up.path == dir.path) {
        throw StateError('no template/ above ${Directory.current.path}');
      }
      dir = up;
    }
  }();

  // The two projects this repository ships images for. The skeleton's app code
  // is still the 0.x one — its Flutter package depends on a generated client
  // package the 1.0 images no longer copy — so that one image is skipped, by
  // name and with the reason, until the template is ported; it is not dropped.
  const skeletonNotPorted =
      'template/ app code is not on DartWay 1.0 yet: dartway_starter_flutter '
      'still depends on dartway_starter_client, which the 1.0 web image does '
      'not copy. Re-enable with the template port.';
  final images = [
    (tree: 'example', package: 'dartway_example_server', skip: null),
    (tree: 'example', package: 'dartway_example_flutter', skip: null),
    (tree: 'template', package: 'dartway_starter_server', skip: null),
    (
      tree: 'template',
      package: 'dartway_starter_flutter',
      skip: skeletonNotPorted,
    ),
  ];

  for (final image in images) {
    final root = Directory(p.join(repository.path, image.tree));
    final package = image.package;

    test(
      '${image.tree}/$package: the image copies every package it depends on',
      () {
        final dockerfile = File(p.join(root.path, package, 'Dockerfile'));
        expect(dockerfile.existsSync(), isTrue, reason: dockerfile.path);

        final copied = readsOf(dockerfile).directories;
        expect(
          copied,
          contains(package),
          reason: 'the image does not copy the package it builds',
        );

        // Transitive: whatever a path dependency itself pulls in by path has to
        // be in the context too.
        final needed = packagesNeededBy(root, package);

        expect(
          needed.difference(copied),
          isEmpty,
          reason:
              'path dependencies missing from the build context of $package. '
              'Add a COPY line for each, or pub inside the image fails on a '
              'directory that is not there.',
        );
      },
      skip: image.skip,
    );

    test('${image.tree}/$package: .dockerignore admits everything the image '
        'copies', () {
      // A COPY line and an allow-list entry are two statements of one fact,
      // and they fail in opposite directions. A missing COPY fails as `pub
      // get` exit code 66, three layers deep; a missing allow-list entry fails
      // at the COPY itself — but only for whoever builds the image. The
      // example's own ignore file admitted a package that no longer existed
      // and not the one its images copy, for as long as nobody built them.
      final admitted = admittedBy(File(p.join(root.path, '.dockerignore')));
      expect(admitted, isNotNull, reason: 'the ignore file denies by default');

      final copied = readsOf(
        File(p.join(root.path, package, 'Dockerfile')),
      ).directories;

      expect(
        copied.where((directory) => !admits(admitted!, directory)),
        isEmpty,
        reason:
            'the $package image copies directories that .dockerignore keeps '
            'out of the build context. The COPY fails outright.',
      );
    });
  }

  final template = Directory(p.join(repository.path, 'template'));

  test('the shared package is wired into both halves', () {
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
