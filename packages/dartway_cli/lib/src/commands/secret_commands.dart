import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;

import '../deploy/local_secrets_file.dart';
import '../deploy/secret_store.dart';
import '../deploy/ssh_runner.dart';
import '../deploy/stack.dart';
import 'deploy_command.dart';

/// Manages the runtime secret store on a deployment target.
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
      'Manage runtime secrets on the server. Values are never printed.';
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

  late final Directory projectRoot = deployProjectRoot();

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
      'MinIO keys). Existing values are never replaced.';

  @override
  String get invocation => 'dartway deploy secret init --env <environment>';

  @override
  Future<int> run() async {
    final results = argResults!;
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
        'line from ${store.file} or set it with "dartway deploy secret set".',
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
        '(dartway deploy secret set <KEY> --env ${stack.target.environment})',
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
  String get invocation =>
      'dartway deploy secret set <KEY> --env <environment>';

  @override
  Future<int> run() async {
    final results = argResults!;
    if (results.rest.length != 1) {
      usageException('Name exactly one key to set.');
    }
    final key = results.rest.single;
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
  String get invocation => 'dartway deploy secret list --env <environment>';

  @override
  Future<int> run() async {
    final results = argResults!;
    final stack = resolveStack(results);
    final store = openStore(stack, results);

    final names = await store.readKeyNames();
    if (!names.ok) {
      stderr.writeln(
        'No readable store at ${store.file}: ${names.error}. '
        'Create it with "dartway deploy secret init".',
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
      'dartway deploy secret push --env <environment> [--dry-run] [--prune]';

  @override
  Future<int> run() async {
    final results = argResults!;
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
        'Add them locally ("dartway deploy secret pull"), or pass --prune to '
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
        'Fill them locally, take the server values with "dartway deploy '
        'secret pull", or pass --allow-emptying.',
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
      'dartway deploy secret pull --env <environment> [--dry-run]';

  @override
  Future<int> run() async {
    final results = argResults!;
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
          'server with "dartway deploy secret push".',
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
