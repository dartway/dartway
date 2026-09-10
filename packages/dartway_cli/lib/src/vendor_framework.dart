// Puts a monorepo checkout's framework packages inside a created project, so
// that images and builds can be made from code that is not published yet.
//
// `dartway create` strips the monorepo's `dependency_overrides` on purpose:
// the paths lead nowhere in a standalone project, and what is left resolves
// from pub.dev the way a stranger's project does. That is right for a stranger
// and wrong for a check that is asking about *this tree* — and the difference
// stayed invisible while only patch versions were released. A minor bump under
// a zero major puts the skeleton's carets past anything published (`^0.13.0`
// against `0.12.1`), and the build then fails inside `pub get` for a reason
// that says nothing about what was being checked.
//
// Two questions were sharing one answer. "Does this tree still produce a
// project that builds" is one; "is what a stranger receives installable" is a
// release question, and `tool/caret_check.dart` asks pub.dev directly. This
// library serves the first.

import 'dart:io';

import 'package:path/path.dart' as p;

/// Where the copies land, relative to the project root. Inside the project
/// because a Docker build context cannot reach above itself.
const vendorDirName = 'dartway_framework';

/// Copies the packages of [monorepo] into [project], overrides every dartway
/// dependency onto the copies, and makes the result reachable from a Docker
/// build. Answers with the lines describing what it did.
List<String> vendorFramework({
  required Directory project,
  required Directory monorepo,
}) {
  final packagesDir = Directory(p.join(monorepo.path, 'packages'));
  if (!packagesDir.existsSync()) {
    throw ArgumentError('No packages/ in ${monorepo.path} — is this the monorepo?');
  }

  final vendored = _copyPackages(packagesDir, project);
  final report = <String>[
    'Vendored ${vendored.length} packages into $vendorDirName/',
    for (final path in _overrideProjectPubspecs(
      project,
      vendored,
      _dependenciesByPackage(project),
    ))
      '  overrode dependencies in $path',
  ];
  if (_admitVendorDirToDockerContext(project)) {
    report.add('  admitted $vendorDirName/ into .dockerignore');
  }
  for (final dockerfile in _copyVendorDirInDockerfiles(project)) {
    report.add('  taught $dockerfile to copy $vendorDirName/');
  }
  return report;
}

/// Copies every package of the monorepo into the project, and answers with
/// package name -> path relative to a package directory of the project.
Map<String, String> _copyPackages(Directory packagesDir, Directory project) {
  final target = Directory(p.join(project.path, vendorDirName));
  if (target.existsSync()) target.deleteSync(recursive: true);

  final vendored = <String, String>{};
  for (final pubspec in _packagePubspecs(packagesDir)) {
    final name = _packageName(pubspec);
    if (name == null) continue;
    final source = pubspec.parent;
    final destination = Directory(p.join(target.path, name));
    _copyDirectory(source, destination);
    _stripWorkspaceResolution(File(p.join(destination.path, 'pubspec.yaml')));
    // Relative to a package of the project, which is one level down from its
    // root — the same shape the monorepo's own overrides have.
    vendored[name] = '../$vendorDirName/$name';
  }
  return vendored;
}

Iterable<File> _packagePubspecs(Directory packagesDir) sync* {
  for (final entity in packagesDir.listSync(recursive: true)) {
    if (entity is! File || p.basename(entity.path) != 'pubspec.yaml') continue;
    final path = entity.path;
    // A package's own example or test fixture is not a package of ours.
    if (path.contains('/example/') ||
        path.contains('/.dart_tool/') ||
        path.contains('/build/')) {
      continue;
    }
    yield entity;
  }
}

String? _packageName(File pubspec) {
  for (final line in pubspec.readAsLinesSync()) {
    if (line.startsWith('name:')) {
      return line.substring('name:'.length).trim();
    }
  }
  return null;
}

/// Directories that have no business in a build context, and would multiply
/// its size by the number of packages if they travelled.
const _skipped = {'.dart_tool', 'build', 'example', '.fvm', 'ephemeral'};

