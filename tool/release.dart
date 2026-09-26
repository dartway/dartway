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
//   dart run tool/release.dart --cut        cut the family off its
//                                            between-releases prerelease,
//                                            then print the plan (#337)
//   dart run tool/release.dart --publish    publish the plan
//
// Between releases the family lives on a prerelease (D-086); pub.dev receives
// the plain version. `--cut` does the mechanical part: the family's own
// version and every caret on it move together, workspace-wide, then the plan
// runs so the stale check (`release_freshness.dart`) names whichever
// satellites still need their own bump — a judgement call on their own
// `CHANGELOG.md`, so `--cut` does not make it. On an uncut tree the plan says
// so in one line instead of listing caret errors (`release_cut.dart`).
//
// Exit codes, the same three the other tools use:
//   0  nothing to publish, the plan printed, or everything published
//   1  something is wrong: a cut was refused, the family needs cutting
//      first, a plan cannot be trusted (unresolved dependency, stale
//      version, a missing CHANGELOG entry), publishing is partial, or a
//      publish failed. A plan-only run that cannot be trusted is not an
//      answer either — it exits the same 1 a `--publish` run would.
//   2  the question could not be put at all — pub.dev unreachable, or this was
//      not run from the repository root. Not an answer, an unknown; the same
//      third code the other tools here use, and for the same reason.

import 'dart:convert';
import 'dart:io';

