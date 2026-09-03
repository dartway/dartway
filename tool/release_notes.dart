// What went out in this release, and over what stretch of time.
//
// A release here leaves three traces and, until now, wrote none of them down:
// the packages that went to pub.dev, the commit `stable` was moved to, and the
// window since the last time that happened. `tool/release.dart` covers the
// first. This covers the other two — and the question a person actually asks,
// which is not "what is the diff" but **"what changed, and since when"**.
//
// **The starting point is the part that is easy to get wrong.** Releases are
// tagged `stable-YYYY-MM-DD[.N]`, and the newest such tag is not necessarily
// the last release: five of them (`stable-2026-09-02` through `.4`) point at
// commits that are not in `master` at all — branch commits that a squash merge
// replaced, tagged before the merge rather than after it. Taking the newest tag
// by name gives a starting point nobody can reach from `master`, and a range
// that means nothing.
//
// So the previous release is the newest `stable-*` tag that is **an ancestor of
// what is being released**. Unreachable tags fall out by construction rather
// than by being listed here, which is what keeps this correct when somebody
// tags a branch again.
//
// Usage:
//   dart run tool/release_notes.dart              since the last release, to HEAD
//   dart run tool/release_notes.dart <from> <to>  an explicit range
//
// Exit codes:
//   0  notes written to stdout
//   1  something is wrong
//   2  the question could not be put — no previous release to measure from

import 'dart:convert';
import 'dart:io';

const _tagPrefix = 'stable-';

Future<void> main(List<String> args) async {
  if (args.length != 0 && args.length != 2) {
    stderr.writeln('usage: dart run tool/release_notes.dart [<from> <to>]');
    exit(64);
  }

  final to = args.isEmpty ? 'HEAD' : args[1];
  final toSha = _git(['rev-parse', to]);
  if (toSha.isEmpty) {
    stderr.writeln('Cannot resolve "$to".');
    exit(1);
  }

  final String from;
  if (args.isNotEmpty) {
    from = args[0];
  } else {
    final previous = _previousRelease(toSha);
    if (previous == null) {
      stderr.writeln(
        'No ${_tagPrefix}* tag is an ancestor of $to, so there is no previous '
        'release to measure from. Pass an explicit range.',
      );
      exit(2);
    }
    from = previous;
  }

  final commits = _git([
    'log',
    '--format=%s',
    '$from..$toSha',
  ]).split('\n').where((line) => line.trim().isNotEmpty).toList();

  if (commits.isEmpty) {
    stderr.writeln('Nothing between $from and $to.');
    exit(1);
  }

  final buffer = StringBuffer();
  _writePeriod(buffer, from: from, to: toSha, commits: commits.length);
  await _writePackages(buffer, from: from, to: toSha);
  _writeChanges(buffer, commits);
  stdout.write(buffer);
}

/// The newest `stable-*` tag that [target] descends from.
///
/// Ancestry rather than name order: a tag placed on a branch commit before its
/// squash merge names a commit that never reached `master`, and sorting tag
/// names would pick exactly that one, since it is the most recent by date.
String? _previousRelease(String target) {
  final tags = _git([
    'tag',
    '--list',
    '$_tagPrefix*',
    '--sort=-creatordate',
  ]).split('\n').where((t) => t.trim().isNotEmpty);

  for (final tag in tags) {
    final sha = _git(['rev-list', '-n1', tag]);
    if (sha.isEmpty || sha == target) continue;
    final ancestry = Process.runSync('git', [
      'merge-base',
      '--is-ancestor',
      sha,
      target,
    ]);
    if (ancestry.exitCode == 0) return tag;
  }
  return null;
}

void _writePeriod(
  StringBuffer out, {
  required String from,
  required String to,
  required int commits,
}) {
  final since = _dateOf(from);
  final until = _dateOf(to);
  final days = DateTime.parse(until).difference(DateTime.parse(since)).inDays;

  out.writeln('## The window');
  out.writeln();
  out.writeln(
    'From **$since** to **$until** — $days day${days == 1 ? '' : 's'}, '
    '$commits pull request${commits == 1 ? '' : 's'}.',
  );
  out.writeln();
  out.writeln(
    'Measured from `$from`, the last release this one descends from. '
    'One pull request is one commit here: `master` takes squash merges only.',
  );
  out.writeln();
}

