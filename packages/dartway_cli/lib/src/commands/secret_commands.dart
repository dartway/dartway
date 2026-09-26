import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;

import '../deploy/deploy_target.dart';
import '../deploy/local_environment.dart';
import '../deploy/local_secrets_file.dart';
import '../deploy/secret_store.dart';
import '../deploy/ssh_runner.dart';
import '../deploy/stack.dart';
import 'deploy_command.dart';

/// Manages the secrets of every environment: the store on a deployed server,
/// and the `local` environment on this machine.
class SecretCommand extends Command<int> {
  SecretCommand() {
    addSubcommand(SecretInitCommand());
    addSubcommand(SecretSetCommand());
    addSubcommand(SecretListCommand());
    addSubcommand(SecretPutFileCommand());
    addSubcommand(SecretPushCommand());
    addSubcommand(SecretPullCommand());
  }

  @override
  String get name => 'secret';

  @override
  String get description =>
      'Manage the secrets of an environment — a server, or "local" on this '
      'machine. Values are never printed.';
}

/// Shared plumbing: every secret command names an environment and connects.
abstract class _SecretCommandBase extends Command<int> {
  _SecretCommandBase() {
    argParser
      ..addOption(
        'env',
        help:
            'Environment declared in deploy/config.yaml, or "local" for this '
            'machine.',
      )
      ..addOption(
        'as',
        help: 'SSH login. Defaults to ssh_user from the config.',
      )
      ..addOption('identity', help: 'SSH private key file.');
  }

  late final Directory projectRoot = deployProjectRoot();

  /// Whether this call is about the developer's own machine rather than a
  /// server. `local` is an environment like any other here; it is only the
  /// storage and the delivery that differ, and both are files.
  bool get isLocal => argResults!.option('env') == DwDeployTarget.localSection;

  DwLocalEnvironment get localEnvironment => DwLocalEnvironment(projectRoot);

  /// Says why a command that only a server can answer was refused.
  int refuseLocal(String because) {
    stderr.writeln('"${DwDeployTarget.localSection}" $because');
    return 1;
  }

  DwStack resolveStack(ArgResults results) =>
      resolveDeployStack(this, results, projectRoot);

  DwSecretStore openStore(DwStack stack, ArgResults results) => DwSecretStore(
    ssh: DwSshRunner(
      host: stack.target.host,
      user: results.option('as') ?? stack.target.sshUser,
      identityFile: results.option('identity'),
    ),
    target: stack.target,
  );
}

/// Creates the store and generates the secrets that are only random strings.
class SecretInitCommand extends _SecretCommandBase {
  @override
  String get name => 'init';

  @override
  String get description =>
      'Create the secret store and generate the database password (and the '
      'storage keys). Existing values are never replaced.';

  @override
  String get invocation => 'dartway secret init --env <environment>';

  @override
  Future<int> run() async {
    final results = argResults!;
    if (isLocal) {
      return refuseLocal(
        'generates nothing. Its database and storage coordinates are '
        'committed in ${DwLocalEnvironment.configPath} > '
        '${DwLocalEnvironment.section}, where everyone on the team reads the '
        'same ones; what is yours alone goes in with "dartway secret set '
        '<KEY> --env ${DwLocalEnvironment.section}".',
      );
    }
    final stack = resolveStack(results);
    final store = openStore(stack, results);

    final created = await store.ensureDirectory();
    if (!created.ok) {
      stderr.writeln('Cannot create ${store.directory}: ${created.firstLine}');
      return 1;
    }
    final generated = await store.generateMissing(stack.generatedSecrets);
    if (!generated.ok) {
      stderr.writeln('Generation failed: ${generated.firstLine}');
      return 1;
    }
    final names = generated.stdout
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();

    // Read back rather than trusted: the generator's own report is a claim,
    // the store is the fact.
    final filled = await store.readNonEmptyKeyNames();
    final notFilled = stack.generatedSecrets.keys
        .where((key) => !filled.names.contains(key))
        .toList();
    if (notFilled.isNotEmpty) {
      stderr.writeln(
        'The store still lacks a value for ${notFilled.join(', ')} after '
        'generation. An existing empty value is never replaced — remove the '
        'line from ${store.file} or set it with "dartway secret set".',
      );
      return 1;
    }

    stdout
      ..writeln('Secret store: ${store.file}')
      ..writeln(
        names.isEmpty
            ? 'Nothing to generate — ${stack.generatedSecrets.length} key(s) '
                  'already present.'
            : 'Generated: ${names.join(', ')}',
      );

    final outstanding = stack.requiredSecretKeys
        .where((key) => !filled.names.contains(key))
        .toList();
    if (outstanding.isNotEmpty) {
      stdout.writeln(
        'Still to deliver by hand: ${outstanding.join(', ')} '
        '(dartway secret set <KEY> --env ${stack.target.environment})',
      );
    }
    return 0;
  }
}