void _copyDirectory(Directory source, Directory destination) {
  destination.createSync(recursive: true);
  for (final entity in source.listSync(followLinks: false)) {
    final name = p.basename(entity.path);
    if (_skipped.contains(name)) continue;
    if (entity is Directory) {
      _copyDirectory(entity, Directory(p.join(destination.path, name)));
    } else if (entity is File) {
      if (name == 'pubspec.lock') continue;
      entity.copySync(p.join(destination.path, name));
    }
  }
}

/// Every package of the project gets overrides for the framework packages it
/// actually reaches, and for nothing else.
///
/// Not for all of them: an override is resolved whether or not anything
/// depends on it, so overriding the whole set drags `dartway_telegram` — and
/// its `flutter:` from the SDK — into the pure-Dart server image, where the
/// Flutter SDK does not exist and `dart pub get` refuses the solve. The reach
/// is transitive, because the framework's dependencies on each other carry the
/// same unpublished carets as the project's own.
List<String> _overrideProjectPubspecs(
  Directory project,
  Map<String, String> vendored,
  Map<String, Set<String>> dependenciesByPackage,
) {
  final rewritten = <String>[];
  for (final entity in project.listSync()) {
    if (entity is! Directory) continue;
    if (p.basename(entity.path) == vendorDirName) continue;
    final pubspec = File(p.join(entity.path, 'pubspec.yaml'));
    if (!pubspec.existsSync()) continue;

    final content = pubspec.readAsStringSync();
    final reached = reachableFrom(
      dartwayDependenciesOf(content),
      dependenciesByPackage,
    );
    pubspec.writeAsStringSync(
      withOverrides(content, {
        for (final name in reached)
          if (vendored.containsKey(name)) name: vendored[name]!,
      }),
    );
    rewritten.add(p.relative(pubspec.path, from: project.path));
  }
  return rewritten;
}

/// [pubspec] with a `dependency_overrides` block naming every package of
/// [vendored]. Any block already there is replaced: `dartway create` removes
/// the monorepo's, and a second run of this script must not stack a third.
String withOverrides(String pubspec, Map<String, String> vendored) {
  final lines = _withoutOverrides(pubspec.split('\n'));
  final block = <String>[
    '',
    '# Written by tool/vendor_framework.dart: this project is built from a',
    '# monorepo checkout rather than from pub.dev, because the versions it',
    '# asks for are not released yet.',
    'dependency_overrides:',
    for (final name in vendored.keys.toList()..sort())
      '  $name:\n    path: ${vendored[name]}',
  ];
  while (lines.isNotEmpty && lines.last.trim().isEmpty) {
    lines.removeLast();
  }
  return '${[...lines, ...block].join('\n')}\n';
}

List<String> _withoutOverrides(List<String> lines) {
  final start = lines.indexWhere(
    (line) => line.trimRight() == 'dependency_overrides:',
  );
  if (start == -1) return lines;
  var end = start + 1;
  while (end < lines.length &&
      (lines[end].trim().isEmpty || lines[end].startsWith(' '))) {
    end++;
  }
  return [...lines.sublist(0, start), ...lines.sublist(end)];
}

void _stripWorkspaceResolution(File pubspec) {
  if (!pubspec.existsSync()) return;
  final kept = pubspec
      .readAsLinesSync()
      .where((line) => line.trimRight() != 'resolution: workspace')
      .toList();
  pubspec.writeAsStringSync('${kept.join('\n')}\n');
}

/// The project's `.dockerignore` denies everything and admits the packages the
/// Dockerfiles copy by name, so a folder that arrived after it was written is
/// invisible to the build until it is listed.
bool _admitVendorDirToDockerContext(Directory project) {
  final dockerignore = File(p.join(project.path, '.dockerignore'));
  if (!dockerignore.existsSync()) return false;
  final content = dockerignore.readAsStringSync();
  if (content.contains('!$vendorDirName/')) return false;
  dockerignore.writeAsStringSync(
    '$content\n'
    '# Vendored by tool/vendor_framework.dart for the image check.\n'
    '!$vendorDirName/\n'
    '!$vendorDirName/**\n'
    '$vendorDirName/**/.dart_tool/\n'
    '$vendorDirName/**/build/\n',
  );
  return true;
}

