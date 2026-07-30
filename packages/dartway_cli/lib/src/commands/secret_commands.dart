import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

import '../deploy/deploy_target.dart';
import '../deploy/master_passwords_file.dart';
import '../deploy/secret_store.dart';
import '../deploy/serverpod_config.dart';
import '../deploy/ssh_runner.dart';
import '../project_layout.dart';

/// Manages the runtime secret store on a deployment target.
class SecretCommand extends Command<int> {
  SecretCommand() {
    addSubcommand(SecretPushCommand());
    addSubcommand(SecretPullCommand());
    addSubcommand(SecretInitCommand());
    addSubcommand(SecretSetCommand());
    addSubcommand(SecretPutFileCommand());
    addSubcommand(SecretListCommand());
  }

  @override
  String get name => 'secret';

  @override
  String get description =>
      'Manage runtime secrets on the server; values never touch this machine.';
}

/// Shared plumbing: every secret command names an environment and connects.
abstract class _SecretCommandBase extends Command<int> {
  _SecretCommandBase() {
    argParser
      ..addOption('env', help: 'Environment declared in deploy/config.yaml.')
      ..addOption(
        'as',
        help: 'SSH login. Defaults to ssh_user from the config.',
      )
      ..addOption('identity', help: 'SSH private key file.');
  }

  late final Directory projectRoot = Directory.current;

  DwDeployTarget resolveTarget(ArgResults results) {
    final environment = results.option('env');
    if (environment == null) {
      final known = DwDeployTarget.environmentsIn(projectRoot);
      usageException(
        'Specify --env.'
        '${known.isEmpty ? '' : ' Declared: ${known.join(', ')}.'}',
      );
    }
    return DwDeployTarget.load(
      projectRoot: projectRoot,
      environment: environment,
    );
  }

  DwSecretStore openStore(DwDeployTarget target, ArgResults results) {
    return DwSecretStore(
      ssh: DwSshRunner(
        host: target.host,
        user: results.option('as') ?? target.sshUser,
        identityFile: results.option('identity'),
      ),
      target: target,
    );
  }
}

/// Sends the environment's slice of the local master file to its server.
///
/// The local `passwords.yaml` holds every environment and is the copy the
/// maintainer keeps; each server receives only `shared` plus its own section,
/// which is exactly what Serverpod merges at startup.
class SecretPushCommand extends _SecretCommandBase {
  SecretPushCommand() {
    argParser
      ..addFlag(
        'prune',
        negatable: false,
        help: 'Allow dropping keys that exist on the server but not locally.',
      )
      ..addFlag(
        'allow-emptying',
        negatable: false,
        help: 'Allow replacing a value the server has with an empty one.',
      )
      ..addFlag(
        'dry-run',
        negatable: false,
        help: 'Report what would be sent, send nothing.',
      );
  }

  @override
  String get name => 'push';

  @override
  String get description =>
      'Upload shared plus this environment from the local passwords.yaml.';

  @override
  String get invocation =>
      'dartway deploy secret push --env <environment> [--dry-run] [--prune]';

