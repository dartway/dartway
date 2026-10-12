import 'dart:io';

import 'package:yaml/yaml.dart';

import '../checker/dw_check_type.dart';
import 'deploy_check.dart';
import 'deploy_target.dart';
import 'image_registry.dart';
import 'kamal.dart';
import 'kamal_runtime_inspection.dart';
import 'remote_checks.dart';
import 'secret_store.dart';
import 'stack.dart';

final List<DwDeployCheck> dwKamalLocalDeployChecks = [
  for (final check in dwLocalDeployChecks)
    if (check.id != 'nginx-upstreams' && check.id != 'override-web-build')
      check,
  DwDeployCheck(
    id: 'kamal-generated',
    title: 'Native deployment files match the project configuration',
    stage: DwDeployCheckStage.local,
    severity: DwCheckSeverity.error,
    evaluate: (context) async {
      try {
        final stale = DwKamalGenerator(
          context.projectRoot,
        ).generate(check: true);
        return stale.isEmpty
            ? const DwDeployVerdict.pass('Kamal contract is current')
            : DwDeployVerdict.fail(
                'stale native files: ${stale.join(', ')}',
                fix: 'Run dartway deploy kamal and commit the result.',
              );
      } on StateError catch (error) {
        return DwDeployVerdict.fail(error.message.toString());
      }
    },
  ),
];

final List<DwDeployCheck> dwKamalRemoteDeployChecks = [
  for (final check in dwRemoteDeployChecks)
    if (!const {
      'docker-available',
      'stack-identity',
      'proxy-congestion-control',
      'secret-files',
      'images-resolve',
    }.contains(check.id))
      check,
  DwDeployCheck(
    id: 'images-resolve',
    title: 'Every native base image resolves from its registry',
    stage: DwDeployCheckStage.remote,
    severity: DwCheckSeverity.error,
    evaluate: (context) => evaluateImagesResolve([
      ('native proxy', 'basecamp/kamal-proxy:v0.10.2'),
      if (context.target.database == DwDatabaseMode.bundled)
        ('native database', DwStack.postgresImage),
      if (context.target.storage == DwStorageMode.bundled)
        ('native storage', DwStack.storageImage),
    ], DwImageRegistry()),
  ),
  _nativeCheck('docker-available', 'Docker is usable by the deployment user', (
    context,
  ) async {
    final result = await context.ssh!.runAs(
      context.target.deployUser,
      'docker version --format "{{.Server.Version}}"',
    );
    return result.ok
        ? DwDeployVerdict.pass(result.stdout.trim())
        : const DwDeployVerdict.fail('Docker is unavailable');
  }),
  _nativeCheck(
    'stack-identity',
    'Selected native services run the selected SHA',
    (context) => context.kamal.checkServices(),
  ),
  _nativeCheck(
    'kamal-routing',
    'TLS routes point at those native containers',
    (context) => context.kamal.checkRouting(),
  ),
  _nativeCheck(
    'proxy-congestion-control',
    'The native proxy uses BBR',
    (context) => context.kamal.checkCongestion(),
  ),
  _nativeCheck(
    'secret-files',
    'Required files are mounted read-only in the running API',
    (context) => context.kamal.checkFiles(),
  ),
  _nativeCheck(
    'kamal-data-mounts',
    'Native data services use their declared mounts',
    (context) => context.kamal.checkData(),
  ),
  _nativeCheck(
    'kamal-proxy-trust',
    'Configured ingress trust includes the native network',
    (context) => context.kamal.checkTrust(),
  ),
];

DwDeployCheck _nativeCheck(
  String name,
  String title,
  Future<DwDeployVerdict> Function(DwDeployContext) evaluate,
) => DwDeployCheck(
  id: name,
  title: title,
  stage: DwDeployCheckStage.remote,
  severity: DwCheckSeverity.error,
  requiresSsh: true,
  evaluate: (context) async {
    try {
      return await evaluate(context);
    } on StateError catch (error) {
      return DwDeployVerdict.fail(error.message.toString());
    } on FormatException {
      return const DwDeployVerdict.fail('Invalid native runtime metadata');
    } on TypeError {
      return const DwDeployVerdict.fail(
        'Invalid native runtime metadata types',
      );
    }
  },
);

