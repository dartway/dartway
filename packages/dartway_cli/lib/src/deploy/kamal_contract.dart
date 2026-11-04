import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

import '../project_layout.dart';
import 'deploy_target.dart';
import 'stack.dart';
import 'yaml_reader.dart';

/// The variables Studio sets when it deploys or checks one environment.
///
/// The repository names no environment: the generated Kamal configuration
/// reads these through ERB, and `deploy/studio.yml` lists them, so a new
/// environment is a new set of values in Studio and no commit.
abstract final class DwStudioVariables {
  /// The environment's name. Kamal's destination is the same name, so every
  /// identity Kamal derives from it (`<service>-<role>-<env>` containers,
  /// `.kamal/apps/<service>-<env>`) is built from it.
  static const environment = 'STUDIO_ENVIRONMENT';
  static const host = 'STUDIO_HOST';
  static const sshUser = 'STUDIO_SSH_USER';

  /// `STUDIO_DOMAIN_<POINT>`: the public host of an ingress point.
  static String domain(String point) => 'STUDIO_DOMAIN_${point.toUpperCase()}';

  /// `STUDIO_BUNDLED_<COMPONENT>`: `true` where the environment runs the
  /// component itself, `false` where it is external.
  static String bundled(String component) =>
      'STUDIO_BUNDLED_${component.toUpperCase()}';
}

/// What an environment name may be: it becomes part of Kamal service, volume,
/// accessory and directory names.
final RegExp dwKamalEnvironmentPattern = RegExp(r'^[a-z0-9][a-z0-9_-]*$');

/// The project half of a Kamal deployment: `deploy/config.yaml > kamal`.
///
/// Everything here holds for every environment. Where an environment runs —
/// host, SSH user, domains, which components are bundled, secret values — is
/// Studio's, read at deploy time through [DwStudioVariables].
class DwKamalProject {
  DwKamalProject({
    required this.repo,
    required this.storage,
    this.project,
    this.deployUser = DwDeployTarget.defaultDeployUser,
    this.requiredSecrets = const [],
    this.requiredSecretFiles = const [],
  });

  /// The GitHub repository whose owner names the images in GHCR.
  final String repo;

  /// `project:`, or null when the identity comes from [repo].
  final String? project;

  /// Whether the project stores files: the `storage` component exists, bundled
  /// or external per environment.
  final bool storage;

  /// The owner of `/home/<deploy_user>/.config/<project>`, where
  /// `requires.files` are delivered on every host.
  final String deployUser;

  final List<String> requiredSecrets;
  final List<String> requiredSecretFiles;

  static const _keys = {'repo', 'project', 'deploy_user', 'storage'};

  String get projectName => DwDeployTarget(
    environment: '',
    host: '',
    sshUser: '',
    deployUser: deployUser,
    os: '',
    repo: repo,
    branch: '',
    sslEmail: '',
    apiDomain: '',
    appDomain: '',
    project: project,
  ).projectName;

  /// Where `requires.files` live on every host of every environment.
  String get runtimeConfigDir => '/home/$deployUser/.config/$projectName';

