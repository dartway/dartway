// Are the committed lockfiles telling the truth about our own packages?
//
// Every lockfile in the tree records a `version:` for each path-overridden
// local package. That number is a copy of what the package's `pubspec.yaml`
// said the last time the lock was written, and nothing keeps the copy in step:
// bump a package and the locks go stale silently, so the next `pub get` in any
// tree rewrites them and the tree dirties itself for reasons that have nothing
// to do with the task. `CLAUDE.md` makes a clean tree mean "another session is
// working here", so the noise costs more than it looks.
//
// Usage: dart run tool/lock_check.dart   (from the repository root)
// Exits 1 and names every stale entry; exits 0 and says so when there are none.
// `tool/self_check.dart` runs this together with its siblings.

import 'dart:io';

import 'check_result.dart';

void main() {
  final report = checkLockfiles();
  report.findings.forEach(stdout.writeln);
  stdout.writeln(report.summary);
  if (report.exitCode != 0) exit(report.exitCode);
}

CheckReport checkLockfiles() {
  const title = 'lockfiles';
  final root = Directory.current;
  final locks =
      root
          .listSync(recursive: true, followLinks: false)
          .whereType<File>()
          .where((f) => f.path.endsWith('pubspec.lock'))
          .where(
            (f) =>
                !f.path.contains('/.dart_tool/') && !f.path.contains('/build/'),
          )
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));

  final stale = <String>[];

  for (final lock in locks) {
    final relative = lock.path.replaceFirst('${root.path}/', '');
    for (final entry in _pathEntries(lock)) {
      final pubspec = File(
        _normalise('${lock.parent.path}/${entry.path}/pubspec.yaml'),
      );
      if (!pubspec.existsSync()) {
        stale.add('$relative: ${entry.name} points at a package that is gone');
        continue;
      }
      final declared = _version(pubspec);
      if (declared != null && declared != entry.version) {
        stale.add(
          '$relative: ${entry.name} locked ${entry.version}, '
          'package declares $declared',
        );
      }
    }
  }

  if (stale.isEmpty) {
    return const CheckReport.ok(
      title,
      '✓ every lockfile agrees with the packages it locks',
    );
  }

  return CheckReport.findings(
    title,
    stale,
    '${stale.length} stale entr${stale.length == 1 ? 'y' : 'ies'}. '
    'Fix: `flutter pub get` in each tree above and commit the lockfile.',
  );
}

/// The lockfile entries resolved through a local path, one record each.
///
/// Parsed by tracking the entry a line belongs to rather than by a pattern
/// spanning lines: a pattern that may cross a blank line silently reads the
/// name of one entry together with the path of the next, which is how the
/// first draft of this reported `_fe_analyzer_shared` as one of ours.
Iterable<_Locked> _pathEntries(File lock) sync* {
  String? name, path, version;
  var isPath = false;

  for (final line in lock.readAsLinesSync()) {
    final start = RegExp(r'^  ([A-Za-z0-9_]+):$').firstMatch(line);
    if (start != null) {
      if (name != null && isPath && path != null && version != null) {
        yield _Locked(name, path, version);
      }
      name = start.group(1);
      path = null;
      version = null;
      isPath = false;
      continue;
    }
    if (name == null) continue;

    path ??= RegExp(r'^      path: "(.*)"$').firstMatch(line)?.group(1);
    version ??= RegExp(r'^    version: "(.*)"$').firstMatch(line)?.group(1);
    if (line == '    source: path') isPath = true;
  }

  if (name != null && isPath && path != null && version != null) {
    yield _Locked(name, path, version);
  }
}

String? _version(File pubspec) => RegExp(
  r'^version:\s*(\S+)',
  multiLine: true,
).firstMatch(pubspec.readAsStringSync())?.group(1);

/// Collapses the `../..` a lockfile path is written with.
String _normalise(String path) {
  final parts = <String>[];
  for (final part in path.split('/')) {
    if (part == '..' && parts.isNotEmpty && parts.last != '..') {
      parts.removeLast();
    } else if (part != '.') {
      parts.add(part);
    }
  }
  return parts.join('/');
}

class _Locked {
  const _Locked(this.name, this.path, this.version);
  final String name;
  final String path;
  final String version;
}