/// Teaches the project's Dockerfiles to copy the vendored packages in.
///
/// Admitting the folder to the build context is only half of it: a Dockerfile
/// copies the packages it names, one by one and deliberately — a path
/// dependency whose directory never enters the image fails inside `pub get` as
/// a bare exit code 66, three layers from the cause. The template cannot carry
/// this line, because in a real project the folder does not exist and `COPY`
/// of a missing path fails the build. So it is written here, into the copy CI
/// throws away.
List<String> _copyVendorDirInDockerfiles(Directory project) {
  final taught = <String>[];
  for (final entity in project.listSync()) {
    if (entity is! Directory) continue;
    final dockerfile = File(p.join(entity.path, 'Dockerfile'));
    if (!dockerfile.existsSync()) continue;

    final content = dockerfile.readAsStringSync();
    if (content.contains('COPY $vendorDirName/')) continue;
    final taughtContent = withVendorCopy(content);
    if (taughtContent == content) continue;

    dockerfile.writeAsStringSync(taughtContent);
    taught.add(p.relative(dockerfile.path, from: project.path));
  }
  return taught;
}

/// [dockerfile] with the vendor directory copied in next to the project's own
/// packages: after the last `COPY` that precedes the `pub get` reading them.
///
/// Anchored on `pub get` rather than on the last `COPY` in the file, because
/// the last one belongs to another stage — the web image copies an nginx
/// config into the runtime stage, where a build-time package directory has no
/// business being.
String withVendorCopy(String dockerfile) {
  final lines = dockerfile.split('\n');
  final resolve = lines.indexWhere(
    (line) => line.startsWith('RUN ') && line.contains('pub get'),
  );
  if (resolve == -1) return dockerfile;

  final lastCopy = lines
      .sublist(0, resolve)
      .lastIndexWhere(
        (line) => line.startsWith('COPY ') && !line.contains('--from='),
      );
  if (lastCopy == -1) return dockerfile;

  lines.insert(lastCopy + 1, 'COPY $vendorDirName/ $vendorDirName/');
  return lines.join('\n');
}

/// What each vendored package depends on, among the vendored ones.
Map<String, Set<String>> _dependenciesByPackage(Directory project) {
  final vendorDir = Directory(p.join(project.path, vendorDirName));
  if (!vendorDir.existsSync()) return const {};

  return {
    for (final entity in vendorDir.listSync().whereType<Directory>())
      if (File(p.join(entity.path, 'pubspec.yaml')).existsSync())
        p.basename(entity.path): dartwayDependenciesOf(
          File(p.join(entity.path, 'pubspec.yaml')).readAsStringSync(),
        ),
  };
}

/// The `dartway_*` packages [pubspec] names as dependencies of its own.
///
/// Read line by line rather than with a YAML parser: the question is which
/// names appear as keys under a dependency section, and the answer survives
/// the pubspecs this repository actually writes. `dependency_overrides` is
/// skipped — it is what this script writes, and reading it back would make a
/// second run inherit the first one's reach.
Set<String> dartwayDependenciesOf(String pubspec) {
  const sections = {'dependencies:', 'dev_dependencies:'};
  final found = <String>{};
  var inSection = false;
  for (final line in pubspec.split('\n')) {
    if (line.isNotEmpty && !line.startsWith(' ') && !line.startsWith('#')) {
      inSection = sections.contains(line.trimRight());
      continue;
    }
    if (!inSection) continue;
    final match = RegExp(r'^  ([a-z0-9_]+):').firstMatch(line);
    if (match != null && match.group(1)!.startsWith('dartway_')) {
      found.add(match.group(1)!);
    }
  }
  return found;
}

/// [roots] and everything they reach through [dependencies].
Set<String> reachableFrom(
  Set<String> roots,
  Map<String, Set<String>> dependencies,
) {
  final reached = <String>{};
  final pending = [...roots];
  while (pending.isNotEmpty) {
    final name = pending.removeLast();
    if (!reached.add(name)) continue;
    pending.addAll(dependencies[name] ?? const <String>{});
  }
  return reached;
}