import 'package:dartway_repo_tools/dartway_repo_tools.dart';
import 'package:yaml/yaml.dart';

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
  final cut = args.contains('--cut');
  final unknown = args.where((a) => a != '--publish' && a != '--cut');
  if (unknown.isNotEmpty) {
    stderr.writeln('unknown argument: ${unknown.first}');
    stderr.writeln('usage: dart run tool/release.dart [--cut | --publish]');
    exit(64);
  }
  if (cut && publish) {
    stderr.writeln(
      '--cut and --publish do not combine: cut writes the plain versions, '
      'let the plan (and a person) look at what it produced, then publish '
      'in a separate run.',
    );
    exit(64);
  }

  if (cut) {
    final refusal = _refuseToCutBecause();
    if (refusal != null) {
      stderr.writeln('Refusing to cut: $refusal');
      exit(1);
    }
    _cutFamilyPrerelease();
  }

  // Every local package, published or not: `publish_to: none` ones are
  // excluded from the plan below, but a plan package can still depend on one
  // — which is exactly the bug this script once had, and `localShapes` is
  // what lets `unresolvableDependenciesOf` see it. Read fresh, after a `--cut`
  // above may have just rewritten some of these files on disk.
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

  // Between releases the family sits on a prerelease (D-086); pub.dev only
  // ever receives the plain version, so every caret on the family would read
  // as unsatisfied — not because anything is broken, but because the release
  // has not been cut yet. Said in one line, before anything else, rather than
  // as a wall of caret errors that sends the reader looking for a dependency
  // problem that is not there (#337). A family that disagrees with itself is
  // left to the ordinary caret-by-caret checks below to describe.
  //
  // This exits 1, in a plan-only run exactly as it would under `--publish`
  // (review of PR #358): a plan that cannot work is not a plan to look at
  // either, and `release.dart` on `master` while the family sits on a
  // prerelease is exactly that — printing it and exiting 0 would have
  // `--publish` on the same tree exit clean having published nothing.
  final familyVersions = {
    for (final p in packages)
      if (familyPackageNames.contains(p.name)) p.name: p.version,
  };
  if (familyLockstepProblem(familyVersions) == null) {
    final version = familyVersion(familyVersions);
    if (plainOf(version) != null) {
      stderr.writeln(cutFirstMessage(version));
      exit(1);
    }
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

  // The synchronisation law's own item 6 (root CLAUDE.md): the package's
  // CHANGELOG.md. `dart pub publish --force` (below) is exactly what silences
  // pub's own warning about a missing entry, so this script has to ask
  // instead. `--cut` never writes this heading itself — it is human text —
  // so on a freshly cut tree this is what tells the maintainer to add it.
  final changelogProblems = <String>[];
  for (final p in plan) {
    final changelogFile = File('${p.directory}/CHANGELOG.md');
    if (!changelogFile.existsSync()) {
      changelogProblems.add('${p.name}: no CHANGELOG.md in ${p.directory}');
      continue;
    }
    final mismatch = changelogMismatch(
      changelogFile.readAsStringSync(),
      p.version,
    );
    if (mismatch != null) {
      changelogProblems.add('${p.name} ${p.version}: $mismatch');
    }
  }
  if (changelogProblems.isNotEmpty) {
    stderr.writeln(
      '\nRefusing to plan a release: ${changelogProblems.length} package(s) '
      "have no CHANGELOG.md entry for the version they'd publish.\n",
    );
    for (final problem in changelogProblems) {
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

  final firstPublications = plan
      .where((p) => published[p.name]!.isEmpty)
      .length;
  final firstPublicationsMessage = firstPublicationsLine(firstPublications);
  if (firstPublicationsMessage != null) {
    stdout.writeln('\n$firstPublicationsMessage');
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

  final byName = {for (final p in plan) p.name: p};
  final report = await publishRelease(
    plan,
    attempt: (unit) => _attemptPublish(byName[unit.name]!),
    confirmVisible: (unit) => _becameVisible(byName[unit.name]!),
    wait: (duration) => Future<void>.delayed(duration),
    log: stdout.writeln,
  );

  final outcome = describePublishOutcome(
    report,
    planNames: plan.map((p) => p.name).toList(),
  );
  for (final line in outcome.stdoutLines) {
    stdout.writeln(line);
  }
  for (final line in outcome.stderrLines) {
    stderr.writeln(line);
  }
  if (outcome.exitCode != 0) exit(outcome.exitCode);
}

/// Makes one `dart pub publish` attempt for [p] and classifies the result for
/// `publishRelease` — the only place this script actually shells out to
/// publish.
///
/// Only a successful attempt's output is printed here, live: a failure or a
/// rate limit is folded into the classification instead and printed exactly
/// once, by `describePublishOutcome` (via `main`) or by `publishRelease`'s own
/// retry log — never both (review of PR #358: the previous version printed a
/// failing attempt's stdout and stderr here, live, and then again in full as
/// part of the stop report).
Future<PublishAttempt> _attemptPublish(_Package p) async {
  final result = Process.runSync('dart', [
    'pub',
    'publish',
    '--force',
  ], workingDirectory: p.directory);
  final attempt = classifyPublishResult(
    exitCode: result.exitCode,
    stdout: result.stdout as String,
    stderr: result.stderr as String,
  );
  if (attempt is PublishOk) stdout.write(result.stdout);
  return attempt;
}

/// Why publishing must not start, or null when it may.
///
/// Publishing takes whatever is in the working tree, so the guards are about
/// *what* would go out rather than about tidiness: a branch, an uncommitted
/// edit or a local commit that has not been through review each publish code
/// nobody has read, irreversibly.
String? _refuseToPublishBecause() {
  final sdk = _refuseUnpinnedSdk('--publish');
  if (sdk != null) return sdk;

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

/// Why publishing must not run on this SDK, or null when it may — the same
/// question `tool/checks.sh` asks, for the same reason: a package built
/// against whatever Flutter happens to be on `PATH` is not what CI proved
/// green, and the failure surfaces as something unrelated to the SDK, months
/// later, in a stranger's project. `tool/checks.sh` cannot re-execute itself
/// under `fvm` because it also runs in CI, where `fvm` is not installed and
/// the version is pinned by the workflow instead; the same is true here.
String? _refuseUnpinnedSdk(String flag) {
  final fvmrc = File('.fvmrc');
  if (!fvmrc.existsSync()) {
    return 'no .fvmrc here — run this from the repository root.';
  }
  final pinned = RegExp(
    '"flutter"\\s*:\\s*"([^"]+)"',
  ).firstMatch(fvmrc.readAsStringSync())?.group(1);
  if (pinned == null) {
    return 'cannot read the pinned Flutter version out of .fvmrc.';
  }

  final result = Process.runSync('flutter', ['--version']);
  final running = result.exitCode == 0
      ? RegExp(r'^Flutter (\S+)').firstMatch(result.stdout as String)?.group(1)
      : null;
  if (running != pinned) {
    return 'Flutter ${running ?? 'not found'} is on PATH; this repository is '
        'written against $pinned — run under the pinned SDK: '
        'fvm exec dart run tool/release.dart $flag';
  }
  return null;
}

/// Why `--cut` must not run, or null when it may.
///
/// Deliberately simpler than [_refuseToPublishBecause]: a cut does not need
/// `master`, and does not need `HEAD` to be `origin/master` — it is meant to
/// be looked at (and re-run) before anything is committed. What it must not
/// do is start from a tree already holding someone else's unfinished edits,
/// or run `pub get` under the wrong SDK afterwards.
String? _refuseToCutBecause() {
  final sdk = _refuseUnpinnedSdk('--cut');
  if (sdk != null) return sdk;

  final status =
      (Process.runSync('git', ['status', '--porcelain']).stdout as String)
          .trim();
  if (status.isNotEmpty) {
    return 'the working tree has uncommitted changes — commit or discard '
        'them before cutting, so the cut itself is the only thing in the '
        'diff.';
  }
  return null;
}

/// Cuts the family off its between-releases prerelease (#337): its own
/// version and every caret on it, workspace-wide, then `dart pub get`
/// wherever a lockfile lives. Prints what it touched; refuses (without
/// writing anything) when the family is not in lockstep, and says so calmly,
/// without writing anything, when there is nothing to cut.
///
/// This does not commit anything — `--cut` hands back a working tree for a
/// person (or the rest of this run) to look at before either commits to it.
void _cutFamilyPrerelease() {
  final rawPubspecs = _rawPubspecs();
  final familyVersions = {
    for (final raw in rawPubspecs)
      if (familyPackageNames.contains(raw.name)) raw.name: raw.version,
  };

  final lockstepProblem = familyLockstepProblem(familyVersions);
  if (lockstepProblem != null) {
    stderr.writeln('Refusing to cut: $lockstepProblem');
    exit(1);
  }

  final from = familyVersion(familyVersions);
  final to = plainOf(from);
  if (to == null) {
    stdout.writeln(
      'The family is already at a plain version ($from) — nothing to cut.',
    );
    return;
  }

  stdout.writeln('Cutting the family from $from to $to:\n');
  final touched = <String>[];
  for (final file in _allPubspecFiles()) {
    final original = file.readAsStringSync();
    final rewritten = cutPubspecContents(original, from: from, to: to);
    if (rewritten == null) continue;
    file.writeAsStringSync(rewritten);
    touched.add(file.path);
  }
  touched.sort();
  for (final path in touched) {
    stdout.writeln('  cut $path');
  }
  if (touched.isEmpty) {
    // The lockstep check above already guarantees at least the family's own
    // six pubspecs carry `from` — reaching here would mean `cutPubspecContents`
    // and `familyVersion` disagree about what this tree holds, a bug in this
    // script rather than a state a tree can actually be in.
    stderr.writeln(
      'Refusing to cut: found nothing to rewrite for $from, which the '
      'family pubspecs themselves report carrying. This is a bug in '
      'release_cut.dart, not a state to publish from.',
    );
    exit(1);
  }

  stdout.writeln('\nResolving:\n');
  for (final directory in _pubGetDirectories()) {
    stdout.writeln('  pub get in $directory');
    final result = Process.runSync('flutter', [
      'pub',
      'get',
    ], workingDirectory: directory);
    if (result.exitCode != 0) {
      stdout.write(result.stdout);
      stderr.write(result.stderr);
      stderr.writeln('\npub get failed in $directory after the cut.');
      exit(1);
    }
  }
  stdout.writeln();
}

/// Every `pubspec.yaml` this repository ships or resolves against —
/// `packages/`, `template/`, `example/` and `tool/` itself, plus the
/// workspace root — not only `packages/`: `template/` and `example/` state
/// carets on the family too, and `--cut` has to reach every one of them.
Iterable<File> _allPubspecFiles() sync* {
  final root = File('pubspec.yaml');
  if (root.existsSync()) yield root;

  for (final directory in ['packages', 'template', 'example', 'tool']) {
    final dir = Directory(directory);
    if (!dir.existsSync()) continue;
    for (final entry in dir.listSync(recursive: true)) {
      if (entry is! File || !entry.path.endsWith('pubspec.yaml')) continue;
      if (entry.path.contains('/.dart_tool/') ||
          entry.path.contains('/build/')) {
        continue;
      }
      yield entry;
    }
  }
}

/// Every directory holding a `pubspec.lock` — where a version or caret change
/// needs `pub get` to re-resolve, after `--cut` rewrites the files above.
///
/// Walks the same directories `_allPubspecFiles` does, rather than the whole
/// repository tree: `js/*` resolves through `package.json`, not a
/// `pubspec.lock`, and a full recursive walk would also cross `.git`.
List<String> _pubGetDirectories() {
  final found = <String>[];
  if (File('pubspec.lock').existsSync()) found.add('.');

  for (final directory in ['packages', 'template', 'example', 'tool']) {
    final dir = Directory(directory);
    if (!dir.existsSync()) continue;
    for (final entry in dir.listSync(recursive: true)) {
      if (entry is! File || !entry.path.endsWith('pubspec.lock')) continue;
      if (entry.path.contains('/.dart_tool/') ||
          entry.path.contains('/build/')) {
        continue;
      }
      found.add(entry.parent.path);
    }
  }
  found.sort();
  return found;
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

    final YamlMap document;
    try {
      document = parsePubspec(pubspec.readAsStringSync());
    } on FormatException catch (error) {
      stderr.writeln('${pubspec.path}: $error');
      exit(1);
    }
    final name = pubspecValue(document, 'name');
    final version = pubspecValue(document, 'version');
    if (name == null || version == null) continue;

    final publishToNone = pubspecValue(document, 'publish_to') != null;

    // A `publish_to: none` package's own dependencies never reach
    // `unresolvableDependenciesOf`: only a planned (non-`none`) package's
    // `dependencyConstraints` are ever read, and a `none` package can never
    // be planned. Reading them anyway would fail this whole script on a
    // form `dartwayDependencyConstraints` refuses to guess at but that a
    // `publish_to: none` package is free to have — `dartway_core_flutter`'s
    // own tour depends on it by `path:`, on purpose, and correctly.
    final dependencyConstraints = <String, String>{};
    if (!publishToNone) {
      try {
        dependencyConstraints.addAll(dartwayDependencyConstraints(document));
      } on FormatException catch (error) {
        stderr.writeln('${pubspec.path}: $error');
        exit(1);
      }
    }

    found.add(
      _RawPubspec(
        name: name,
        version: version,
        directory: directory.path,
        publishToNone: publishToNone,
        dependencyConstraints: dependencyConstraints,
      ),
    );
  }
  found.sort((a, b) => a.name.compareTo(b.name));
  return found;
}

/// Paths under [directory] that a commit touched at or after [since] and
/// that count as shipped contents (`isArchiveRelevantPath`) — what
/// `staleVersionsAmong` judges a published version by.
///
/// The whole package directory, not a named few subpaths: the first version
/// of this check only watched `lib/`, `bin/` and `pubspec.yaml`, and missed
/// `dartway_push_firebase`'s `web/` (the service worker template) and
/// `dartway_push_rustore`'s `android/` (the native service) entirely — both
/// ship in the pub.dev archive and neither is `lib/`.
///
/// `--name-only` with an empty `--pretty` format prints one path per touched
/// file and nothing else; a path git does not track (`bin/` on a package with
/// none) is simply never mentioned, so no existence check is needed first.
/// `--since-as-filter` keeps the walk going past a commit older than [since]
/// instead of stopping there — plain `--since` prunes a branch the moment it
/// meets one such commit, which would hide a later, newer change on the far
/// side of an old, unrelated one.
List<String> _changedPathsSince(String directory, DateTime since) {
  final result = Process.runSync('git', [
    'log',
    '--since-as-filter=${since.toIso8601String()}',
    '--name-only',
    '--pretty=format:',
    '--',
    directory,
  ]);
  if (result.exitCode != 0) {
    // Not "nothing changed" — that reads a git failure as a clean bill of
    // health and would wave a genuinely stale package through. This is the
    // same "cannot answer" the header's exit code 2 is for everywhere else.
    stderr.writeln('git log failed for $directory: ${result.stderr}'.trim());
    exit(2);
  }
  final paths = (result.stdout as String)
      .split('\n')
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .where((line) => isArchiveRelevantPath(_relativeTo(line, directory)))
      .toSet()
      .toList();
  paths.sort();
  return paths;
}

/// [path] with its [directory] prefix stripped, so `isArchiveRelevantPath`
/// (which reads segments like `test` or `example`) never sees the workspace
/// path leading up to the package and mistakes it for one of the package's
/// own directories.
String _relativeTo(String path, String directory) {
  final prefix = '$directory/';
  return path.startsWith(prefix) ? path.substring(prefix.length) : path;
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
  @override
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
