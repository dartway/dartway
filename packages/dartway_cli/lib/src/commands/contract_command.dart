import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;

import '../project_layout.dart';

final class ContractCommand extends Command<int> {
  ContractCommand() {
    addSubcommand(_ContractBaselineCommand());
  }

  @override
  String get name => 'contract';

  @override
  String get description => 'Manage the project contract store baseline.';
}

final class _ContractBaselineCommand extends Command<int> {
  _ContractBaselineCommand() {
    argParser.addOption(
      'revision',
      abbr: 'r',
      mandatory: true,
      valueHelp: 'sha|tag',
      help: 'Git revision from which the store build was built.',
    );
  }

  @override
  String get name => 'baseline';

  @override
  String get description =>
      'Record the generated contract of the build live in both stores.';

  @override
  int run() {
    final root = findPackageProjectRoot(Directory.current) ?? findProjectRoot();
    final revision = argResults!['revision'] as String;
    final sharedDirectories = root
        .listSync()
        .whereType<Directory>()
        .where((directory) => p.basename(directory.path).endsWith('_shared'))
        .toList();
    final gitTopLevel = Process.runSync('git', [
      'rev-parse',
      '--show-toplevel',
    ], workingDirectory: root.path);
    if (gitTopLevel.exitCode != 0) {
      throw StateError('Cannot record a baseline outside a Git repository.');
    }
    final gitRoot = Directory((gitTopLevel.stdout as String).trim());
    final commit = Process.runSync('git', [
      'rev-parse',
      '--verify',
      '$revision^{commit}',
    ], workingDirectory: gitRoot.path);
    if (commit.exitCode != 0) {
      throw StateError(
        'Revision `$revision` does not resolve to a Git commit.',
      );
    }
    final resolvedCommit = (commit.stdout as String).trim();

    String inGit(Directory directory, String path) => p.posix.joinAll(
      p.split(p.relative(p.join(directory.path, path), from: gitRoot.path)),
    );

    ProcessResult show(Directory directory, String path) => Process.runSync(
      'git',
      ['show', '$resolvedCommit:${inGit(directory, path)}'],
      workingDirectory: gitRoot.path,
    );

    final candidates = [
      for (final directory in sharedDirectories)
        (
          directory: directory,
          contract: show(directory, 'lib/generated/dw_contract.json'),
        ),
    ].where((candidate) => candidate.contract.exitCode == 0).toList();
    if (candidates.length != 1) {
      throw StateError(
        'Expected revision `$revision` to contain one shared package with lib/generated/dw_contract.json; found ${candidates.length}.',
      );
    }
    final shared = candidates.single.directory;
    final descriptor = jsonDecode(candidates.single.contract.stdout as String);
    if (descriptor is! Map<String, dynamic> ||
        descriptor['format'] is! int ||
        descriptor['codec'] != 1 ||
        descriptor['contractVersion'] is! String ||
        descriptor['objects'] is! Map ||
        descriptor['unverified'] is! List) {
      throw StateError('The generated contract is malformed.');
    }
    if ((descriptor['unverified'] as List).isNotEmpty) {
      throw StateError(
        'The generated contract is unverified: ${descriptor['unverified']}.',
      );
    }
    final pubspecSource = show(shared, 'pubspec.yaml');
    if (pubspecSource.exitCode != 0) {
      throw StateError('Revision `$revision` has no shared pubspec.yaml.');
    }
    final pubspec = (pubspecSource.stdout as String)
        .split('\n')
        .where((line) => line.startsWith('version:'))
        .map((line) => line.substring('version:'.length).trim())
        .single;
    if (pubspec != descriptor['contractVersion']) {
      throw StateError(
        'The generated contract is stale: its version differs from pubspec.yaml. Run `dartway generate` first.',
      );
    }
    descriptor['baselineCommit'] = resolvedCommit;
    final target = File(p.join(shared.path, 'contract_baseline.json'));
    target.writeAsStringSync(
      '${const JsonEncoder.withIndent('  ').convert(descriptor)}\n',
    );
    stdout.writeln(
      'Recorded store contract baseline ${descriptor['contractVersion']} in ${p.relative(target.path, from: root.path)}.',
    );
    return 0;
  }
}