/// Writes one secret, reading the value from stdin.
class SecretSetCommand extends _SecretCommandBase {
  @override
  String get name => 'set';

  @override
  String get description =>
      'Store a secret on the server. The value is read from stdin so it never '
      'appears in shell history or a process list.';

  @override
  String get invocation => 'dartway secret set <KEY> --env <environment>';

  @override
  Future<int> run() async {
    final results = argResults!;
    if (results.rest.length != 1) {
      usageException('Name exactly one key to set.');
    }
    final key = results.rest.single;
    if (isLocal) return _storeLocally(key);
    final stack = resolveStack(results);
    if (stack.reservedSecretKeys.contains(key)) {
      stderr.writeln(
        'Refusing to store $key: the compose file sets it from '
        'deploy/config.yaml, and that value would override this one.',
      );
      return 1;
    }
    final store = openStore(stack, results);

    if (stdin.hasTerminal) {
      final endOfInput = Platform.isWindows ? 'Ctrl+Z then Enter' : 'Ctrl+D';
      stdout.writeln('Reading the value from stdin; end with $endOfInput.');
    }
    final value = utf8.decode(await _readAllStdin()).trim();
    if (value.isEmpty) {
      stderr.writeln('Refusing to store an empty value for "$key".');
      return 1;
    }

    final DwSshResult written;
    try {
      written = await store.setSecret(key: key, value: value);
    } on DwSecretFormatException catch (error) {
      stderr.writeln('Refusing to store "$key": ${error.message}');
      return 1;
    }
    if (!written.ok) {
      stderr.writeln('Failed to store "$key": ${written.firstLine}');
      return 1;
    }

    final filled = await store.readNonEmptyKeyNames();
    if (!filled.names.contains(key)) {
      stderr.writeln(
        'The write reported success and ${store.file} holds no value for '
        '$key. Nothing that reads the store will see it.',
      );
      return 1;
    }

    stdout
      ..writeln('Stored $key in ${store.file}.')
      ..writeln(
        'A running server keeps the environment it started with; the value '
        'takes effect on the next deploy.',
      );
    return 0;
  }

