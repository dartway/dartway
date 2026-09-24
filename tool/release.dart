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
//   2  the question could not be put at all — pub.dev unreachable, or this was
//      not run from the repository root. Not an answer, an unknown; the same
//      third code the other tools here use, and for the same reason.

import 'dart:convert';
import 'dart:io';

import 'package:dartway_repo_tools/dartway_repo_tools.dart';

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

  // Every local package, published or not: `publish_to: none` ones are
  // excluded from the plan below, but a plan package can still depend on one
  // — which is exactly the bug this script once had, and `localShapes` is
  // what lets `unresolvableDependenciesOf` see it.
  final rawPubspecs = _rawPubspecs();

  final packages = rawPubspecs
      .where((p) => !p.publishToNone)
      .map(_Package.new)
      .toList();
  final localShapes = {
    for (final raw in rawPubspecs)
      raw.name: LocalPackageShape(
        name: raw.name,
        publishToNone: raw.publishToNone,
      ),
  };
  if (packages.isEmpty) {
    stderr.writeln(
      'No publishable packages found under packages/. '
      'Run this from the repository root.',
    );
    exit(2);
  }

  stdout.writeln('Asking $_host about ${packages.length} packages…');
  final published = <String, Map<String, DateTime>>{};
  for (final package in packages) {
    try {
      published[package.name] = await _versionsOf(package.name);
    } on _Unreachable catch (failure) {
      stderr.writeln(
        'Could not ask $_host about ${package.name}: '
        '${failure.reason}',
      );
      exit(2);
    }
  }

  final List<_Package> plan;
  try {
    plan = ReleaseOrder.of(
      packages
          .where((p) => !published[p.name]!.containsKey(p.version))
          .toList(),
    );
    ReleaseOrder.verify(plan);
  } on StateError catch (failure) {
    // The header states what each exit code means, and a promise about
    // behaviour is checked the same way as any other: an ordering failure is
    // "something is wrong", so it leaves by that door rather than through
    // Dart's uncaught-exception path with a stack trace and code 255.
    stderr.writeln(failure.message);
    exit(1);
  }

  // Does every dependency the plan states actually resolve — from the plan
  // itself, or from what pub.dev already has? Before printing the plan, not
  // just before publishing it: a plan that cannot work is not a plan to look
  // at either.
  final unresolvable = unresolvableDependenciesOf(
    plan,
    localPackages: localShapes,
    pubDevVersions: {
      for (final MapEntry(key: name, value: versions) in published.entries)
        name: versions.keys.toSet(),
    },
  );
  if (unresolvable.isNotEmpty) {
    stderr.writeln(
      '\nRefusing to plan a release: '
      '${unresolvable.length} dependency/ies would not resolve.\n',
    );
    for (final problem in unresolvable) {
      stderr.writeln('  - $problem');
    }
    exit(1);
  }

  // A package this run leaves alone because pub.dev already has the version
  // this tree states — the only place `dartway_shared_preferences`,
  // `dartway_telegram` and `dartway_studio_bridge` were visible as behind
  // their own code, before each was found by hand and moved a minor (#307).
  final unchanged = packages.where(
    (p) => published[p.name]!.containsKey(p.version),
  );
  final stale = staleVersionsAmong(
    unchanged.map(
      (p) => (name: p.name, version: p.version, directory: p.directory),
    ),
    publishedAt: (name, version) => published[name]?[version],
    changedPathsSince: _changedPathsSince,
  );
  if (stale.isNotEmpty) {
    stderr.writeln(
      '\nRefusing to plan a release: '
      '${stale.length} package(s) changed since the last release without a '
      'version move.\n',
    );
    for (final problem in stale) {
      stderr.writeln('  - $problem');
    }
    exit(1);
  }

  if (plan.isEmpty) {
    stdout.writeln(
      '\n✓ every package is published at the version this tree '
      'states. Nothing to release.',
    );
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
    final was = known.isEmpty
        ? 'NEW — never published'
        : 'was ${_newest(known.keys.toSet())}';
    stdout.writeln(
      '  ${(i + 1).toString().padLeft(2)}. '
      '${p.name.padRight(32)} ${p.version.padRight(9)} ($was)',
    );
  }

  if (!publish) {
    stdout.writeln('\nThis was the plan only. Add --publish to carry it out.');
    stdout.writeln(
      'A published version cannot be withdrawn — only retracted, '
      'and it stays visible.',
    );
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

    final result = Process.runSync('dart', [
      'pub',
      'publish',
      '--force',
    ], workingDirectory: p.directory);
    stdout.write(result.stdout);
    if (result.exitCode != 0) {
      stderr.write(result.stderr);
      stderr.writeln(
        '\n✗ ${p.name} failed to publish. Stopping here: the '
        'packages after it in the order state carets on what did not go out.',
      );
      stderr.writeln(
        'Published in this run: '
        '${plan.take(i).map((e) => e.name).join(', ')}',
      );
      exit(1);
    }

    if (i + 1 == plan.length) continue;
    if (!await _becameVisible(p)) {
      stderr.writeln(
        '\n✗ ${p.name} ${p.version} published, but $_host still '
        'does not list it after ${_visibilityTimeout.inMinutes} minutes. '
        'Stopping rather than failing the next package on version solving.',
      );
      exit(1);
    }
  }

  stdout.writeln('\n✓ published ${plan.length} package(s).');
  stdout.writeln(
    'The release is not finished: `stable` is moved by the '
    'promotion ritual in CLAUDE.md, not by this script.',
  );
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

