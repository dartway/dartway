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

/// Reads only Git objects at [sha]. A missing descriptor has one narrow
/// bootstrap: reproduce the committed codecs/registry using existing resolved
/// dependencies. No pub get, setup scripts, SDK switching or feature seed.
Future<ContractBaseline> readContractBaseline({
  required String root,
  required String sha,
  required DwProjectPackage shared,
  required Future<List<GeneratedFile>> Function(String root) generate,
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
  final scratch = Directory.systemTemp.createTempSync('dw_contract_base_');
  try {
    // Do not follow a historical symlink out of the disposable tree.
    final tree = _git(gitRoot, ['ls-tree', '-rz', sha]);
    final omitted = <String>[];
    for (final entry in tree.split('\u0000')) {
      if (!entry.startsWith('120000 ') && !entry.startsWith('160000 ')) {
        continue;
      }
      final path = entry.substring(entry.indexOf('\t') + 1);
      if (path.endsWith('.dart') ||
          path.endsWith('pubspec.yaml') ||
          path.contains('/lib/')) {
        throw FormatException(
          'baseline codec source symlink/submodule is unsupported: $path',
        );
      }
      // Agent adapters/assets cannot participate in the analyzed codec tree;
      // omit them rather than materializing links in disposable scratch.
      omitted.add(path);
    }
    final archive = p.join(scratch.path, 'tree.tar');
    _git(gitRoot, ['archive', '--format=tar', '--output=$archive', sha]);
    final checkout = Directory(p.join(scratch.path, 'tree'))..createSync();
    final extracted = Process.runSync('tar', [
      '-xf',
      archive,
      for (final path in omitted) '--exclude=$path',
      '-C',
      checkout.path,
    ]);
    if (extracted.exitCode != 0) {
      throw const FormatException('cannot extract committed source tree');
    }
    // The descriptor owns only the shared registry/codecs. App SDK sources,
    // server schema and handler semantics are outside this proof.
    final target = p.join(
      checkout.path,
      p.relative(shared.root, from: gitRoot),
    );
    for (final package in [shared]) {
      final destination = p.join(
        checkout.path,
        p.relative(package.root, from: gitRoot),
      );
      final oldPubspec = File(p.join(destination, 'pubspec.yaml'));
      if (!oldPubspec.existsSync()) {
        throw FormatException('baseline lacks package ${package.name}');
      }
      final old = loadYaml(oldPubspec.readAsStringSync()) as Map;
      final current =
          loadYaml(
                File(p.join(package.root, 'pubspec.yaml')).readAsStringSync(),
              )
              as Map;
      for (final key in [
        'name',
        'environment',
        'dependencies',
        'dev_dependencies',
        'dependency_overrides',
        'resolution',
      ]) {
        if (jsonEncode(canonical(_plain(old[key]))) !=
            jsonEncode(canonical(_plain(current[key])))) {
          throw FormatException(
            'baseline ${package.name} $key cannot be reproduced from existing dependency resolution; establish a descriptor on the trusted base first',
          );
        }
      }
      var ancestor = package.root;
      File? config;
      File? lock;
      while (true) {
        final candidate = File(
          p.join(ancestor, '.dart_tool/package_config.json'),
        );
        if (candidate.existsSync()) {
          config = candidate;
          lock = File(p.join(ancestor, 'pubspec.lock'));
          break;
        }
        final parent = p.dirname(ancestor);
        if (parent == ancestor) break;
        ancestor = parent;
      }
      if (config == null ||
          lock == null ||
          !lock.existsSync() ||
          !p.isWithin(gitRoot, lock.path)) {
        throw FormatException(
          'baseline ${package.name} needs existing resolved package config and committed lock information',
        );
      }
      final oldLock = File(
        p.join(checkout.path, p.relative(lock.path, from: gitRoot)),
      );
      if (!oldLock.existsSync() ||
          !_sameResolution(
            loadYaml(oldLock.readAsStringSync()),
            loadYaml(lock.readAsStringSync()),
          )) {
        throw FormatException(
          'baseline ${package.name} dependency lock differs from the existing resolution; establish a descriptor on the trusted base first',
        );
      }
      final decoded =
          jsonDecode(config.readAsStringSync()) as Map<String, dynamic>;
      final locked =
          (loadYaml(oldLock.readAsStringSync()) as Map)['packages'] as Map;
      if (decoded['configVersion'] != 2 || decoded['packages'] is! List) {
        throw const FormatException(
          'unsupported resolved package configuration',
        );
      }
      for (final entry in decoded['packages'] as List) {
        final uri = config.uri.resolve(entry['rootUri'] as String);
        if (uri.scheme != 'file') {
          throw const FormatException('unsupported resolved dependency URI');
        }
        final dependency = p.normalize(uri.toFilePath());
        final pinned = locked[entry['name']];
        if (pinned is Map &&
            pinned['source'] == 'path' &&
            !p.equals(dependency, gitRoot) &&
            !p.isWithin(gitRoot, dependency)) {
          throw FormatException(
            'unverifiable external path dependency ${entry['name']} in descriptor-free baseline; commit a descriptor on the trusted base with its original dependency source available',
          );
        }
        entry['rootUri'] = p
            .toUri(
              p.equals(dependency, gitRoot) || p.isWithin(gitRoot, dependency)
                  ? p.join(checkout.path, p.relative(dependency, from: gitRoot))
                  : dependency,
            )
            .toString();
        if (!Directory(
          Uri.parse(entry['rootUri'] as String).toFilePath(),
        ).existsSync()) {
          throw FormatException(
            'resolved dependency ${entry['name']} is unavailable for the committed baseline',
          );
        }
      }
      for (final entry in decoded['packages'] as List) {
        final pinned = locked[entry['name']];
        if (pinned is! Map) continue;
        final dependencyPubspec = File(
          p.join(
            Uri.parse(entry['rootUri'] as String).toFilePath(),
            'pubspec.yaml',
          ),
        );
        if (!dependencyPubspec.existsSync()) {
          throw FormatException(
            'resolved dependency ${entry['name']} lacks its pubspec',
          );
        }
        final metadata = loadYaml(dependencyPubspec.readAsStringSync());
        if (metadata is! Map ||
            metadata['name'] != entry['name'] ||
            '${metadata['version']}' != '${pinned['version']}') {
          throw FormatException(
            'resolved dependency ${entry['name']} does not match the committed dependency lock',
          );
        }
      }
      final copied = File(
        p.join(destination, '.dart_tool/package_config.json'),
      );
      copied.parent.createSync(recursive: true);
      copied.writeAsStringSync(jsonEncode(decoded));
    }
    final output = await generate(target);
    final descriptorFile = output
        .where((f) => p.basename(f.path) == 'dw_contract.json')
        .single;
    for (final file in output.where(
      (f) => p.basename(f.path) != 'dw_contract.json',
    )) {
      final committed = File(file.path);
      if (!committed.existsSync() ||
          committed.readAsStringSync() != file.content) {
        throw FormatException(
          'committed codec/registry not reproduced: ${p.relative(file.path, from: target)}; regenerate and commit with a supported generator on the trusted base first',
        );
      }
    }
    final descriptor = jsonDecode(descriptorFile.content);
    validateContract(descriptor);
    return ContractBaseline(
      descriptor as Map<String, dynamic>,
      'validated bootstrap (committed shared source, matching dependency locks, exact committed shared codecs/registry reproduction)',
    );
  } finally {
    scratch.deleteSync(recursive: true);
  }
}

Object? _plain(Object? value) => switch (value) {
  Map() => {
    for (final entry in value.entries) '${entry.key}': _plain(entry.value),
  },
  List() => value.map(_plain).toList(),
  _ => value,
};

bool _sameResolution(Object? a, Object? b) {
  Object? resolution(Object? value) {
    final plain = _plain(value);
    if (plain is! Map || plain['packages'] is! Map) return null;
    return {
      for (final entry in (plain['packages'] as Map).entries)
        entry.key: {...entry.value as Map}..remove('dependency'),
    };
  }

  final before = resolution(a);
  final after = resolution(b);
  return before != null &&
      after != null &&
      jsonEncode(canonical(before)) == jsonEncode(canonical(after));
}
