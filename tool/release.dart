// What a release publishes, in the order it has to be published in.
//
// A release here is two acts, and only one of them was written down. The
// promotion ritual for `stable` lives in the root `CLAUDE.md` and gets done;
// publishing to pub.dev is done by hand, was documented nowhere, and therefore
// accumulated — by 2026-09-03 eleven packages sat ahead of what was published
// and six had never been published at all, while `stable` had twice moved past
// pub.dev on its own. Nothing inside the monorepo notices: `dependency_overrides`
// hide every constraint until `dartway create` strips them in a stranger's tree.
//
// So this script answers the two questions a person cannot hold in their head:
// **what is behind**, and **in what order it may go out**. A package cannot be
// published before one it states a caret on — inside the workspace that
// dependency resolves locally and the ordering is invisible.
//
// Usage:
//   dart run tool/release.dart              the plan, and nothing else
//   dart run tool/release.dart --publish    publish it
//
// Exit codes, the same three the other tools use:
//   0  nothing to publish, or the plan printed / everything published
//   1  something is wrong, or a publication failed
//   2  pub.dev could not be asked at all — not a finding, an unknown

import 'dart:convert';
import 'dart:io';

const _host = 'pub.dev';

/// How long to wait for a just-published version to become visible.
///
/// Not politeness: the next package in the order states a caret on the one
/// before it, and `dart pub publish` resolves against the live index. Publishing
/// the dependent while the index still shows the old version fails on version
/// solving, halfway through a release, with some packages already out.
const _visibilityTimeout = Duration(minutes: 3);

Future<void> main(List<String> args) async {
  final publish = args.contains('--publish');
  final unknown = args.where((a) => a != '--publish');
  if (unknown.isNotEmpty) {
    stderr.writeln('unknown argument: ${unknown.first}');
    stderr.writeln('usage: dart run tool/release.dart [--publish]');
    exit(64);
  }

  final packages = _packages();
  if (packages.isEmpty) {
    stderr.writeln(
      'No publishable packages found under packages/. '
      'Run this from the repository root.',
    );
    exit(2);
  }

  stdout.writeln('Asking $_host about ${packages.length} packages…');
  final published = <String, Set<String>>{};
  for (final package in packages) {
    try {
      published[package.name] = await _versionsOf(package.name);
    } on _Unreachable catch (failure) {
      stderr.writeln('Could not ask $_host about ${package.name}: '
          '${failure.reason}');
      exit(2);
    }
  }

  final plan = _order(
    packages.where((p) => !published[p.name]!.contains(p.version)).toList(),
  );
  _verifyOrder(plan);

  if (plan.isEmpty) {
    stdout.writeln('\n✓ every package is published at the version this tree '
        'states. Nothing to release.');
    return;
  }

  stdout.writeln('\n${plan.length} package(s) to publish, in order:\n');
  for (var i = 0; i < plan.length; i++) {
    final p = plan[i];
    final known = published[p.name]!;
    // A first publication is a different act from an update: it claims the name
    // on pub.dev permanently and makes the package public with whatever
    // maturity it has. Saying which is which is the whole reason to print a
    // plan rather than just publishing.
    final was = known.isEmpty ? 'NEW — never published' : 'was ${_newest(known)}';
    stdout.writeln('  ${(i + 1).toString().padLeft(2)}. '
        '${p.name.padRight(32)} ${p.version.padRight(9)} ($was)');
  }

  if (!publish) {
    stdout.writeln('\nThis was the plan only. Add --publish to carry it out.');
    stdout.writeln('A published version cannot be withdrawn — only retracted, '
        'and it stays visible.');
    return;
  }

  final refusal = _refuseToPublishBecause();
  if (refusal != null) {
    stderr.writeln('\nRefusing to publish: $refusal');
    exit(1);
  }

  for (var i = 0; i < plan.length; i++) {
    final p = plan[i];
    stdout.writeln('\n── ${i + 1}/${plan.length} ${p.name} ${p.version}');

    final result = Process.runSync(
      'dart',
      ['pub', 'publish', '--force'],
      workingDirectory: p.directory,
    );
    stdout.write(result.stdout);
    if (result.exitCode != 0) {
      stderr.write(result.stderr);
      stderr.writeln('\n✗ ${p.name} failed to publish. Stopping here: the '
          'packages after it in the order state carets on what did not go out.');
      stderr.writeln('Published in this run: '
          '${plan.take(i).map((e) => e.name).join(', ')}');
      exit(1);
    }

    if (i + 1 == plan.length) continue;
    if (!await _becameVisible(p)) {
      stderr.writeln('\n✗ ${p.name} ${p.version} published, but $_host still '
          'does not list it after ${_visibilityTimeout.inMinutes} minutes. '
          'Stopping rather than failing the next package on version solving.');
      exit(1);
    }
  }

  stdout.writeln('\n✓ published ${plan.length} package(s).');
  stdout.writeln('The release is not finished: `stable` is moved by the '
      'promotion ritual in CLAUDE.md, not by this script.');
}

