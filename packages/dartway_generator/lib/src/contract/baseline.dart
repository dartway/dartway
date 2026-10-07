import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

import '../emit/output.dart';
import '../project.dart';
import 'descriptor.dart';

/// Baseline selection is performed before analysis and never follows feature
/// HEAD. Explicit CI revisions are resolved directly; project defaults use
/// the configured base branch (or an unambiguous remote HEAD/main/master).
String resolveContractBase(String projectRoot, String? revision) {
  if (revision != null) {
    return _git(projectRoot, [
      'rev-parse',
      '--verify',
      '--end-of-options',
      '$revision^{commit}',
    ]).trim();
  }
  String? branch;
  for (final relative in [
    '.agents/dartway-toolkit.json',
    '.claude/dartway-toolkit.json',
  ]) {
    final file = File(p.join(projectRoot, relative));
    if (!file.existsSync()) continue;
    final json = jsonDecode(file.readAsStringSync());
    if (json is! Map ||
        json['settings'] is! Map ||
        (json['settings'] as Map)['baseBranch'] is! String) {
      throw const FormatException(
        'toolkit settings do not identify the project base branch; supply --contract-base',
      );
    }
    branch = (json['settings'] as Map)['baseBranch'] as String;
    break;
  }
  if (branch != null) {
    final remote = _tryGit(projectRoot, [
      'rev-parse',
      '--verify',
      '--end-of-options',
      'refs/remotes/origin/$branch^{commit}',
    ]);
    branch = remote == null
        ? 'refs/heads/$branch'
        : 'refs/remotes/origin/$branch';
  } else {
    branch = _tryGit(projectRoot, [
      'symbolic-ref',
      'refs/remotes/origin/HEAD',
    ])?.trim();
    if (branch == null) {
      final candidates = <String>[];
      for (final name in ['main', 'master']) {
        final remote = 'refs/remotes/origin/$name';
        final local = 'refs/heads/$name';
        if (_tryGit(projectRoot, [
              'rev-parse',
              '--verify',
              '$remote^{commit}',
            ]) !=
            null) {
          candidates.add(remote);
        } else if (_tryGit(projectRoot, [
              'rev-parse',
              '--verify',
              '$local^{commit}',
            ]) !=
            null) {
          candidates.add(local);
        }
      }
      if (candidates.length != 1) {
        throw const FormatException(
          'no unambiguous project base branch; configure baseBranch or supply --contract-base',
        );
      }
      branch = candidates.single;
    }
  }
  return _git(projectRoot, ['merge-base', 'HEAD', branch]).trim();
}

String _git(String root, List<String> arguments) {
  final result = Process.runSync('git', arguments, workingDirectory: root);
  if (result.exitCode != 0) {
    throw FormatException('Git baseline unavailable: ${result.stderr}'.trim());
  }
  return result.stdout as String;
}

String? _tryGit(String root, List<String> arguments) {
  final result = Process.runSync('git', arguments, workingDirectory: root);
  return result.exitCode == 0 ? result.stdout as String : null;
}

final class ContractBaseline {
  const ContractBaseline(this.descriptor, this.proof);
  final Map<String, dynamic> descriptor;
  final String proof;
}

