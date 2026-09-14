import 'dart:io';

import 'package:dart_style/dart_style.dart';
import 'package:meta/meta.dart';
import 'package:path/path.dart' as p;
import 'package:pub_semver/pub_semver.dart';
import 'package:yaml/yaml.dart';

/// What a draft needs to know about the project it is written into: which
/// library to import ORM types from, and which language version to format for.
@internal
final class DwMigrationProject {
  const DwMigrationProject({
    required this.ormLibrary,
    required this.languageVersion,
  });

  /// A project that declares nothing: the ORM itself, formatted at the newest
  /// language version the formatter knows.
  static final DwMigrationProject standalone = DwMigrationProject(
    ormLibrary: ormPackageLibrary,
    languageVersion: DartFormatter.latestLanguageVersion,
  );

  static const ormPackageLibrary = 'package:dartway_orm/dartway_orm.dart';
  static const serverPackageLibrary =
      'package:dartway_core_server/dartway_core_server.dart';

  /// The library a draft imports: `dartway_core_server`, which re-exports the
  /// ORM, when the project depends on it — a server project does, and its
  /// `analyze` flags an import of a package it does not declare
  /// (`depend_on_referenced_packages`) — otherwise `dartway_orm`.
  final String ormLibrary;

  /// The project's language version (its SDK constraint's lower bound), so a
  /// draft is formatted the way `dart format` formats the project.
  final Version languageVersion;

  /// The project owning [directory]: the nearest `pubspec.yaml` at or above
  /// it. [standalone] when there is none.
  static DwMigrationProject of(String directory) {
    var folder = p.absolute(p.normalize(directory));
    while (true) {
      final pubspec = File(p.join(folder, 'pubspec.yaml'));
      if (pubspec.existsSync()) {
        return fromPubspec(pubspec.readAsStringSync());
      }
      final parent = p.dirname(folder);
      if (parent == folder) return standalone;
      folder = parent;
    }
  }

  /// Reads a `pubspec.yaml`. Only `dependencies` count: a draft is compiled
  /// into the project's own code, which cannot import a dev dependency.
  static DwMigrationProject fromPubspec(String text) {
    final yaml = loadYaml(text);
    final dependencies = yaml is YamlMap ? yaml['dependencies'] : null;
    final environment = yaml is YamlMap ? yaml['environment'] : null;
    final sdk = environment is YamlMap ? environment['sdk'] : null;
    return DwMigrationProject(
      ormLibrary:
          dependencies is YamlMap &&
              dependencies.containsKey('dartway_core_server')
          ? serverPackageLibrary
          : ormPackageLibrary,
      languageVersion: _languageVersionOf(sdk),
    );
  }

  /// `major.minor` of the constraint's lower bound, never newer than the
  /// formatter knows; the newest it knows when there is no bound.
  static Version _languageVersionOf(Object? sdk) {
    final latest = DartFormatter.latestLanguageVersion;
    if (sdk is! String) return latest;
    final VersionConstraint constraint;
    try {
      constraint = VersionConstraint.parse(sdk);
    } on FormatException {
      return latest;
    }
    final min = constraint is VersionRange ? constraint.min : null;
    if (min == null) return latest;
    final version = Version(min.major, min.minor, 0);
    return version > latest ? latest : version;
  }

  /// [source] formatted as `dart format` formats this project.
  String format(String source) =>
      DartFormatter(languageVersion: languageVersion).format(source);
}