/// Why publishing must not start, or null when it may.
///
/// Publishing takes whatever is in the working tree, so the guards are about
/// *what* would go out rather than about tidiness: a branch, an uncommitted
/// edit or a local commit that has not been through review each publish code
/// nobody has read, irreversibly.
String? _refuseToPublishBecause() {
  String git(List<String> args) =>
      (Process.runSync('git', args).stdout as String).trim();

  final branch = git(['rev-parse', '--abbrev-ref', 'HEAD']);
  if (branch != 'master') {
    return 'HEAD is on "$branch". A release is cut from master.';
  }
  if (git(['status', '--porcelain']).isNotEmpty) {
    return 'the working tree has uncommitted changes, and publishing would '
        'ship them.';
  }
  final head = git(['rev-parse', 'HEAD']);
  final remote = git(['rev-parse', 'origin/master']);
  if (head.isEmpty || remote.isEmpty) return 'could not read git revisions.';
  if (head != remote) {
    return 'HEAD ($head) is not origin/master ($remote). Fetch, fast-forward, '
        'and publish what review has seen.';
  }
  return null;
}

/// Every publishable package in the workspace.
///
/// `publish_to: none` marks the ones that exist to be run rather than depended
/// on — the two `example` packages — and they are skipped by that mark rather
/// than by name, so a third one needs no edit here.
List<_Package> _packages() {
  final found = <_Package>[];
  for (final directory in Directory('packages').existsSync()
      ? Directory('packages').listSync(recursive: true).whereType<Directory>()
      : <Directory>[]) {
    final pubspec = File('${directory.path}/pubspec.yaml');
    if (!pubspec.existsSync()) continue;

    final lines = pubspec.readAsLinesSync();
    String? valueOf(String key) {
      for (final line in lines) {
        final match = RegExp('^$key:\\s*(\\S+)\\s*\$').firstMatch(line);
        if (match != null) return match.group(1);
      }
      return null;
    }

    if (valueOf('publish_to') != null) continue;
    final name = valueOf('name');
    final version = valueOf('version');
    if (name == null || version == null) continue;

    found.add(_Package(name, version, directory.path, _dependencies(lines)));
  }
  found.sort((a, b) => a.name.compareTo(b.name));
  return found;
}

/// The `dartway_*` packages this one depends on for real.
///
/// `dependency_overrides` is skipped on purpose: it is the block that makes the
/// workspace resolve locally, it never travels to anyone's project, and reading
/// it here would invent an ordering constraint that does not exist on pub.dev.
Set<String> _dependencies(List<String> lines) {
  final deps = <String>{};
  var section = '';
  for (final line in lines) {
    final top = RegExp(r'^([a-z_]+):').firstMatch(line);
    if (top != null) {
      section = top.group(1)!;
      continue;
    }
    if (section != 'dependencies') continue;
    final entry = RegExp(r'^\s+(dartway_[a-z0-9_]+):').firstMatch(line);
    if (entry != null) deps.add(entry.group(1)!);
  }
  return deps;
}

/// The plan, ordered so that nothing is published before what it depends on.
///
/// Only packages inside the plan constrain each other: a dependency that is
/// already published at the version stated is on pub.dev before this run starts.
List<_Package> _order(List<_Package> plan) {
  final byName = {for (final p in plan) p.name: p};
  final ordered = <_Package>[];
  final placed = <String>{};

  // A dependency cycle cannot exist in a resolvable workspace, but a bug here
  // must not become an infinite loop in a script that publishes.
  while (ordered.length < plan.length) {
    final ready = plan
        .where((p) => !placed.contains(p.name))
        .where((p) => p.dependencies.every(
              (d) => !byName.containsKey(d) || placed.contains(d),
            ))
        .toList();

    if (ready.isEmpty) {
      final stuck = plan.where((p) => !placed.contains(p.name)).map((p) => p.name);
      throw StateError(
        'Cannot order the release: ${stuck.join(', ')} depend on each other. '
        'A cycle among dartway packages is not resolvable on pub.dev either.',
      );
    }

    for (final p in ready) {
      ordered.add(p);
      placed.add(p.name);
    }
  }
  return ordered;
}