  @override
  Future<int> run() async {
    final results = argResults!;
    final target = resolveTarget(results);
    final store = openStore(target, results);
    final layout = ProjectLayout.detect(projectRoot);

    final file = File(
      p.join(
        projectRoot.path,
        layout.serverPackage,
        'config',
        'passwords.yaml',
      ),
    );
    if (!file.existsSync()) {
      stderr.writeln('No ${layout.serverPackage}/config/passwords.yaml.');
      return 1;
    }

    final document = loadYaml(file.readAsStringSync());
    if (document is! YamlMap) {
      stderr.writeln('passwords.yaml must be a map of sections.');
      return 1;
    }

    final sections = <String, Map<String, String>>{};
    for (final name in ['shared', target.environment]) {
      final section = document[name];
      if (section == null) {
        continue;
      }
      if (section is! YamlMap) {
        stderr.writeln('Section "$name" must be a map.');
        return 1;
      }
      sections[name] = {
        for (final entry in section.entries)
          entry.key.toString(): entry.value?.toString() ?? '',
      };
    }

    if (!sections.containsKey(target.environment)) {
      stderr.writeln(
        'No "${target.environment}" section in passwords.yaml — nothing to '
        'push.',
      );
      return 1;
    }

    final localKeys = sections.values.expand((s) => s.keys).toSet();
    final remote = await store.readKeyNames(
      sections: ['shared', target.environment],
    );
    final orphaned = remote.ok
        ? (remote.names.difference(localKeys).toList()..sort())
        : const <String>[];

    stdout.writeln('Push to ${store.passwordsFile}');
    for (final section in sections.entries) {
      final keys = section.value.keys.toList()..sort();
      stdout.writeln('  ${section.key}: ${keys.join(', ')}');
    }

    if (orphaned.isNotEmpty && !results.flag('prune')) {
      stderr.writeln(
        'Refusing to push: the server holds keys this file does not — '
        '${orphaned.join(', ')}.\n'
        'Add them locally, or pass --prune to drop them.',
      );
      return 1;
    }
    if (orphaned.isNotEmpty) {
      stdout.writeln('  dropping: ${orphaned.join(', ')}');
    }

    // A key can be present on both sides and still lose its value: the local
    // file may hold a placeholder where the server holds the real thing.
    // Comparing key names alone never notices, and the result is a service
    // that starts and quietly does nothing.
    final effectiveLocal = DwMasterPasswordsFile.effective(
      sections,
      target.environment,
    );
    final remoteNonEmpty = await store.readNonEmptyKeyNames(
      sections: ['shared', target.environment],
    );
    // A guard that reads the server is useless if the read silently failed.
    // When the store exists but could not be inspected, refuse rather than
    // assume there is nothing to lose.
    if (remote.ok && !remoteNonEmpty.ok) {
      stderr.writeln(
        'Refusing to push: the server has a store but its contents could not '
        'be read (${remoteNonEmpty.error}). Without that, this command cannot '
        'tell whether it would destroy a live value.',
      );
      return 1;
    }

    final wouldEmpty =
        remoteNonEmpty.names
            .where((key) => (effectiveLocal[key] ?? '').isEmpty)
            .toList()
          ..sort();

    if (wouldEmpty.isNotEmpty && !results.flag('allow-emptying')) {
      stderr.writeln(
        'Refusing to push: this would blank values the server has — '
        '${wouldEmpty.join(', ')}.\n'
        'Fill them locally, take the server values with "dartway deploy '
        'secret pull", or pass --allow-emptying to overwrite them anyway.',
      );
      return 1;
    }
    if (wouldEmpty.isNotEmpty) {
      stdout.writeln('  emptying: ${wouldEmpty.join(', ')}');
    }

    if (results.flag('dry-run')) {
      stdout.writeln('Dry run — nothing sent.');
      return 0;
    }

    final written = await store.writeSections(sections);
    if (!written.ok) {
      stderr.writeln('Push failed: ${written.firstLine}');
      return 1;
    }

    final empty = sections.values
        .expand((s) => s.entries)
        .where((entry) => entry.value.isEmpty)
        .map((entry) => entry.key)
        .toList();

    stdout.writeln('Pushed ${localKeys.length} keys.');
    if (empty.isNotEmpty) {
      stdout.writeln(
        'Stored empty: ${empty.join(', ')} — present, so code reading them '
        'will not throw, but they carry no value.',
      );
    }
    stdout.writeln(
      'A running container keeps the file it already mounted; the values take '
      'effect on the next deploy.',
    );
    return 0;
  }
}

/// Brings the server's slice back into the local master file.
///
/// The counterpart to `push`, and the way an already-running project is
/// adopted: whatever the server holds becomes the starting point for the file
/// that will govern it from then on.
class SecretPullCommand extends _SecretCommandBase {
  SecretPullCommand() {
    argParser.addFlag(
      'dry-run',
      negatable: false,
      help: 'Report what would change, write nothing.',
    );
  }

  @override
  String get name => 'pull';

  @override
  String get description =>
      'Copy keys the server has and the local passwords.yaml lacks into it.';

  @override
  String get invocation =>
      'dartway deploy secret pull --env <environment> [--dry-run]';

