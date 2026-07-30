import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

import 'yaml_reader.dart';

/// A single deployment target declared in `deploy/config.yaml`.
///
/// This file describes the machine only. Everything the running application
/// needs — domains, ports, database — lives in the Serverpod configuration
/// (`<project>_server/config/<env>.yaml`) and is never duplicated here.
class DwDeployTarget {
  DwDeployTarget({
    required this.environment,
    required this.host,
    required this.sshUser,
    required this.deployUser,
    required this.os,
    required this.repo,
    required this.branch,
    required this.sslEmail,
    required this.webAppDomain,
    this.registryMirror,
    this.serverEntrypoint,
    this.firewallPorts = const [],
    this.requiredSecrets = const [],
    this.requiredSecretFiles = const [],
  });

  /// Environment name — the top-level key in `deploy/config.yaml`. Matches the
  /// Serverpod run mode, so `staging` here means `config/staging.yaml` there.
  final String environment;

  final String host;
  final String sshUser;
  final String deployUser;
  final String os;
  final String repo;
  final String branch;
  final String sslEmail;

  /// Domain serving the Flutter web build. Serverpod has no concept of it,
  /// which is why it is one of the few domains declared on this side.
  final String webAppDomain;

  /// Registry to pull base images through, e.g. `mirror.gcr.io`.
  final String? registryMirror;

  /// Path to the server binary inside the image, used to override the image
  /// entrypoint when running migrations.
  ///
  /// Needed only when the Dockerfile declares `ENTRYPOINT` in shell form: that
  /// form ignores the arguments `docker compose run` appends, so a migration
  /// run would silently start an ordinary server instead. The template uses
  /// exec form, where arguments replace `CMD` and nothing is needed here.
  final String? serverEntrypoint;

  /// Extra TCP ports to open beyond SSH, 80 and 443.
  final List<int> firewallPorts;

  /// Secrets that cannot be generated and must be delivered by a human.
  /// Checked on the server; listing them here turns a runtime failure into a
  /// pre-deploy one.
  final List<String> requiredSecrets;

  /// Secret files (service account JSON and similar) expected on the server.
  final List<String> requiredSecretFiles;

  static const _configRelativePath = 'deploy/config.yaml';

  /// Project name derived from the repository URL. Names the checkout and the
  /// runtime configuration directory on the server.
  String get projectName {
    final lastSegment = repo.split('/').last;
    return lastSegment.endsWith('.git')
        ? lastSegment.substring(0, lastSegment.length - 4)
        : lastSegment;
  }

  /// Where the deployment keeps the repository checkout.
  String get appDir => '/home/$deployUser/$projectName';

  /// Where runtime secrets live — outside Git and outside the checkout, so
  /// that `git reset --hard` on deploy can never touch them.
  String get runtimeConfigDir => '/home/$deployUser/.config/$projectName';

  /// Reads one environment from `<projectRoot>/deploy/config.yaml`.
  static DwDeployTarget load({
    required Directory projectRoot,
    required String environment,
  }) {
    final file = File(p.join(projectRoot.path, 'deploy', 'config.yaml'));
    if (!file.existsSync()) {
      throw StateError(
        'No $_configRelativePath in ${projectRoot.path}.\n'
        'Create it, or run this command from a DartWay project root.',
      );
    }

    final document = loadYaml(file.readAsStringSync());
    if (document is! YamlMap) {
      throw StateError('$_configRelativePath must be a map of environments.');
    }

    final section = document[environment];
    if (section == null) {
      final known = document.keys.join(', ');
      throw StateError(
        'No "$environment" environment in $_configRelativePath. '
        'Declared: ${known.isEmpty ? '<none>' : known}.',
      );
    }
    if (section is! YamlMap) {
      throw StateError('"$environment" in $_configRelativePath must be a map.');
    }

    final reader = DwYamlReader(section, source: _configRelativePath);
    final requires = reader.optionalMap('requires');
    final requiresReader = requires == null
        ? null
        : DwYamlReader(requires, source: '$_configRelativePath > requires');

    return DwDeployTarget(
      environment: environment,
      host: reader.requiredString('host'),
      sshUser: reader.requiredString('ssh_user'),
      deployUser: reader.requiredString('deploy_user'),
      os: reader.requiredString('os'),
      repo: reader.requiredString('repo'),
      branch: reader.requiredString('branch'),
      sslEmail: reader.requiredString('ssl_email'),
      webAppDomain: reader.requiredString('web_app_domain'),
      registryMirror: reader.optionalString('registry_mirror'),
      serverEntrypoint: reader.optionalString('server_entrypoint'),
      firewallPorts: reader.optionalIntList('firewall_ports'),
      requiredSecrets:
          requiresReader?.optionalStringList('secrets') ?? const [],
      requiredSecretFiles:
          requiresReader?.optionalStringList('files') ?? const [],
    );
  }

  /// Environment names declared in `deploy/config.yaml`, in file order.
  static List<String> environmentsIn(Directory projectRoot) {
    final file = File(p.join(projectRoot.path, 'deploy', 'config.yaml'));
    if (!file.existsSync()) {
      return const [];
    }
    final document = loadYaml(file.readAsStringSync());
    if (document is! YamlMap) {
      return const [];
    }
    return document.keys.map((key) => key.toString()).toList();
  }
}