  /// Writes one value into `deploy/secrets.yaml` > `local`.
  ///
  /// The value is read from stdin here too: a local machine is not a reason
  /// for a key to land in the shell history, which is a file that outlives
  /// the project.
  Future<int> _storeLocally(String key) async {
    if (!dwIsSecretKeyName(key)) {
      stderr.writeln(
        '"$key" is not a secret name: upper case letters, digits and '
        'underscores, not starting with a digit or with COMPOSE_.',
      );
      return 1;
    }
    if (stdin.hasTerminal) {
      final endOfInput = Platform.isWindows ? 'Ctrl+Z then Enter' : 'Ctrl+D';
      stdout.writeln('Reading the value from stdin; end with $endOfInput.');
    }
    final value = utf8.decode(await _readAllStdin()).trim();
    if (value.isEmpty) {
      stderr.writeln('Refusing to store an empty value for "$key".');
      return 1;
    }

    localEnvironment.store(key, value);
    final stored = localEnvironment.mine[key];
    if (stored != value) {
      stderr.writeln(
        'The write reported success and ${DwLocalEnvironment.secretsPath} > '
        '${DwLocalEnvironment.section} does not hold $key.',
      );
      return 1;
    }

    stdout.writeln(
      'Stored $key in ${DwLocalEnvironment.secretsPath} > '
      '${DwLocalEnvironment.section}.',
    );
    if (localEnvironment.committed.containsKey(key)) {
      stdout.writeln(
        'It also has a value in ${DwLocalEnvironment.configPath}; yours wins.',
      );
    }
    stdout.writeln('A running server keeps the environment it started with.');
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

/// Lists what the store holds, by name only.
class SecretListCommand extends _SecretCommandBase {
  @override
  String get name => 'list';

  @override
  String get description =>
      'List stored secret names and files. Values are never read.';

  @override
  String get invocation => 'dartway secret list --env <environment>';

  @override
  Future<int> run() async {
    final results = argResults!;
    if (isLocal) return _listLocal();
    final stack = resolveStack(results);
    final store = openStore(stack, results);

    final names = await store.readKeyNames();
    if (!names.ok) {
      stderr.writeln(
        'No readable store at ${store.file}: ${names.error}. '
        'Create it with "dartway secret init".',
      );
      return 1;
    }
    final filled = await store.readNonEmptyKeyNames();
    final files = await store.listFiles();

    stdout.writeln('Store: ${store.file}');
    final sorted = names.names.toList()..sort();
    for (final key in sorted) {
      final notes = [
        if (!filled.names.contains(key)) 'empty',
        if (stack.requiredSecretKeys.contains(key)) 'required',
        if (stack.generatedSecrets.containsKey(key)) 'generated',
        if (stack.reservedSecretKeys.contains(key))
          'REFUSED by the deploy: set by the compose file',
      ];
      stdout.writeln('  $key${notes.isEmpty ? '' : '  (${notes.join(', ')})'}');
    }
    final missing = stack.requiredSecretKeys
        .where((key) => !names.names.contains(key))
        .toList();
    if (missing.isNotEmpty) {
      stdout.writeln('  missing: ${missing.join(', ')}');
    }
    stdout.writeln(
      files.names.isEmpty
          ? '  files: none'
          : '  files: ${files.names.join(', ')}',
    );
    return 0;
  }

  /// What the `local` environment holds, and what it is missing.
  ///
  /// Both halves in one list, each key marked with the file it comes from: the
  /// question a developer asks is "is it set", not "which file is it in", and
  /// an answer that makes them open two files is the reason the old
  /// copy-pasted block survived so long.
  int _listLocal() {
    final environment = localEnvironment;
    final committed = environment.committed;
    final mine = environment.mine;
    if (committed.isEmpty && mine.isEmpty) {
      stdout.writeln(
        'Nothing for "${DwLocalEnvironment.section}" in '
        '${DwLocalEnvironment.configPath} or '
        '${DwLocalEnvironment.secretsPath}.',
      );
    }

    final required = environment.requiredSecrets;
    stdout.writeln(
      'Local environment: ${DwLocalEnvironment.configPath} (committed) and '
      '${DwLocalEnvironment.secretsPath} (yours)',
    );
    for (final key in {...committed.keys, ...mine.keys}.toList()..sort()) {
      final value = mine[key] ?? committed[key]!;
      final notes = [
        if (mine.containsKey(key)) 'secrets.yaml' else 'config.yaml',
        if (mine.containsKey(key) && committed.containsKey(key))
          'overrides config.yaml',
        if (required.contains(key)) 'required',
        if (value.isEmpty) 'empty',
      ];
      stdout.writeln('  $key  (${notes.join(', ')})');
    }

    final missing = required
        .where((key) => (mine[key] ?? committed[key] ?? '').isEmpty)
        .toList();
    if (missing.isNotEmpty) {
      stdout
        ..writeln('  missing: ${missing.join(', ')}')
        ..writeln(
          '  The project declares them under "requires" in '
          '${DwLocalEnvironment.configPath}; deliver each with '
          '"dartway secret set <KEY> --env ${DwLocalEnvironment.section}".',
        );
    }
    // A listing reports; the gate that fails on a missing secret is
    // "dartway check".
    return 0;
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
  String get invocation => 'dartway secret put-file <path> --env <environment>';

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

    if (isLocal) {
      return refuseLocal(
        'mounts nothing: a document a locally started server reads is a path '
        'on this machine, so point a variable at it — "dartway secret set '
        'GOOGLE_APPLICATION_CREDENTIALS --env ${DwLocalEnvironment.section}".',
      );
    }
    final stack = resolveStack(results);
    final store = openStore(stack, results);
    final name = results.option('name') ?? p.basename(local.path);

    final DwSshResult uploaded;
    try {
      uploaded = await store.putFile(local, name: name);
    } on DwSecretFormatException catch (error) {
      stderr.writeln(error.message);
      return 1;
    }
    if (!uploaded.ok) {
      stderr.writeln('Upload failed: ${uploaded.firstLine}');
      return 1;
    }
    final listed = await store.listFiles();
    if (!listed.names.contains(name)) {
      stderr.writeln(
        'The upload reported success and ${store.directory} does not list '
        '$name.',
      );
      return 1;
    }
    stdout.writeln('Stored ${store.directory}/$name (mode 0600).');
    if (!stack.target.requiredSecretFiles.contains(name)) {
      stdout.writeln(
        'It is not under requires.files in deploy/config.yaml, so it is not '
        'mounted into the server. Declare it and re-run "dartway deploy setup".',
      );
    }
    return 0;
  }
}

/// Sends this environment's section of `deploy/secrets.yaml` to its server.
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
      'Replace the server store with this environment from '
      '${DwLocalSecretsFile.relativePath}.';

  @override
  String get invocation =>
      'dartway secret push --env <environment> [--dry-run] [--prune]';

  @override
  Future<int> run() async {
    final results = argResults!;
    if (isLocal) {
      return refuseLocal(
        'is already ${DwLocalEnvironment.secretsPath} > '
        '${DwLocalEnvironment.section}. There is nowhere to send it.',
      );
    }
    final stack = resolveStack(results);
    final environment = stack.target.environment;
    final store = openStore(stack, results);

    final local = DwLocalSecretsFile.of(projectRoot);
    final sections = local.read();
    if (sections == null) {
      stderr.writeln('No ${DwLocalSecretsFile.relativePath}.');
      return 1;
    }
    final section = sections[environment];
    if (section == null) {
      stderr.writeln(
        'No "$environment" section in ${DwLocalSecretsFile.relativePath} — '
        'nothing to push.',
      );
      return 1;
    }

    // Everything that cannot be stored is refused before anything is sent: a
    // push that fails half-way through the list is a store nobody can
    // describe.
    final problems = <String>[];
    for (final entry in section.entries) {
      if (stack.reservedSecretKeys.contains(entry.key)) {
        problems.add(
          '${entry.key} is set by the compose file and cannot be stored',
        );
        continue;
      }
      try {
        DwSecretStore.encodeLine(entry.key, entry.value);
      } on DwSecretFormatException catch (error) {
        problems.add(error.message);
      }
    }
    if (problems.isNotEmpty) {
      stderr.writeln('Refusing to push:');
      for (final problem in problems) {
        stderr.writeln('  - $problem');
      }
      return 1;
    }

    final remote = await store.readKeyNames();
    final remoteFilled = await store.readNonEmptyKeyNames();
    // A guard that reads the server is useless if the read silently failed.
    if (remote.ok && !remoteFilled.ok) {
      stderr.writeln(
        'Refusing to push: the server has a store but its contents could not '
        'be read (${remoteFilled.error}).',
      );
      return 1;
    }
    final orphaned = remote.ok
        ? (remote.names.difference(section.keys.toSet()).toList()..sort())
        : const <String>[];
    final wouldEmpty =
        remoteFilled.names
            .where((key) => (section[key] ?? '').isEmpty)
            .where((key) => section.containsKey(key))
            .toList()
          ..sort();

    final keys = section.keys.toList()..sort();
    stdout.writeln('Push to ${store.file}: ${keys.join(', ')}');

    if (orphaned.isNotEmpty && !results.flag('prune')) {
      stderr.writeln(
        'Refusing to push: the server holds keys this file does not — '
        '${orphaned.join(', ')}.\n'
        'Add them locally ("dartway secret pull"), or pass --prune to '
        'drop them.',
      );
      return 1;
    }
    if (orphaned.isNotEmpty) {
      stdout.writeln('  dropping: ${orphaned.join(', ')}');
    }
    if (wouldEmpty.isNotEmpty && !results.flag('allow-emptying')) {
      stderr.writeln(
        'Refusing to push: this would blank values the server has — '
        '${wouldEmpty.join(', ')}.\n'
        'Fill them locally, take the server values with "dartway secret pull", or pass --allow-emptying.',
      );
      return 1;
    }

    final missing = stack.requiredSecretKeys
        .where((key) => (section[key] ?? '').isEmpty)
        .toList();
    if (missing.isNotEmpty) {
      stdout.writeln(
        '  note: required and not set here — ${missing.join(', ')}; the next '
        'deploy will refuse until they are',
      );
    }

    if (results.flag('dry-run')) {
      stdout.writeln('Dry run — nothing sent.');
      return 0;
    }

    final written = await store.writeAll(section);
    if (!written.ok) {
      stderr.writeln('Push failed: ${written.firstLine}');
      return 1;
    }
    final after = await store.readKeyNames();
    final absent = section.keys.where((key) => !after.names.contains(key));
    if (absent.isNotEmpty) {
      stderr.writeln(
        'The push reported success and the store lacks ${absent.join(', ')}.',
      );
      return 1;
    }

    stdout
      ..writeln('Pushed ${section.length} key(s).')
      ..writeln(
        'A running server keeps the environment it started with; the values '
        'take effect on the next deploy.',
      );
    return 0;
  }
}

/// Brings the server's keys into `deploy/secrets.yaml`.
///
/// The counterpart to `push`, and the way a server whose secrets were
/// generated in place gets a maintainer's copy.
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
      'Copy keys the server has and ${DwLocalSecretsFile.relativePath} lacks '
      'into it.';