/// The desired native contract comes from the generator, never from the
/// previous Compose files. One projected runtime snapshot is shared by checks.
final class DwKamalRuntime {
  DwKamalRuntime(this.context);
  final DwDeployContext context;
  late final Map<String, String> _files = DwKamalGenerator(
    context.projectRoot,
  ).render();
  late final Future<String> version = _version();
  late final Future<DwKamalRuntimeState> _state = _read();
  late final String _destination =
      DwKamalGenerator.destinations[context.target.environment]!;
  Map get _manifest => loadYaml(_files['deploy/studio.yml']!) as Map;
  List<String> get _services => (_manifest['services'] as List).cast<String>();
  Map _base(String service) =>
      loadYaml(_files['deploy/kamal/$service.yml']!) as Map;
  Map _target(String service) =>
      loadYaml(_files['deploy/kamal/$service.$_destination.yml']!) as Map;
  String _identity(String service) => _base(service)['service'] as String;
  String _role(String service) =>
      (_target(service)['servers'] as Map).keys.single as String;
  String get _postgres =>
      ((_target('api')['accessories'] as Map)['postgres'] as Map)['service']
          as String;

  Future<String> _version() async {
    var selected = context.version;
    if (selected == null) {
      final git = await Process.run('git', [
        'rev-parse',
        'HEAD',
      ], workingDirectory: context.projectRoot.path);
      if (git.exitCode == 0) selected = git.stdout.toString().trim();
    }
    if (selected == null || !RegExp(r'^[0-9a-f]{40}$').hasMatch(selected)) {
      throw StateError(
        'Native checks require --version <full SHA> or a Git checkout.',
      );
    }
    return selected;
  }

  Future<DwKamalRuntimeState> _read() async {
    await version;
    final services = [
      for (final service in _services) _identity(service),
      if (context.target.database == DwDatabaseMode.bundled) _postgres,
    ];
    final result = await context.ssh!.runAs(
      context.target.deployUser,
      nativeKamalInspectionScript(services),
    );
    if (!result.ok)
      throw StateError(
        'Cannot inspect the native Kamal stack: ${result.firstLine}',
      );
    return DwKamalRuntimeState.parse(result.stdout);
  }

  List<DwKamalContainerInfo> _running(
    DwKamalRuntimeState state,
    String identity, {
    bool accessory = false,
  }) => state.containers
      .where(
        (container) =>
            container.service == identity &&
            container.running &&
            (accessory || container.destination == _destination),
      )
      .toList();

  Future<DwKamalContainerInfo?> _selected(
    DwKamalRuntimeState state,
    String service,
  ) async {
    final expected = 'ghcr.io/${_base(service)['image']}:${await version}';
    final matching = _running(state, _identity(service))
        .where(
          (container) =>
              container.image == expected &&
              container.role == _role(service) &&
              container.healthy,
        )
        .toList();
    return matching.length == 1 ? matching.single : null;
  }

  Future<DwDeployVerdict> checkServices() async {
    final state = await _state;
    final missing = <String>[];
    for (final service in _services) {
      if (await _selected(state, service) == null) missing.add(service);
    }
    return missing.isEmpty
        ? DwDeployVerdict.pass(
            '${_services.length} native services at ${await version}',
          )
        : DwDeployVerdict.fail(
            'missing, unhealthy or ambiguous native SHA for: ${missing.join(', ')}',
          );
  }

  Future<DwDeployVerdict> checkRouting() async {
    final state = await _state;
    for (final service in _services) {
      final container = await _selected(state, service);
      final route =
          state.routes['${_identity(service)}-${_role(service)}-$_destination'];
      final port = (_base(service)['proxy'] as Map)['app_port'] as int;
      final hosts = (_target(service)['proxy'] as Map)['hosts'] as List;
      final routeName = '${_identity(service)}-${_role(service)}-$_destination';
      if (state.routes.entries.any(
        (entry) =>
            entry.key != routeName &&
            entry.value is Map &&
            (entry.value as Map)['hosts'] is List &&
            ((entry.value as Map)['hosts'] as List).any(hosts.contains),
      )) {
        return DwDeployVerdict.fail(
          'Another native service also claims the hosts of $service.',
        );
      }
      if (container == null ||
          route is! Map ||
          route['state'] != 'running' ||
          route['tls'] != true ||
          !_same(route['hosts'], hosts) ||
          (route['read_targets'] as List).isNotEmpty ||
          (route['rollout'] as Map)['enabled'] != false ||
          (route['targets'] as List).length != 1 ||
          !container.isTarget(
            (route['targets'] as List).single as String,
            port,
          ) ||
          (route['path_prefixes'] as List).any((path) => path != '/')) {
        return DwDeployVerdict.fail(
          'Native TLS route for $service does not select the expected container.',
        );
      }
    }
    return const DwDeployVerdict.pass(
      'native hosts, TLS and active targets match',
    );
  }