/// Every `pubspec.yaml` under `packages/`, published or not.
///
/// `publish_to: none` used to be the filter applied *here*, which is exactly
/// how a `publish_to: none` package went missing from the whole script rather
/// than merely from what it publishes: nothing downstream could tell "this
/// dependency is already out" from "this dependency does not exist in this
/// tree at all, and never can". Both are now kept, on every raw entry, so
/// `unresolvableDependenciesOf` can tell them apart.
List<_RawPubspec> _rawPubspecs() {
  final found = <_RawPubspec>[];
  for (final directory
      in Directory('packages').existsSync()
          ? Directory(
              'packages',
            ).listSync(recursive: true).whereType<Directory>()
          : <Directory>[]) {
    final pubspec = File('${directory.path}/pubspec.yaml');
    if (!pubspec.existsSync()) continue;

    final lines = pubspec.readAsLinesSync();
    final name = pubspecValue(lines, 'name');
    final version = pubspecValue(lines, 'version');
    if (name == null || version == null) continue;

    found.add(
      _RawPubspec(
        name: name,
        version: version,
        directory: directory.path,
        publishToNone: pubspecValue(lines, 'publish_to') != null,
        dependencyConstraints: dartwayDependencyConstraints(lines),
      ),
    );
  }
  found.sort((a, b) => a.name.compareTo(b.name));
  return found;
}

/// Commit dates touching [directory]'s `lib/`, `bin/` or `pubspec.yaml` at or
/// after [since] — what `staleVersionsAmong` judges a published version by.
///
/// `--name-only` with an empty `--pretty` format prints one path per touched
/// file and nothing else; a path git does not track (`bin/` on a package with
/// none) is simply never mentioned, so no existence check is needed first.
List<String> _changedPathsSince(String directory, DateTime since) {
  final result = Process.runSync('git', [
    'log',
    '--since=${since.toIso8601String()}',
    '--name-only',
    '--pretty=format:',
    '--',
    '$directory/lib',
    '$directory/bin',
    '$directory/pubspec.yaml',
  ]);
  if (result.exitCode != 0) return const [];
  final paths = (result.stdout as String)
      .split('\n')
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .toSet()
      .toList();
  paths.sort();
  return paths;
}

Future<bool> _becameVisible(_Package package) async {
  final deadline = DateTime.now().add(_visibilityTimeout);
  stdout.write('   waiting for $_host to list ${package.version}');
  while (DateTime.now().isBefore(deadline)) {
    await Future<void>.delayed(const Duration(seconds: 5));
    try {
      if ((await _versionsOf(package.name)).containsKey(package.version)) {
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

/// Every version of [package] that exists on pub.dev, with when it was
/// published; empty when the package has never been published.
///
/// The publish timestamp travels alongside the version for
/// `staleVersionsAmong` (see `release_freshness.dart` for why it is the
/// timestamp this script judges a package's freshness by, not a git tag).
Future<Map<String, DateTime>> _versionsOf(String package) async {
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
      for (final entry in versions)
        (entry as Map)['version'] as String: DateTime.parse(
          entry['published'] as String,
        ),
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

/// One `packages/*/pubspec.yaml`, as read off disk — the input both
/// `_Package` (what a plan publishes) and `LocalPackageShape` (what
/// `unresolvableDependenciesOf` checks a dependency against) are built from.
class _RawPubspec {
  const _RawPubspec({
    required this.name,
    required this.version,
    required this.directory,
    required this.publishToNone,
    required this.dependencyConstraints,
  });

  final String name;
  final String version;
  final String directory;
  final bool publishToNone;
  final Map<String, String> dependencyConstraints;
}

class _Package implements ReleaseUnit, PlannedRelease {
  _Package(_RawPubspec raw)
    : name = raw.name,
      version = raw.version,
      directory = raw.directory,
      dependencyConstraints = raw.dependencyConstraints;

  @override
  final String name;
  final String version;
  final String directory;

  @override
  Set<String> get dependencies => dependencyConstraints.keys.toSet();

  @override
  final Map<String, String> dependencyConstraints;
}

class _Unreachable implements Exception {
  const _Unreachable(this.reason);
  final String reason;
}