/// Checks the answer the ordering just gave, before anything acts on it.
///
/// The order is the whole value of this script and the one thing a mistake in
/// it cannot be taken back from: publishing a dependent before its dependency
/// fails on version solving with part of the release already out, permanently.
/// So the result is verified rather than trusted — the check is four lines and
/// reads nothing the sort read.
void _verifyOrder(List<_Package> plan) {
  final position = {for (var i = 0; i < plan.length; i++) plan[i].name: i};
  for (var i = 0; i < plan.length; i++) {
    for (final dependency in plan[i].dependencies) {
      final at = position[dependency];
      if (at != null && at > i) {
        throw StateError(
          'Ordering is wrong: ${plan[i].name} would be published at ${i + 1}, '
          'before ${plan[at].name} at ${at + 1}, which it depends on. '
          'Refusing to act on it.',
        );
      }
    }
  }
}

Future<bool> _becameVisible(_Package package) async {
  final deadline = DateTime.now().add(_visibilityTimeout);
  stdout.write('   waiting for $_host to list ${package.version}');
  while (DateTime.now().isBefore(deadline)) {
    await Future<void>.delayed(const Duration(seconds: 5));
    try {
      if ((await _versionsOf(package.name)).contains(package.version)) {
        stdout.writeln(' — listed');
        return true;
      }
    } on _Unreachable {
      // A blip while waiting is not an answer; keep asking until the deadline.
    }
    stdout.write('.');
  }
  stdout.writeln();
  return false;
}

/// Every version of [package] that exists on pub.dev; empty when the package
/// has never been published.
///
/// Versions rather than "the latest": the question this script asks is whether
/// *this exact* version is already out, and a comparison would have to
/// re-implement semver ordering to answer it.
Future<Set<String>> _versionsOf(String package) async {
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 10);
  try {
    final request = await client.getUrl(
      Uri.https(_host, '/api/packages/$package'),
    );
    final response = await request.close().timeout(const Duration(seconds: 20));
    if (response.statusCode == 404) {
      await response.drain<void>();
      return const {};
    }
    if (response.statusCode != 200) {
      await response.drain<void>();
      throw _Unreachable('HTTP ${response.statusCode}');
    }
    final body = await response.transform(utf8.decoder).join();
    final versions = (jsonDecode(body) as Map)['versions'] as List?;
    if (versions == null) throw const _Unreachable('no versions in reply');
    return {
      for (final entry in versions) (entry as Map)['version'] as String,
    };
  } on _Unreachable {
    rethrow;
  } catch (error) {
    throw _Unreachable('$error');
  } finally {
    client.close(force: true);
  }
}

/// The newest of a set of version strings, for reporting only.
///
/// Sorted by numeric parts where they parse and lexically otherwise: this
/// decides what one line of output says, never what gets published.
String _newest(Set<String> versions) {
  final sorted = versions.toList()
    ..sort((a, b) {
      final pa = _parts(a);
      final pb = _parts(b);
      if (pa == null || pb == null) return a.compareTo(b);
      for (var i = 0; i < 3; i++) {
        final byPart = pa[i].compareTo(pb[i]);
        if (byPart != 0) return byPart;
      }
      return a.compareTo(b);
    });
  return sorted.last;
}

List<int>? _parts(String version) {
  final match = RegExp(r'^(\d+)\.(\d+)\.(\d+)$').firstMatch(version.trim());
  if (match == null) return null;
  return [for (var i = 1; i <= 3; i++) int.parse(match.group(i)!)];
}

class _Package {
  const _Package(this.name, this.version, this.directory, this.dependencies);
  final String name;
  final String version;
  final String directory;
  final Set<String> dependencies;
}

class _Unreachable implements Exception {
  const _Unreachable(this.reason);
  final String reason;
}