  /// Reads `deploy/config.yaml > kamal` and the project's `requires`.
  ///
  /// A Kamal project keeps no deployment sections: they would read as a
  /// server list somebody believes is in force, while Studio deploys from its
  /// own. Both the section's absence and leftover sections are refused.
  static DwKamalProject load(Directory projectRoot) {
    const path = DwDeployTarget.configRelativePath;
    const section = DwDeployTarget.kamalSection;
    final file = File(p.join(projectRoot.path, path));
    if (!file.existsSync()) {
      throw StateError('No $path in ${projectRoot.path}.');
    }
    final document = loadYaml(file.readAsStringSync());
    if (document is! YamlMap) {
      throw StateError('$path must be a map.');
    }
    final deployments = DwDeployTarget.deployableIn(document);
    if (deployments.isNotEmpty) {
      throw StateError(
        '$path: ${deployments.join(', ')} '
        '${deployments.length == 1 ? 'is a deployment section' : 'are deployment sections'}; '
        'a Kamal project keeps its environments in Studio. Move what is '
        'common to "$section:", delete the sections and regenerate.',
      );
    }
    final kamal = document[section];
    if (kamal is! YamlMap) {
      throw StateError(
        '$path: declare "$section:" with "repo:" (and "storage: true" when '
        'the project stores files) before generating Kamal configuration.',
      );
    }
    final source = '$path > $section';
    final problems = <String>[
      for (final key in kamal.keys.map((key) => '$key'))
        if (!_keys.contains(key))
          '$source: unknown key "$key" (known: ${(_keys.toList()..sort()).join(', ')})',
    ];
    final reader = DwYamlReader(kamal, source: source);
    String? read(String Function() value) {
      try {
        return value();
      } on StateError catch (error) {
        problems.add(error.message);
        return null;
      }
    }

    final repo = read(() => reader.requiredString('repo'));
    final project = read(() => reader.optionalString('project') ?? '');
    final deployUser = read(
      () =>
          reader.optionalString('deploy_user') ??
          DwDeployTarget.defaultDeployUser,
    );
    final storage = kamal['storage'] ?? false;
    if (storage is! bool) {
      problems.add('$source: "storage" is true or false, got "$storage"');
    }
    if (problems.isNotEmpty) {
      throw StateError(
        '$path is not deployable:\n${problems.map((line) => '  - $line').join('\n')}',
      );
    }
    final requires = DwDeployTarget.projectRequiresIn(document);
    final result = DwKamalProject(
      repo: repo!,
      project: project!.isEmpty ? null : project,
      deployUser: deployUser!,
      storage: storage as bool,
      requiredSecrets: requires.secrets,
      requiredSecretFiles: requires.files,
    );
    if (!DwDeployTarget.projectNamePattern.hasMatch(result.projectName)) {
      throw StateError(
        '$source: project: "${result.projectName}" must start with a lower '
        'case letter or digit and contain only lower case letters, digits, '
        '"_" and "-". Set project: explicitly when the repository name does '
        'not match.',
      );
    }
    return result;
  }
}

/// What one environment must give for one mode of an optional component.
class DwKamalNeeds {
  const DwKamalNeeds({
    this.values = const [],
    this.optionalValues = const [],
    this.secrets = const [],
  });

  /// Non-secret values, set under their own names and rendered into
  /// `env.clear`.
  final List<String> values;

  /// Non-secret values rendered only when the environment sets them.
  final List<String> optionalValues;

  /// Secret names Kamal reads from its secrets.
  final List<String> secrets;

  Map<String, Object?> toYaml() => {
    if (values.isNotEmpty) 'values': values,
    if (optionalValues.isNotEmpty) 'optional_values': optionalValues,
    if (secrets.isNotEmpty) 'secrets': secrets,
  };

  static DwKamalNeeds parse(Object? yaml) => yaml is Map
      ? DwKamalNeeds(
          values: _strings(yaml['values']),
          optionalValues: _strings(yaml['optional_values']),
          secrets: _strings(yaml['secrets']),
        )
      : const DwKamalNeeds();
}

/// An optional part of the stack that an environment either runs itself or
/// takes from outside.
class DwKamalComponent {
  const DwKamalComponent({
    required this.name,
    required this.provider,
    required this.bundled,
    required this.external,
  });

  final String name;

  /// What provides it where it is bundled: `{service: storage}` or
  /// `{service: api, accessory: postgres}`.
  final Map<String, String> provider;
  final DwKamalNeeds bundled;
  final DwKamalNeeds external;

  String get variable => DwStudioVariables.bundled(name);

  Map<String, Object?> toYaml() => {
    'variable': variable,
    'provider': provider,
    'bundled': bundled.toYaml(),
    'external': external.toYaml(),
  };
}

/// A public host of the stack, named by the environment.
class DwKamalIngress {
  const DwKamalIngress({
    required this.point,
    required this.service,
    this.component,
  });

  final String point;
  final String service;

  /// The component whose bundled mode needs this host, or null when every
  /// environment needs it.
  final String? component;

  String get variable => DwStudioVariables.domain(point);

  Map<String, Object?> toYaml() => {
    'variable': variable,
    'service': service,
    if (component != null) 'component': component,
  };
}

/// `deploy/studio.yml`: what any environment of this project must give.
class DwKamalManifest {
  const DwKamalManifest({
    required this.project,
    required this.services,
    required this.ingress,
    required this.components,
    required this.values,
    required this.secrets,
  });

  final String project;

