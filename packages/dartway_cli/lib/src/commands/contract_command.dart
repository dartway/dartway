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
  @override
  String get name => 'baseline';

  @override
  String get description =>
      'Record the generated contract of the build live in both stores.';

  @override
  int run() {
    final root = findPackageProjectRoot(Directory.current) ?? findProjectRoot();
    final shared = root
        .listSync()
        .whereType<Directory>()
        .where((directory) => p.basename(directory.path).endsWith('_shared'))
        .where(
          (directory) => File(
            p.join(directory.path, 'lib', 'generated', 'dw_contract.json'),
          ).existsSync(),
        )
        .toList();
    if (shared.length != 1) {
      throw StateError(
        'Expected one shared package with lib/generated/dw_contract.json; found ${shared.length}.',
      );
    }
    final source = File(
      p.join(shared.single.path, 'lib', 'generated', 'dw_contract.json'),
    );
    final sourceRelative = p.relative(source.path, from: root.path);
    final gitTopLevel = Process.runSync('git', [
      'rev-parse',
      '--show-toplevel',
    ], workingDirectory: root.path);
    if (gitTopLevel.exitCode != 0) {
      throw StateError('Cannot record a baseline outside a Git repository.');
    }
    final gitRoot = Directory((gitTopLevel.stdout as String).trim());
    final sourceInGit = p.posix.joinAll(
      p.split(p.relative(source.path, from: gitRoot.path)),
    );
    final status = Process.runSync('git', [
      'status',
      '--porcelain',
      '--',
      sourceInGit,
    ], workingDirectory: gitRoot.path);
    final headSource = Process.runSync('git', [
      'show',
      'HEAD:./$sourceInGit',
    ], workingDirectory: gitRoot.path);
    if (status.exitCode != 0 ||
        (status.stdout as String).trim().isNotEmpty ||
        headSource.exitCode != 0 ||
        headSource.stdout != source.readAsStringSync()) {
      throw StateError(
        'Refusing to record $sourceRelative: it is dirty or differs from HEAD.',
      );
    }
    final descriptor = jsonDecode(source.readAsStringSync());
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
    final pubspec = File(p.join(shared.single.path, 'pubspec.yaml'))
        .readAsLinesSync()
        .where((line) => line.startsWith('version:'))
        .map((line) => line.substring('version:'.length).trim())
        .single;
    if (pubspec != descriptor['contractVersion']) {
      throw StateError(
        'The generated contract is stale: its version differs from pubspec.yaml. Run `dartway generate` first.',
      );
    }
    final commit = Process.runSync('git', [
      'rev-parse',
      '--verify',
      'HEAD^{commit}',
    ], workingDirectory: root.path);
    if (commit.exitCode != 0) {
      throw StateError('Cannot record a baseline outside a Git commit.');
    }
    descriptor['baselineCommit'] = (commit.stdout as String).trim();
    final target = File(p.join(shared.single.path, 'contract_baseline.json'));
    target.writeAsStringSync(
      '${const JsonEncoder.withIndent('  ').convert(descriptor)}\n',
    );
    stdout.writeln(
      'Recorded store contract baseline ${descriptor['contractVersion']} in ${p.relative(target.path, from: root.path)}.',
    );
    return 0;
  }
}