/// A committed descriptor always wins. Without one, adopt [current] only when
/// the shared package hand-written files still match the Git objects at [sha].
Future<ContractBaseline> readContractBaseline({
  required String root,
  required String sha,
  required DwProjectPackage shared,
  required Map<String, dynamic> current,
}) async {
  final gitRoot = _git(root, ['rev-parse', '--show-toplevel']).trim();
  var relative = p.posix.joinAll(
    p.split(
      p.relative(
        p.join(shared.lib, 'generated', 'dw_contract.json'),
        from: gitRoot,
      ),
    ),
  );
  if (_tryGit(root, [
        'cat-file',
        '-e',
        '$sha:${p.posix.dirname(p.posix.dirname(p.posix.dirname(relative)))}/pubspec.yaml',
      ]) ==
      null) {
    final matches = <String>[];
    for (final path in LineSplitter.split(
      _git(root, ['ls-tree', '-r', '--name-only', sha]),
    ).where((path) => p.posix.basename(path) == 'pubspec.yaml')) {
      final metadata = loadYaml(_git(root, ['show', '$sha:$path']));
      if (metadata is Map && metadata['name'] == shared.name) {
        matches.add(p.posix.dirname(path));
      }
    }
    if (matches.length != 1) {
      throw const FormatException(
        'committed shared package cannot be identified unambiguously',
      );
    }
    relative = p.posix.join(matches.single, 'lib/generated/dw_contract.json');
  }
  final text = _tryGit(root, ['show', '$sha:$relative']);
  if (text != null) {
    final value = jsonDecode(text);
    validateContract(value);
    final pubspec = loadYaml(
      _git(root, [
        'show',
        '$sha:${p.posix.dirname(p.posix.dirname(p.posix.dirname(relative)))}/pubspec.yaml',
      ]),
    );
    if (pubspec is! Map ||
        '${pubspec['version']}' != (value as Map)['contractVersion']) {
      throw const FormatException(
        'committed descriptor version differs from committed shared package version; regenerate and commit at the trusted base',
      );
    }
    return ContractBaseline(
      value as Map<String, dynamic>,
      'committed descriptor (Git object, format 1 / codec 1)',
    );
  }
  final basePackage = p.posix.dirname(
    p.posix.dirname(p.posix.dirname(relative)),
  );
  final headPackage = p.posix.joinAll(
    p.split(p.relative(shared.root, from: gitRoot)),
  );
  final baseFiles = <String, (String, String)>{};
  for (final entry in _git(gitRoot, [
    'ls-tree',
    '-rz',
    sha,
    '--',
    basePackage,
  ]).split('\u0000')) {
    if (entry.isEmpty) continue;
    final tab = entry.indexOf('\t');
    final metadata = entry.substring(0, tab).split(' ');
    final path = p.posix.relative(entry.substring(tab + 1), from: basePackage);
    baseFiles[path] = (metadata[0], metadata[2]);
  }
  // Include additions as well as base-tracked files: a new DTO must not become
  // an unverified contract edit just because it had no blob at the base.
  final paths = <String>{
    ...baseFiles.keys,
    for (final path in _git(gitRoot, [
      'ls-files',
      '-z',
      '--cached',
      '--others',
      '--exclude-standard',
      '--',
      headPackage,
    ]).split('\u0000'))
      if (path.isNotEmpty) p.posix.relative(path, from: headPackage),
  }.toList()..sort();
  final changed = <String>[];
  for (final path in paths) {
    if (path == 'pubspec.yaml' || path == 'pubspec.lock') continue;
    final entry = baseFiles[path];
    final before = entry == null
        ? null
        : _gitBytes(gitRoot, ['cat-file', 'blob', entry.$2]);
    final after = _fileBytes(
      p.join(shared.root, p.joinAll(p.posix.split(path))),
    );
    // Ownership is determined from the base bytes for existing files. A head
    // cannot hide an edit to a manual part by adding a generated header.
    if (isGeneratorOwnedFile(path, before ?? after ?? const [])) continue;
    if (before == null || after == null || !_sameBytes(before, after)) {
      changed.add(p.posix.join(headPackage, path));
    }
  }
  if (changed.isNotEmpty) {
    throw FormatException(
      'shared contract source changed: ${changed.join(', ')}. Split the change: '
      'land the pin move with generated files and the descriptor first, keeping '
      'hand-written shared source unchanged; make the contract edit in a following PR',
    );
  }
  return ContractBaseline(
    current,
    'adopted at $sha: shared contract source unchanged; descriptor established by this change',
  );
}

List<int> _gitBytes(String root, List<String> arguments) {
  final result = Process.runSync(
    'git',
    arguments,
    workingDirectory: root,
    stdoutEncoding: null,
  );
  if (result.exitCode != 0) {
    throw FormatException('Git baseline unavailable: ${result.stderr}'.trim());
  }
  return result.stdout as List<int>;
}

List<int>? _fileBytes(String path) =>
    switch (FileSystemEntity.typeSync(path, followLinks: false)) {
      FileSystemEntityType.file => File(path).readAsBytesSync(),
      FileSystemEntityType.link => utf8.encode(Link(path).targetSync()),
      _ => null,
    };

bool _sameBytes(List<int> before, List<int> after) {
  if (before.length != after.length) return false;
  for (var i = 0; i < before.length; i++) {
    if (before[i] != after[i]) return false;
  }
  return true;
}