  /// In deploy order. A service that provides a component is deployed only
  /// where that component is bundled.
  final List<String> services;
  final List<DwKamalIngress> ingress;
  final List<DwKamalComponent> components;

  /// Non-secret values every environment gives.
  final List<String> values;

  /// Secret names every environment gives, beyond its components' own.
  final List<String> secrets;

  static const path = 'deploy/studio.yml';

  static DwKamalManifest parse(String text) {
    final yaml = loadYaml(text);
    if (yaml is! Map || yaml['project'] is! String) {
      throw StateError(
        '$path: not an environment-free manifest. Regenerate it with '
        'dartway deploy kamal.',
      );
    }
    final ingress = yaml['ingress'];
    final components = yaml['components'];
    return DwKamalManifest(
      project: yaml['project'] as String,
      services: _strings(yaml['services']),
      ingress: [
        if (ingress is Map)
          for (final MapEntry(:key, :value) in ingress.entries)
            if (value is Map)
              DwKamalIngress(
                point: '$key',
                service: '${value['service']}',
                component: value['component'] as String?,
              ),
      ],
      components: [
        if (components is Map)
          for (final MapEntry(:key, :value) in components.entries)
            if (value is Map)
              DwKamalComponent(
                name: '$key',
                provider: {
                  for (final MapEntry(:key, :value)
                      in ((value['provider'] as Map?) ?? const {}).entries)
                    '$key': '$value',
                },
                bundled: DwKamalNeeds.parse(value['bundled']),
                external: DwKamalNeeds.parse(value['external']),
              ),
      ],
      values: _strings(yaml['values']),
      secrets: _strings(yaml['secrets']),
    );
  }

  static DwKamalManifest load(Directory projectRoot) {
    final file = File(p.join(projectRoot.path, path));
    if (!file.existsSync()) {
      throw StateError('No $path in ${projectRoot.path}.');
    }
    return parse(file.readAsStringSync());
  }

  DwKamalComponent? component(String name) =>
      components.where((component) => component.name == name).firstOrNull;

  /// What an environment with these [bundled] modes must give.
  DwKamalNeeds needs(Map<String, bool> bundled) => DwKamalNeeds(
    values: {
      ...values,
      for (final component in components)
        ...(bundled[component.name]! ? component.bundled : component.external)
            .values,
    }.toList(),
    optionalValues: {
      for (final component in components)
        ...(bundled[component.name]! ? component.bundled : component.external)
            .optionalValues,
    }.toList(),
    secrets: {
      ...secrets,
      for (final component in components)
        ...(bundled[component.name]! ? component.bundled : component.external)
            .secrets,
    }.toList(),
  );
}

/// One environment, as Studio describes it through its variables.
class DwKamalEnvironment {
  DwKamalEnvironment._({
    required this.name,
    required this.host,
    required this.sshUser,
    required this.domains,
    required this.bundled,
    required this.values,
    required this.needs,
  });

  final String name;
  final String host;
  final String sshUser;

  /// Ingress point → host, for the points this environment serves.
  final Map<String, String> domains;

  /// Component → whether this environment runs it itself.
  final Map<String, bool> bundled;

  /// The non-secret values the manifest asks for, as given.
  final Map<String, String> values;

  /// What the manifest asks of this environment, given its modes.
  final DwKamalNeeds needs;