/// What this release made available, asked of pub.dev rather than of the trees.
///
/// The obvious source is the version fields in the two trees, and it is wrong
/// twice over. **A first publication is invisible in git:** `dartway_offline_*`
/// and three `dartway_push_*` packages sat here at 0.1.0 for weeks without ever
/// reaching pub.dev, so by the trees they "did not change" in the release that
/// finally published them. **And a backlog is invisible too:** `dartway_push_client`
/// reached 0.2.0 in this repository before the window opened and went out
/// inside it, so its version moved in the wrong release to be noticed.
///
/// The question a reader has is neither of those. It is *what can I now depend
/// on that I could not before*, and only pub.dev answers it — a version whose
/// publication date falls after the previous release belongs to this one.
///
/// **Which is why the tag goes on after publishing, not before.** The boundary
/// is the previous tag's own timestamp, so a release tagged before it published
/// pushes its packages into the next release's window: `stable-2026-08-24` was
/// created at 09:58Z and that release's packages went out at 11:45Z, so
/// `dartway_lints` and `dartway_router` read as belonging to the release after
/// it. Tagging last costs nothing and makes the boundary exact.
Future<void> _writePackages(
  StringBuffer out, {
  required String from,
  required String to,
}) async {
  // The tag's own moment, not midnight of its day: a day-wide boundary sweeps
  // in whatever the previous release published later that same day.
  final boundary = _timestampOf(from);
  final since = DateTime.parse(boundary.at).toUtc();
  final released = <String>[];
  var pubDevAnswered = true;

  for (final pubspec in _pubspecs(to)) {
    final version = _versionIn(to, pubspec);
    final name = _nameIn(to, pubspec);
    if (version == null || name == null) continue;

    final history = await _publishedVersions(name);
    if (history == null) {
      pubDevAnswered = false;
      continue;
    }

    final publishedAt = history[version];
    if (publishedAt == null || !publishedAt.isAfter(since)) continue;

    // Whether this is the package's debut decides how it reads: a bump asks
    // an existing user to upgrade, a debut tells everyone else it exists.
    final earlier = history.length - 1;
    released.add(
      earlier == 0
          ? '- **$name** $version — first published'
          : '- **$name** $version',
    );
  }

  if (released.isEmpty && pubDevAnswered) return;

  out.writeln('## Packages');
  out.writeln();
  if (released.isEmpty) {
    out.writeln('_No package publications could be confirmed._');
  }
  for (final line in released..sort()) {
    out.writeln(line);
  }
  if (boundary.kind == _Boundary.lightweightTag) {
    out.writeln();
    out.writeln(
      '_`$from` is a lightweight tag, so it records no moment of its own and '
      'this window opens at the commit it names instead. Anything the previous '
      'release published after that commit is listed above as belonging to this '
      'one. Annotated tags (`git tag -a`) make the boundary exact._',
    );
  } else if (boundary.kind == _Boundary.notATag) {
    out.writeln();
    out.writeln(
      '_`$from` is not a tag, so this window opens at the moment that commit '
      'landed rather than at a release._',
    );
  }
  if (!pubDevAnswered) {
    out.writeln();
    out.writeln(
      '_pub.dev could not be asked about every package, so this list may be '
      'incomplete. Nothing else in these notes depends on it._',
    );
  }
  out.writeln();
}

/// Every published version of [package] and when it went out, or null when
/// pub.dev could not be asked. Empty for a package never published.
Future<Map<String, DateTime>?> _publishedVersions(String package) async {
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 10);
  try {
    final request = await client.getUrl(
      Uri.https('pub.dev', '/api/packages/$package'),
    );
    final response = await request.close().timeout(const Duration(seconds: 20));
    if (response.statusCode == 404) {
      await response.drain<void>();
      return const {};
    }
    if (response.statusCode != 200) {
      await response.drain<void>();
      return null;
    }
    final body = await response.transform(utf8.decoder).join();
    final versions = (jsonDecode(body) as Map)['versions'] as List?;
    if (versions == null) return null;
    return {
      for (final entry in versions.cast<Map>())
        entry['version'] as String:
            DateTime.parse(entry['published'] as String).toUtc(),
    };
  } catch (_) {
    return null;
  } finally {
    client.close(force: true);
  }
}