  @override
  Future<int> run() async {
    final results = argResults!;
    final target = resolveTarget(results);
    final store = openStore(target, results);
    final layout = ProjectLayout.detect(projectRoot);
    final master = DwMasterPasswordsFile(
      File(
        p.join(
          projectRoot.path,
          layout.serverPackage,
          'config',
          'passwords.yaml',
        ),
      ),
    );

    final remoteRead = await store.readFile();
    if (!remoteRead.ok) {
      stderr.writeln(
        'Cannot read ${store.passwordsFile}: ${remoteRead.firstLine}',
      );
      return 1;
    }
    final remoteDocument = loadYaml(remoteRead.stdout);
    if (remoteDocument is! YamlMap) {
      stderr.writeln('The server file is not a map of sections.');
      return 1;
    }

    final wanted = ['shared', target.environment];
    final remote = <String, Map<String, String>>{};
    for (final name in wanted) {
      final section = remoteDocument[name];
      if (section is YamlMap) {
        remote[name] = {
          for (final entry in section.entries)
            entry.key.toString(): entry.value?.toString() ?? '',
        };
      }
    }

    final local = master.read() ?? const <String, Map<String, String>>{};

    final localEffective = DwMasterPasswordsFile.effective(
      local,
      target.environment,
    );
    final remoteEffective = DwMasterPasswordsFile.effective(
      remote,
      target.environment,
    );

    final additions = <String, String>{};
    final differing = <String>[];
    for (final entry in remoteEffective.entries) {
      final localValue = localEffective[entry.key];
      // A local placeholder carries no information, so it is treated as an
      // absent key rather than a conflicting one — this is how a file whose
      // keys were written before their values gets filled in.
      final localIsPlaceholder = localValue == null || localValue.isEmpty;
      if (localIsPlaceholder && entry.value.isNotEmpty) {
        additions[entry.key] = entry.value;
      } else if (localValue == null) {
        additions[entry.key] = entry.value;
      } else if (localValue != entry.value) {
        differing.add(entry.key);
      }
    }
    final localOnly =
        localEffective.keys
            .where((key) => !remoteEffective.containsKey(key))
            .toList()
          ..sort();

    final addedCount = additions.length;

    stdout.writeln('Compare ${store.passwordsFile} with ${master.file.path}');
    if (addedCount == 0) {
      stdout.writeln('  nothing to add');
    } else {
      final keys = additions.keys.toList()..sort();
      // Additions land in the environment section, never in "shared": a key
      // added to "shared" would also start resolving for development and test.
      stdout.writeln('  add to ${target.environment}: ${keys.join(', ')}');
    }
    if (differing.isNotEmpty) {
      differing.sort();
      stdout.writeln('  values differ: ${differing.join(', ')}');
    }
    if (localOnly.isNotEmpty) {
      stdout.writeln('  local only: ${localOnly.join(', ')}');
    }

    if (differing.isNotEmpty) {
      stdout.writeln(
        'Differing values are reported, never rewritten — the local file is '
        'the one you maintain. Resolve them by hand, or overwrite the server '
        'with "dartway deploy secret push".',
      );
    }

    if (addedCount == 0) {
      return 0;
    }
    if (results.flag('dry-run')) {
      stdout.writeln('Dry run — nothing written.');
      return 0;
    }
    if (!master.exists) {
      stderr.writeln(
        'No ${layout.serverPackage}/config/passwords.yaml to write into.',
      );
      return 1;
    }

    master.write({target.environment: additions});
    stdout
      ..writeln('Added $addedCount key(s) to ${master.file.path}.')
      ..writeln(
        'This file now holds secrets for ${target.environment}; keep it out '
        'of Git and backed up somewhere you control.',
      );
    return 0;
  }
}

/// Creates the store and fills in the keys that can be generated.
class SecretInitCommand extends _SecretCommandBase {
  @override
  String get name => 'init';

  @override
  String get description =>
      'Create the secret store and generate the keys that are just random '
      'strings. Existing values are never replaced.';

  @override
  String get invocation => 'dartway deploy secret init --env <environment>';

  @override
  Future<int> run() async {
    final results = argResults!;
    final target = resolveTarget(results);
    final store = openStore(target, results);

    final layout = ProjectLayout.detect(projectRoot);
    final serverpod = DwServerpodConfig.load(
      projectRoot: projectRoot,
      serverPackage: layout.serverPackage,
      environment: target.environment,
    );

    final keys = [
      ...DwSecretStore.generatedKeys,
      if (serverpod.managesRedis) 'redis',
    ];

    final created = await store.ensureDirectory();
    if (!created.ok) {
      stderr.writeln('Cannot create ${store.directory}: ${created.firstLine}');
      return 1;
    }

    final before = await store.readKeyNames(sections: [target.environment]);
    final generated = await store.generateMissing(
      section: target.environment,
      keys: keys,
    );
    if (!generated.ok) {
      stderr.writeln('Generation failed: ${generated.firstLine}');
      return 1;
    }
    final after = await store.readKeyNames(sections: [target.environment]);

    final added = after.names.difference(before.names).toList()..sort();
    stdout
      ..writeln('Secret store: ${store.directory}')
      ..writeln(
        added.isEmpty
            ? 'Nothing to generate — all ${keys.length} keys already present.'
            : 'Generated: ${added.join(', ')}',
      );

    final outstanding = target.requiredSecrets
        .where((key) => !after.names.contains(key))
        .toList();
    if (outstanding.isNotEmpty) {
      stdout.writeln(
        'Still to deliver by hand: ${outstanding.join(', ')} '
        '(dartway deploy secret set <key> --env ${target.environment})',
      );
    }
    return 0;
  }
}