  /// Reads environment [name] from [variables], every problem at once.
  ///
  /// [check] reads only what the outside probe needs (domains and modes), so
  /// the check image is not handed SSH coordinates or values it never uses.
  static DwKamalEnvironment resolve(
    DwKamalManifest manifest, {
    required String name,
    required Map<String, String> variables,
    bool check = false,
  }) {
    final problems = <String>[];
    if (!dwKamalEnvironmentPattern.hasMatch(name)) {
      problems.add(
        'environment "$name" must start with a lower case letter or digit and '
        'contain only lower case letters, digits, "_" and "-"',
      );
    }
    final declared = variables[DwStudioVariables.environment];
    if (declared != null && declared != name) {
      problems.add(
        '${DwStudioVariables.environment} is "$declared", not "$name"',
      );
    }
    String? required(String variable) {
      final value = variables[variable];
      if (value == null || value.isEmpty) {
        problems.add('$variable is not set');
        return null;
      }
      return value;
    }

    final bundled = <String, bool>{};
    for (final component in manifest.components) {
      // The outside probe needs a component's mode only where it changes
      // what answers in public: a host of its own.
      if (check &&
          !manifest.ingress.any((point) => point.component == component.name)) {
        continue;
      }
      final value = required(component.variable);
      if (value == null) continue;
      if (value != 'true' && value != 'false') {
        problems.add('${component.variable} is true or false, got "$value"');
      } else {
        bundled[component.name] = value == 'true';
      }
    }
    final domains = <String, String>{};
    for (final point in manifest.ingress) {
      final component = point.component;
      if (component != null && bundled[component] != true) continue;
      final domain = required(point.variable);
      if (domain == null) continue;
      if (!_hostName.hasMatch(domain)) {
        problems.add('${point.variable} "$domain" is not a host name');
      }
      domains[point.point] = domain;
    }
    // Until every mode is known, what every environment gives is still asked.
    final needs = bundled.length == manifest.components.length
        ? manifest.needs(bundled)
        : DwKamalNeeds(values: manifest.values, secrets: manifest.secrets);
    final host = check ? '' : required(DwStudioVariables.host);
    final sshUser = check ? '' : required(DwStudioVariables.sshUser);
    final values = <String, String>{
      if (!check)
        for (final name in needs.values)
          if (required(name) case final value?) name: value,
      if (!check)
        for (final name in needs.optionalValues)
          if (variables[name] case final value? when value.isNotEmpty)
            name: value,
    };
    if (problems.isNotEmpty) {
      throw StateError(
        'Environment "$name" is incomplete for ${DwKamalManifest.path}:\n'
        '${problems.map((line) => '  - $line').join('\n')}',
      );
    }
    return DwKamalEnvironment._(
      name: name,
      host: host!,
      sshUser: sshUser!,
      domains: domains,
      bundled: bundled,
      values: values,
      needs: needs,
    );
  }

  /// The target the shared checks read, for this environment of [project].
  DwDeployTarget target({
    required String projectName,
    String deployUser = DwDeployTarget.defaultDeployUser,
    List<String> requiredSecrets = const [],
    List<String> requiredSecretFiles = const [],
  }) => DwDeployTarget(
    environment: name,
    host: host,
    sshUser: sshUser,
    deployUser: deployUser,
    os: 'ubuntu',
    repo: '',
    branch: '',
    sslEmail: '',
    apiDomain: domains['api']!,
    appDomain: domains['app']!,
    project: projectName,
    database: bundled['database'] == false
        ? DwDatabaseMode.external
        : DwDatabaseMode.bundled,
    storage: switch (bundled['storage']) {
      null => DwStorageMode.none,
      true => DwStorageMode.bundled,
      false => DwStorageMode.external,
    },
    storageDomain: domains['files'],
    requiredSecrets: requiredSecrets,
    requiredSecretFiles: requiredSecretFiles,
    trustedProxyNetworks: [
      if (values[DwStack.trustedProxyNetworksKey] case final networks?)
        ...networks.split(',').map((network) => network.trim()),
    ],
  );

  /// The stack `deploy check` verifies for environment [name] of the project
  /// at [projectRoot], from the project's manifest and Studio's [variables].
  static DwStack stack({
    required Directory projectRoot,
    required DwKamalManifest manifest,
    required String name,
    required Map<String, String> variables,
    DwKamalProject? project,
    bool check = false,
  }) {
    final layout = ProjectLayout.detect(projectRoot);
    final environment = resolve(
      manifest,
      name: name,
      variables: variables,
      check: check,
    );
    return DwStack(
      target: environment.target(
        projectName: manifest.project,
        deployUser: project?.deployUser ?? DwDeployTarget.defaultDeployUser,
        requiredSecrets: project?.requiredSecrets ?? const [],
        requiredSecretFiles: project?.requiredSecretFiles ?? const [],
      ),
      projectRoot: projectRoot,
      serverPackage: layout.serverPackage,
      flutterPackage: layout.flutterPackage,
    );
  }

  static final RegExp _hostName = RegExp(
    r'^(?=.{1,253}$)([a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?\.)+'
    r'[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?$',
  );
}

List<String> _strings(Object? yaml) =>
    yaml is List ? [for (final item in yaml) '$item'] : const [];
