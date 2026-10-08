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
/// the shared package and its in-repo path dependencies match Git blobs at [sha].
Future<ContractBaseline> readContractBaseline({
  required String root,
  required String sha,
  required DwProjectPackage shared,
  required Map<String, dynamic> current,
  required Set<String> generatedPaths,
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
  final baseDependencies = _inRepoPathDependencies(
    basePackage,
    gitRoot,
    sha: sha,
  );
  final headDependencies = _inRepoPathDependencies(headPackage, gitRoot);
  final changed = <String>[
    // A departed dependency is a removed contract input even if its old files
    // remain on disk. Otherwise repointing it could hide an external edit.
    ...baseDependencies.difference(headDependencies),
  ];
  final compared = <String, String?>{};
  for (final (base, head) in [
    (basePackage, headPackage),
    for (final dependency in {...baseDependencies, ...headDependencies})
      (dependency, dependency),
  ]) {
    final baseFiles = <String, (String, String)>{};
    for (final entry in _git(gitRoot, [
      'ls-tree',
      '-rz',
      sha,
      '--',
      base,
    ]).split('\u0000')) {
      if (entry.isEmpty) continue;
      final tab = entry.indexOf('\t');
      final metadata = entry.substring(0, tab).split(' ');
      final path = p.posix.relative(entry.substring(tab + 1), from: base);
      baseFiles[path] = (metadata[0], metadata[2]);
    }
    // Include additions as well as base-tracked files, including deletions.
    final paths = <String>{
      ...baseFiles.keys,
      for (final path in _git(gitRoot, [
        'ls-files',
        '-z',
        '--cached',
        '--others',
        '--exclude-standard',
        '--',
        head,
      ]).split('\u0000'))
        if (path.isNotEmpty) p.posix.relative(path, from: head),
    }.toList()..sort();
    for (final path in paths) {
      if (path == 'pubspec.yaml' || path == 'pubspec.lock') continue;
      final entry = baseFiles[path];
      final gitPath = p.posix.normalize(p.posix.join(head, path));
      final filePath = p.join(gitRoot, p.joinAll(p.posix.split(gitPath)));
      if (entry?.$1 == '160000') {
        throw FormatException(
          'baseline shared contract source submodule is unsupported: '
          '$gitPath; keep the shared contract source '
          'in tracked files so its blobs can be compared',
        );
      }
      if (head == headPackage) {
        if (generatedPaths.contains(filePath)) continue;
        // Only parts need base bytes for ownership. An existing manual part
        // cannot hide an edit by adding a generated header at head.
        if (path.endsWith('.dw.dart')) {
          final bytes = entry == null
              ? _fileBytes(filePath)
              : _gitBytes(gitRoot, ['cat-file', 'blob', entry.$2]);
          if (isGeneratorOwnedFile(path, bytes ?? const [])) continue;
        }
      }
      compared[gitPath] = entry?.$2;
    }
  }
  final workingBlobs = await _workingBlobIds(gitRoot, compared.keys);
  for (final entry in compared.entries) {
    final after = workingBlobs[entry.key];
    if (entry.value == null || after == null || entry.value != after) {
      changed.add(entry.key);
    }
  }
  changed.sort();
  if (changed.isNotEmpty) {
    throw FormatException(
      'shared contract source changed: ${changed.join(', ')}. Split the change: '
      'land the pin move with generated files and the descriptor first, keeping '
      'hand-written shared source and in-repo path dependencies unchanged; make the contract edit in a following PR',
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

// Resolve dependency names from pubspec edges, but take their actual sources
// from the lock so overrides do not create a second dependency graph. Both
// snapshots stay within the Git root; base metadata never comes from head.
Set<String> _inRepoPathDependencies(
  String sharedPackage,
  String gitRoot, {
  String? sha,
}) {
  String? read(String path) => sha == null
      ? (File(p.join(gitRoot, path)).existsSync()
            ? File(p.join(gitRoot, path)).readAsStringSync()
            : null)
      : _tryGit(gitRoot, ['show', '$sha:$path']);

  var resolutionRoot = sharedPackage;
  Map? packages;
  while (true) {
    final text = read(p.posix.join(resolutionRoot, 'pubspec.lock'));
    if (text != null) {
      final metadata = loadYaml(text);
      if (metadata is! Map || metadata['packages'] is! Map) {
        throw const FormatException('resolved lock does not identify packages');
      }
      packages = metadata['packages'] as Map;
      break;
    }
    if (resolutionRoot == '.') break;
    resolutionRoot = p.posix.dirname(resolutionRoot);
  }
  if (packages == null) return {};

  String? inRepo(String path) {
    var absolute = p.normalize(p.join(gitRoot, resolutionRoot, path));
    if (sha == null && Directory(absolute).existsSync()) {
      absolute = Directory(absolute).resolveSymbolicLinksSync();
    }
    if (absolute != gitRoot && !p.isWithin(gitRoot, absolute)) return null;
    return p.posix.joinAll(p.split(p.relative(absolute, from: gitRoot)));
  }

  final resolved = <String, String>{};
  for (final entry in packages.entries) {
    if (entry.value is! Map || (entry.value as Map)['source'] != 'path') {
      continue;
    }
    final description = (entry.value as Map)['description'];
    if (description is! Map || description['path'] is! String) {
      throw const FormatException('resolved path dependency has no path');
    }
    final path = inRepo(description['path'] as String);
    if (path != null) resolved[entry.key as String] = path;
  }

  // Workspace members do not have lock entries. Their pubspecs still provide
  // the same dependency edges, including edges to overridden path packages.
  final workspaceText = read(p.posix.join(resolutionRoot, 'pubspec.yaml'));
  final workspace = workspaceText == null ? null : loadYaml(workspaceText);
  if (workspace is Map && workspace['workspace'] is List) {
    final workspacePackages = <String, Map>{resolutionRoot: workspace};
    final pubspecs = sha == null
        ? _git(gitRoot, [
            'ls-files',
            '-z',
            '--cached',
            '--others',
            '--exclude-standard',
            '--',
            resolutionRoot,
          ])
        : _git(gitRoot, [
            'ls-tree',
            '-rz',
            '--name-only',
            sha,
            '--',
            resolutionRoot,
          ]);
    for (final path in pubspecs.split('\u0000').toSet()) {
      if (p.posix.basename(path) != 'pubspec.yaml') continue;
      final text = read(path);
      if (text == null) continue;
      final metadata = loadYaml(text);
      if (metadata is Map &&
          metadata['resolution'] == 'workspace' &&
          metadata['name'] is String) {
        workspacePackages[p.posix.dirname(path)] = metadata;
      }
    }
    final pendingWorkspace = [resolutionRoot];
    final visitedWorkspace = <String>{};
    while (pendingWorkspace.isNotEmpty) {
      final package = pendingWorkspace.removeLast();
      if (!visitedWorkspace.add(package)) continue;
      final metadata = workspacePackages[package]!;
      if (metadata['name'] is String) {
        resolved[metadata['name'] as String] = package;
      }
      if (metadata['workspace'] is! List) continue;
      final members = <RegExp>[
        for (final pattern in (metadata['workspace'] as List).cast<String>())
          RegExp(
            '^${RegExp.escape(p.posix.normalize(pattern)).replaceAll(r'\*\*', '.*').replaceAll(r'\*', '[^/]*')}\$',
          ),
      ];
      for (final member in workspacePackages.keys) {
        final relative = p.posix.relative(member, from: package);
        if (members.any((pattern) => pattern.hasMatch(relative))) {
          pendingWorkspace.add(member);
        }
      }
    }
  }

  final closure = <String>{};
  final pending = [sharedPackage];
  final visited = <String>{};
  while (pending.isNotEmpty) {
    final package = pending.removeLast();
    if (!visited.add(package)) continue;
    final text = read(p.posix.join(package, 'pubspec.yaml'));
    if (text == null) {
      throw FormatException(
        'path dependency pubspec unavailable: $package/pubspec.yaml',
      );
    }
    final metadata = loadYaml(text);
    if (metadata is! Map ||
        (metadata['dependencies'] != null &&
            metadata['dependencies'] is! Map)) {
      throw FormatException(
        'path dependency pubspec does not identify dependencies: $package/pubspec.yaml',
      );
    }
    final dependencies = metadata['dependencies'] as Map?;
    for (final name in dependencies?.keys ?? const []) {
      final dependency = resolved[name];
      if (dependency == null || dependency == sharedPackage) continue;
      if (closure.add(dependency)) pending.add(dependency);
    }
  }
  return closure;
}

// --stdin-paths applies each file's attributes just as --path does, while one
// process hashes all regular files. Git expects C-quoted paths for special bytes.
Future<Map<String, String>> _workingBlobIds(
  String root,
  Iterable<String> paths,
) async {
  final regular = <String>[];
  final blobs = <String, String>{};
  for (final path in paths) {
    final filePath = p.join(root, p.joinAll(p.posix.split(path)));
    switch (FileSystemEntity.typeSync(filePath, followLinks: false)) {
      case FileSystemEntityType.file:
        regular.add(path);
      case FileSystemEntityType.link:
        blobs[path] = await _workingLinkBlobId(root, filePath);
      default:
        break;
    }
  }
  if (regular.isEmpty) return blobs;
  final process = await Process.start('git', [
    'hash-object',
    '--stdin-paths',
  ], workingDirectory: root);
  final output = process.stdout.transform(utf8.decoder).join();
  final error = process.stderr.transform(utf8.decoder).join();
  for (final path in regular) {
    final quoted = utf8
        .encode(path)
        .map(
          (byte) => byte >= 32 && byte < 127 && byte != 34 && byte != 92
              ? String.fromCharCode(byte)
              : '\\${byte.toRadixString(8).padLeft(3, '0')}',
        )
        .join();
    process.stdin.writeln('"$quoted"');
  }
  await process.stdin.close();
  final code = await process.exitCode;
  final stderr = await error;
  if (code != 0) {
    throw FormatException('Git baseline unavailable: $stderr'.trim());
  }
  final ids = LineSplitter.split(await output).toList();
  if (ids.length != regular.length) {
    throw const FormatException(
      'Git baseline unavailable: incomplete file hashes',
    );
  }
  for (var i = 0; i < regular.length; i++) {
    blobs[regular[i]] = ids[i];
  }
  return blobs;
}

Future<String> _workingLinkBlobId(String root, String filePath) async {
  // Git stores a symlink's target verbatim, without clean/eol filters.
  final process = await Process.start('git', [
    'hash-object',
    '--stdin',
  ], workingDirectory: root);
  final output = process.stdout.transform(utf8.decoder).join();
  final error = process.stderr.transform(utf8.decoder).join();
  process.stdin.add(utf8.encode(Link(filePath).targetSync()));
  await process.stdin.close();
  final code = await process.exitCode;
  final stderr = await error;
  if (code != 0) {
    throw FormatException('Git baseline unavailable: $stderr'.trim());
  }
  return (await output).trim();
}