/// Writes one secret, reading the value from stdin.
class SecretSetCommand extends _SecretCommandBase {
  SecretSetCommand() {
    argParser.addOption(
      'section',
      help:
          'Passwords section to write to. Defaults to the environment; '
          'use "shared" for values common to every run mode.',
    );
  }

  @override
  String get name => 'set';

  @override
  String get description =>
      'Store a secret on the server. The value is read from stdin so it never '
      'appears in shell history or a process list.';

  @override
  String get invocation =>
      'dartway deploy secret set <key> --env <environment> [--section shared]';

  @override
  Future<int> run() async {
    final results = argResults!;
    if (results.rest.length != 1) {
      usageException('Name exactly one key to set.');
    }
    final key = results.rest.single;
    final target = resolveTarget(results);
    final store = openStore(target, results);
    final section = results.option('section') ?? target.environment;

    if (stdin.hasTerminal) {
      final endOfInput = Platform.isWindows ? 'Ctrl+Z then Enter' : 'Ctrl+D';
      stdout.writeln('Reading the value from stdin; end with $endOfInput.');
    }
    final value = utf8.decode(await _readAllStdin()).trim();
    if (value.isEmpty) {
      stderr.writeln('Refusing to store an empty value for "$key".');
      return 1;
    }

    final written = await store.setSecret(
      section: section,
      key: key,
      value: value,
    );
    if (!written.ok) {
      stderr.writeln('Failed to store "$key": ${written.firstLine}');
      return 1;
    }

    stdout
      ..writeln('Stored "$key" under "$section" in ${store.passwordsFile}.')
      ..writeln(
        'A running container keeps the file it already mounted; the value '
        'takes effect on the next deploy.',
      );
    return 0;
  }

  Future<List<int>> _readAllStdin() async {
    final bytes = <int>[];
    await for (final chunk in stdin) {
      bytes.addAll(chunk);
    }
    return bytes;
  }
}

/// Uploads a secret file into the store.
class SecretPutFileCommand extends _SecretCommandBase {
  SecretPutFileCommand() {
    argParser.addOption(
      'name',
      help: 'Name to store the file under. Defaults to its basename.',
    );
  }

  @override
  String get name => 'put-file';

  @override
  String get description =>
      'Upload a secret file (service account JSON and similar) to the server.';

  @override
  String get invocation =>
      'dartway deploy secret put-file <path> --env <environment>';

  @override
  Future<int> run() async {
    final results = argResults!;
    if (results.rest.length != 1) {
      usageException('Name exactly one file to upload.');
    }
    final local = File(results.rest.single);
    if (!local.existsSync()) {
      stderr.writeln('No such file: ${local.path}');
      return 1;
    }

    final target = resolveTarget(results);
    final store = openStore(target, results);
    final name = results.option('name') ?? p.basename(local.path);

    final uploaded = await store.putFile(local, name: name);
    if (!uploaded.ok) {
      stderr.writeln('Upload failed: ${uploaded.firstLine}');
      return 1;
    }
    stdout.writeln('Stored ${store.directory}/$name (mode 0600).');
    return 0;
  }
}

/// Lists what the store holds, by name only.
class SecretListCommand extends _SecretCommandBase {
  @override
  String get name => 'list';

  @override
  String get description =>
      'List stored secret names and files. Values are never read.';

  @override
  String get invocation => 'dartway deploy secret list --env <environment>';

  @override
  Future<int> run() async {
    final results = argResults!;
    final target = resolveTarget(results);
    final store = openStore(target, results);

    final shared = await store.readKeyNames(sections: const ['shared']);
    final scoped = await store.readKeyNames(sections: [target.environment]);
    final files = await store.listFiles();

    if (!shared.ok && !scoped.ok) {
      stderr.writeln('No readable store at ${store.directory}.');
      return 1;
    }

    stdout.writeln('Store: ${store.directory}');
    _writeSection('shared', shared.names);
    _writeSection(target.environment, scoped.names);

    final secretFiles = files
        .where((name) => name != 'passwords.yaml')
        .toList();
    stdout.writeln(
      secretFiles.isEmpty
          ? '  files: none'
          : '  files: ${secretFiles.join(', ')}',
    );
    return 0;
  }

  void _writeSection(String title, Set<String> names) {
    final sorted = names.toList()..sort();
    stdout.writeln(
      sorted.isEmpty ? '  $title: empty' : '  $title: ${sorted.join(', ')}',
    );
  }
}