  Future<DwDeployVerdict> checkCongestion() async =>
      (await _state).congestion == 'bbr'
      ? const DwDeployVerdict.pass('bbr in kamal-proxy network namespace')
      : const DwDeployVerdict.fail(
          'kamal-proxy is not using BBR; configure and reboot the native proxy.',
        );

  Future<DwDeployVerdict> checkFiles() async {
    final api = await _selected(await _state, 'api');
    if (api == null)
      return const DwDeployVerdict.fail(
        'The selected native API is not running.',
      );
    for (final name in context.target.requiredSecretFiles) {
      final mounts = api.mounts.where(
        (mount) => mount.destination == '${DwStack.secretFilesDir}/$name',
      );
      if (mounts.length != 1 ||
          mounts.single.type != 'bind' ||
          mounts.single.writable ||
          mounts.single.source != '${context.target.runtimeConfigDir}/$name') {
        return DwDeployVerdict.fail(
          'Native API file $name lacks its per-file read-only mount.',
        );
      }
    }
    if (api.mounts.any(
      (mount) =>
          mount.destination == DwStack.secretFilesDir ||
          mount.destination ==
              '${DwStack.secretFilesDir}/${DwSecretStore.fileName}',
    )) {
      return const DwDeployVerdict.fail(
        'The native API mounts the whole secret store.',
      );
    }
    return DwDeployVerdict.pass(
      '${context.target.requiredSecretFiles.length} native file mounts verified',
    );
  }

  Future<DwDeployVerdict> checkData() async {
    final state = await _state;
    if (_services.contains('storage')) {
      final volume = ((_target('storage')['volumes'] as List).single as String)
          .split(':')
          .first;
      final storage = await _selected(state, 'storage');
      if (storage == null ||
          !storage.mounts.any(
            (mount) =>
                mount.type == 'volume' &&
                mount.name == volume &&
                mount.destination == '/data' &&
                mount.writable,
          )) {
        return const DwDeployVerdict.fail(
          'Native storage is not using its declared data volume.',
        );
      }
    }
    if (context.target.database == DwDatabaseMode.bundled) {
      final database = _running(state, _postgres, accessory: true);
      if (database.length != 1 ||
          !database.single.healthy ||
          database.single.image != 'postgres:17-alpine' ||
          !database.single.mounts.any(
            (mount) =>
                mount.type == 'bind' &&
                mount.writable &&
                mount.destination == '/var/lib/postgresql/data' &&
                mount.source.endsWith('/$_postgres/postgres'),
          )) {
        return const DwDeployVerdict.fail(
          'Native Postgres is not using its declared data directory.',
        );
      }
    }
    return const DwDeployVerdict.pass(
      'native data mounts verified; data integrity requires a backup restore proof',
    );
  }

  Future<DwDeployVerdict> checkTrust() async {
    if (context.target.trustedProxyNetworks.isEmpty) {
      return const DwDeployVerdict.fail(
        'Declare trusted_proxy_networks for the native ingress before deployment.',
      );
    }
    final state = await _state;
    if (state.subnets.isEmpty ||
        !state.subnets.every(context.target.trustedProxyNetworks.contains)) {
      return const DwDeployVerdict.fail(
        'trusted_proxy_networks must include the actual kamal network subnets.',
      );
    }
    return const DwDeployVerdict.pass('native network is explicitly trusted');
  }

  static bool _same(Object? actual, List expected) =>
      actual is List &&
      actual.length == expected.length &&
      actual.toSet().containsAll(expected);
}