  @override
  String get invocation =>
      'dartway secret pull --env <environment> [--dry-run]';

  @override
  Future<int> run() async {
    final results = argResults!;
    if (isLocal) {
      return refuseLocal(
        'is already ${DwLocalEnvironment.secretsPath} > '
        '${DwLocalEnvironment.section}. There is nowhere to read it from.',
      );
    }
    final stack = resolveStack(results);
    final environment = stack.target.environment;
    final store = openStore(stack, results);
    final local = DwLocalSecretsFile.of(projectRoot);

    final remoteRead = await store.readFile();
    if (!remoteRead.ok) {
      stderr.writeln('Cannot read ${store.file}: ${remoteRead.firstLine}');
      return 1;
    }
    final Map<String, String> remote;
    try {
      remote = DwSecretStore.parse(remoteRead.stdout);
    } on DwSecretFormatException catch (error) {
      stderr.writeln('The server store is malformed: ${error.message}');
      return 1;
    }

    final localSection =
        (local.read() ?? const <String, Map<String, String>>{})[environment] ??
        const <String, String>{};

    final additions = <String, String>{};
    final differing = <String>[];
    for (final entry in remote.entries) {
      final localValue = localSection[entry.key];
      // A local placeholder carries no information, so it is filled rather
      // than reported as a conflict.
      if (localValue == null ||
          (localValue.isEmpty && entry.value.isNotEmpty)) {
        additions[entry.key] = entry.value;
      } else if (localValue != entry.value) {
        differing.add(entry.key);
      }
    }
    final localOnly =
        localSection.keys.where((key) => !remote.containsKey(key)).toList()
          ..sort();

    stdout.writeln('Compare ${store.file} with ${local.file.path}');
    if (additions.isEmpty) {
      stdout.writeln('  nothing to add');
    } else {
      stdout.writeln(
        '  add to $environment: ${(additions.keys.toList()..sort()).join(', ')}',
      );
    }
    if (differing.isNotEmpty) {
      stdout
        ..writeln('  values differ: ${(differing..sort()).join(', ')}')
        ..writeln(
          '  Differing values are reported, never rewritten — the local file '
          'is the one you maintain. Resolve them by hand, or overwrite the '
          'server with "dartway secret push".',
        );
    }
    if (localOnly.isNotEmpty) {
      stdout.writeln('  local only: ${localOnly.join(', ')}');
    }

    if (additions.isEmpty) {
      return 0;
    }
    if (results.flag('dry-run')) {
      stdout.writeln('Dry run — nothing written.');
      return 0;
    }
    if (!local.exists) {
      local.file
        ..parent.createSync(recursive: true)
        ..writeAsStringSync(
          '# Secrets of every environment. Git-ignored; keep it backed up '
          'somewhere you control.\n',
        );
    }
    local.write(environment, additions);
    stdout
      ..writeln('Added ${additions.length} key(s) to ${local.file.path}.')
      ..writeln(
        'This file now holds secrets for $environment; it must stay out of '
        'Git (deploy/.gitignore) and be backed up somewhere you control.',
      );
    return 0;
  }
}
