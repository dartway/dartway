import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

import 'deploy_target.dart';
import 'local_secrets_file.dart';

/// The `local` environment of a project: what a developer's own machine starts
/// a server with.
///
/// The same two files every other environment is described in, cut along the
/// only line Git forces:
///
/// - `deploy/config.yaml` > `local` — committed, because the coordinates of
///   the development database and storage are the same for everyone on the
///   team and belong in the repository;
/// - `deploy/secrets.yaml` > `local` — git-ignored, because the keys under it
///   are this developer's own.
///
/// The server side of this is `DwLocalEnvironment` in `dartway_core_server`,
/// which the project's entry point calls. This class is the maintenance side:
/// what is there, what is missing, and writing one value without opening an
/// editor.
class DwLocalEnvironment {
  DwLocalEnvironment(this.projectRoot);

  final Directory projectRoot;

  /// The section both files keep this machine's environment under.
  static const String section = DwDeployTarget.localSection;

  File get configFile =>
      File(p.join(projectRoot.path, 'deploy', 'config.yaml'));

  DwLocalSecretsFile get secretsFile => DwLocalSecretsFile.of(projectRoot);

  static const String configPath = 'deploy/config.yaml';
  static const String secretsPath = DwLocalSecretsFile.relativePath;

  /// The committed half: `deploy/config.yaml` > `local`.
  Map<String, String> get committed {
    final document = _config;
    if (document == null) return const {};
    final local = document[section];
    if (local == null) return const {};
    if (local is! YamlMap) {
      throw StateError(
        '$configPath > $section must be a map of environment variables to '
        'values.',
      );
    }
    return {
      for (final entry in local.entries)
        entry.key.toString(): _scalar(entry.key, entry.value),
    };
  }

  /// The git-ignored half: `deploy/secrets.yaml` > `local`.
  Map<String, String> get mine =>
      (secretsFile.read() ?? const {})[section] ?? const {};

  /// Every secret the project declares it needs, wherever it runs.
  ///
  /// The hoisted `requires:` only. What one deployment needs beyond it is that
  /// deployment's business, and asking a laptop for it would be asking for a
  /// key nobody local can use.
  List<String> get requiredSecrets {
    final document = _config;
    if (document == null) return const [];
    final requires = document['requires'];
    if (requires is! YamlMap) return const [];
    final secrets = requires['secrets'];
    if (secrets is! YamlList) return const [];
    return [for (final entry in secrets) entry.toString()];
  }

  /// [environment] with both halves under it, the way a project's entry point
  /// sees it: committed first, the developer's own over it, and a real
  /// environment variable over both.
  Map<String, String> overlay(Map<String, String> environment) => {
    ...committed,
    ...mine,
    ...environment,
  };

  /// Stores [value] under [key] in the git-ignored half, creating the file
  /// when it is not there yet.
  void store(String key, String value) {
    final file = secretsFile;
    if (!file.exists) {
      file.file
        ..parent.createSync(recursive: true)
        ..writeAsStringSync(
          '# Secrets of every environment, including this machine\'s "local".\n'
          '# Git-ignored; keep it backed up somewhere you control.\n',
        );
    }
    file.write(section, {key: value});
  }

  YamlMap? get _config {
    if (!configFile.existsSync()) return null;
    final document = loadYaml(configFile.readAsStringSync());
    if (document == null) return null;
    if (document is! YamlMap) {
      throw StateError('$configPath must be a map of environments.');
    }
    return document;
  }

  static String _scalar(Object? key, Object? value) {
    if (value == null) return '';
    if (value is YamlMap || value is YamlList) {
      throw StateError(
        '$configPath > $section > $key is not a single value. The section is '
        'the environment a server is started with, and a process environment '
        'holds text.',
      );
    }
    return value.toString();
  }
}