/// The changes, breaking ones first.
///
/// Conventional commits make this readable without a curated list: the type is
/// the grouping and `!` is the flag that decides what a reader has to act on.
/// **A breaking change that forgets its `!` is invisible here** — the notes can
/// only surface what the commit subject claims, which is why the marker is a
/// rule rather than a habit.
void _writeChanges(StringBuffer out, List<String> commits) {
  const headings = {
    'feat': 'Added',
    'fix': 'Fixed',
    'docs': 'Documentation',
    'chore': 'Housekeeping',
    'ci': 'CI',
    'refactor': 'Refactoring',
    'test': 'Tests',
  };

  final breaking = <String>[];
  final grouped = <String, List<String>>{};
  final ungrouped = <String>[];

  for (final subject in commits) {
    final match = RegExp(
      r'^([a-z]+)(?:\(([^)]*)\))?(!)?:\s*(.+)$',
    ).firstMatch(subject);
    if (match == null) {
      ungrouped.add(subject);
      continue;
    }
    final type = match.group(1)!;
    final scope = match.group(2);
    final line = '- ${scope == null ? '' : '**$scope** — '}${match.group(4)}';

    if (match.group(3) == '!') {
      breaking.add(line);
      continue;
    }
    grouped.putIfAbsent(type, () => []).add(line);
  }

  if (breaking.isNotEmpty) {
    out.writeln('## Breaking');
    out.writeln();
    out.writeln('Read these before upgrading — each one changes something an '
        'application already depends on.');
    out.writeln();
    for (final line in breaking) {
      out.writeln(line);
    }
    out.writeln();
  }

  for (final entry in headings.entries) {
    final lines = grouped.remove(entry.key);
    if (lines == null || lines.isEmpty) continue;
    out.writeln('## ${entry.value}');
    out.writeln();
    for (final line in lines) {
      out.writeln(line);
    }
    out.writeln();
  }

  // Anything with a type this file does not know a heading for still has to
  // appear: a release note that silently drops a change is worse than an
  // untidy one.
  for (final entry in grouped.entries) {
    out.writeln('## ${entry.key}');
    out.writeln();
    for (final line in entry.value) {
      out.writeln(line);
    }
    out.writeln();
  }

  if (ungrouped.isNotEmpty) {
    out.writeln('## Other');
    out.writeln();
    for (final line in ungrouped) {
      out.writeln('- $line');
    }
    out.writeln();
  }
}

Iterable<String> _pubspecs(String revision) => _git([
  'ls-tree',
  '-r',
  '--name-only',
  revision,
  'packages/',
]).split('\n').where((path) => path.endsWith('/pubspec.yaml'));

String? _versionIn(String revision, String path) =>
    _fieldIn(revision, path, 'version');

String? _nameIn(String revision, String path) =>
    _fieldIn(revision, path, 'name');

String? _fieldIn(String revision, String path, String field) {
  final result = Process.runSync('git', ['show', '$revision:$path']);
  if (result.exitCode != 0) return null;
  final text = result.stdout as String;
  if (RegExp(r'^publish_to:', multiLine: true).hasMatch(text)) return null;
  final match = RegExp('^$field:\\s*(\\S+)\\s*\$', multiLine: true)
      .firstMatch(text);
  return match?.group(1);
}

String _dateOf(String revision) =>
    _git(['log', '--format=%cs', '-n1', revision]);

/// When [revision] was tagged, and whether that moment is real.
///
/// **Only an annotated tag records when it was applied.** A lightweight tag is
/// just a ref pointing at a commit: it stores no date of its own, and
/// `%(creatordate)` silently answers with the commit's committer date instead.
/// So reading `creatordate` and calling it "when we tagged" is a mechanism that
/// looks like it works and does nothing — the boundary stays the merge time,
/// which is before the release published, which is the misattribution this file
/// exists to avoid.
///
/// Every existing `stable-*` tag here is lightweight, so the fallback is the
/// present rather than the exception, and the caller says so in the notes
/// instead of quietly being wrong.
({String at, _Boundary kind}) _timestampOf(String revision) {
  final objectType = _git([
    'for-each-ref',
    '--format=%(objecttype)',
    'refs/tags/$revision',
  ]);

  if (objectType == 'tag') {
    final tagged = _git([
      'for-each-ref',
      '--format=%(taggerdate:iso-strict)',
      'refs/tags/$revision',
    ]);
    if (tagged.isNotEmpty) return (at: tagged, kind: _Boundary.annotatedTag);
  }

  return (
    at: _git(['log', '--format=%cI', '-n1', revision]),
    // An explicit range may start anywhere — a branch, a bare sha — and calling
    // that "a lightweight tag" in the notes would be its own small lie.
    kind: objectType.isEmpty ? _Boundary.notATag : _Boundary.lightweightTag,
  );
}

/// What the window's opening moment actually came from.
enum _Boundary { annotatedTag, lightweightTag, notATag }

String _git(List<String> args) {
  final result = Process.runSync('git', args);
  if (result.exitCode != 0) return '';
  return (result.stdout as String).trim();
}
