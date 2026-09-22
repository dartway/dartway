import 'dart:io';

import 'package:yaml/yaml.dart';

/// The environment a developer's machine adds to a server started by hand.
///
/// A deployed server is configured by its environment alone: the deploy
/// renders `.env` from the secret store and Compose hands it to the container.
/// On a developer's machine nobody renders anything — the server is started by
/// `dart run bin/server.dart` or by the IDE, with whatever environment that
/// process happened to inherit. That is why every project used to carry the
/// same block of `DW_DATABASE_*` copied into a launch configuration, a README
/// and a shell profile, each copy free to drift.
///
/// So the project's own entry point reads the two files the project already
/// has, in one visible line:
///
/// ```dart
/// final env = DwLocalEnvironment.overlay(Platform.environment);
/// ```
///
/// - `deploy/config.yaml` > `local` — committed: the coordinates of the
///   development database and storage, the same for everyone on the team;
/// - `deploy/secrets.yaml` > `local` — git-ignored: the keys that are this
///   developer's own.
///
/// **The real environment always wins**, so one exported variable overrides a
/// file without editing it, and a deployed server — which inherits everything
/// from Compose — is unaffected even in the impossible case that a file were
/// there. It is impossible because `.dockerignore` admits only the packages
/// into the build context: `deploy/` never enters an image, and the runtime
/// stage holds nothing but the compiled binary. There is no run mode here and
/// no "am I in development" flag — there is a file next to the project, or
/// there is not.
///
/// What it loaded is announced on stdout, because a value whose origin cannot
/// be named is the kind of thing that costs an afternoon.
abstract final class DwLocalEnvironment {
  /// The committed half, relative to the project root.
  static const String configPath = 'deploy/config.yaml';

  /// The git-ignored half, relative to the project root.
  static const String secretsPath = 'deploy/secrets.yaml';

  /// The section both files keep this machine's environment under.
  static const String section = 'local';

  /// How far up from the starting directory a project root is looked for.
  ///
  /// A server package sits one level below it, a test two. Beyond that a walk
  /// up is no longer finding this project's `deploy/` but somebody's home
  /// directory.
  static const int searchDepth = 4;

  /// [environment] with the `local` section of both files under it.
  ///
  /// Returns [environment] unchanged when no project root is found above
  /// [from] (the deployed case, and any directory outside a project).
  ///
  /// Throws a [StateError] naming the file and the key when a file is there
  /// and cannot be read as this: a local environment that is half-applied is
  /// worse than one that is absent, because the server starts and fails
  /// somewhere far from the reason.
  static Map<String, String> overlay(
    Map<String, String> environment, {
    Directory? from,
    void Function(String message)? report,
  }) {
    final root = projectRootAbove(from ?? Directory.current);
    if (root == null) return Map.unmodifiable(environment);

    final config = _read(File('${root.path}/$configPath'));
    final secrets = _read(File('${root.path}/$secretsPath'));
    if (config.isEmpty && secrets.isEmpty) return Map.unmodifiable(environment);

    final merged = <String, String>{...config, ...secrets, ...environment};
    final overridden = [
      for (final key in {...config.keys, ...secrets.keys})
        if (environment.containsKey(key)) key,
    ]..sort();
    (report ?? stdout.writeln)(
      'Local environment: ${config.length} key(s) from $configPath, '
      '${secrets.length} from $secretsPath'
      '${overridden.isEmpty ? '' : '; the process environment overrides '
                '${overridden.join(', ')}'}',
    );
    return Map.unmodifiable(merged);
  }

  /// The nearest directory at or above [start] that holds [configPath], or
  /// null when there is none within [searchDepth].
  static Directory? projectRootAbove(Directory start) {
    var directory = start.absolute;
    for (var level = 0; level <= searchDepth; level++) {
      if (File('${directory.path}/$configPath').existsSync()) return directory;
      final parent = directory.parent;
      if (parent.path == directory.path) return null;
      directory = parent;
    }
    return null;
  }

  /// The `local` section of [file] as environment variables, or nothing when
  /// the file or the section is absent.
  static Map<String, String> _read(File file) {
    if (!file.existsSync()) return const {};

    final Object? document;
    try {
      document = loadYaml(file.readAsStringSync());
    } on YamlException catch (error) {
      throw StateError('${file.path} is not valid YAML: ${error.message}');
    }
    if (document == null) return const {};
    if (document is! YamlMap) {
      throw StateError('${file.path} must be a map of environments.');
    }
    final local = document[section];
    if (local == null) return const {};
    if (local is! YamlMap) {
      throw StateError(
        '${file.path} > $section must be a map of environment variables to '
        'values.',
      );
    }

    final values = <String, String>{};
    for (final entry in local.entries) {
      final key = entry.key.toString();
      if (!_isVariableName(key)) {
        throw StateError(
          '${file.path} > $section: "$key" is not an environment variable '
          'name — upper case letters, digits and underscores, not starting '
          'with a digit.',
        );
      }
      final value = entry.value;
      if (value is YamlMap || value is YamlList) {
        throw StateError(
          '${file.path} > $section > $key is not a single value. The section '
          'is the environment the server is started with, and a process '
          'environment holds text.',
        );
      }
      // A YAML scalar is typed — 8090 is an int, false is a bool — and an
      // environment is text either way.
      values[key] = value == null ? '' : value.toString();
    }
    return values;
  }

  static bool _isVariableName(String key) =>
      RegExp(r'^[A-Z_][A-Z0-9_]*$').hasMatch(key);
}
