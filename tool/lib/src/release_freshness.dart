/// A package `release.dart` found already published at the exact version this
/// tree states — so it left it out of the plan — whose shipped contents
/// (`isArchiveRelevantPath`, below) moved after that version's own publish.
/// The version claims nothing changed since release; something did.
///
/// This is exactly how `dartway_shared_preferences` (published `0.5.0`),
/// `dartway_telegram` (`0.2.0`) and `dartway_studio_bridge` (`0.9.0`) fell a
/// release behind their own code: each moved onto the rewrite without its
/// version following, and a plan that only asks pub.dev "is this version out
/// yet" reads that as nothing to do.
///
/// **Compared against the version's own publish timestamp, not against the
/// latest `stable-*` tag.** A release is two acts — publish, then move
/// `stable` (root `CLAUDE.md`, "A release is two acts") — so a package can be
/// sitting correctly published on pub.dev from a commit `stable` has not
/// reached yet; diffing since the tag would call that ordinary gap "changed
/// without a version move". The publish timestamp is the one instant that
/// always means "this version's code was declared final", whichever tag is or
/// is not there yet.
library;

/// Whether a change at [relativePath] (a package-relative path, as `git log
/// --name-only` prints it) is evidence that what a stranger's `dart pub
/// publish` archive carries actually moved.
///
/// An exclusion list, not an inclusion one: what ships is everything except a
/// named few, so the next platform folder a plugin adds (`android/`, `ios/`,
/// `web/`, `windows/`, ...) is covered without an edit here — an inclusion
/// list would have to be kept in step with pub's own archive rules, and
/// falling behind it is exactly the silent-drift failure mode this whole
/// check exists to close (`dartway_push_firebase`'s `web/` and
/// `dartway_push_rustore`'s `android/` would have gone unwatched under the
/// first version of this check, which only read `lib/`, `bin/` and
/// `pubspec.yaml`).
///
/// Excluded: `test/` and `example/` prove behaviour rather than being it. Pub
/// does archive both (verified by `dart pub publish --dry-run` — `example/`
/// is browsable on pub.dev the same way `README.md` is), but neither reaches
/// a project that depends on the package: nothing under either directory is
/// on the package's own `lib/<library>.dart` export surface, so a build that
/// resolves this package never touches them. A `CHANGELOG.md` or `README.md`
/// edit is excluded for a different reason — it does not change what ships,
/// only how it reads.
bool isArchiveRelevantPath(String relativePath) {
  final segments = relativePath.split(RegExp(r'[\\/]'));
  if (segments.contains('test') || segments.contains('example')) return false;
  final base = segments.isEmpty ? '' : segments.last;
  if (base == 'CHANGELOG.md' || base == 'README.md') return false;
  return true;
}

class StaleVersion {
  const StaleVersion(this.package, this.version, this.changedPaths);

  final String package;
  final String version;

  /// What changed, for the report — paths under the package's own directory.
  final List<String> changedPaths;

  @override
  String toString() =>
      '$package $version was published, but has changed since '
      '(${changedPaths.join(', ')}) without a version move.';
}

/// [unchangedPackages] is every package `release.dart` left out of its plan
/// because pub.dev already lists the version this tree states — the ones this
/// check exists for; a package in the plan is already being published and has
/// nothing to prove here.
///
/// [publishedAt] and [changedPathsSince] are injected so this reads as a pure
/// function under test: the real script asks pub.dev for the first and runs
/// `git log --since-as-filter=<publishedAt> --name-only -- <dir>`, filtered
/// through [isArchiveRelevantPath], for the second.
/// `--since-as-filter` matters as much as the path filter: without it `git
/// log --since` stops walking a branch the moment it meets one commit older
/// than the cutoff, so a change made and then reverted before an unrelated
/// older commit would hide everything committed after it from this walk.
List<StaleVersion> staleVersionsAmong(
  Iterable<({String name, String version, String directory})>
  unchangedPackages, {
  required DateTime? Function(String name, String version) publishedAt,
  required List<String> Function(String directory, DateTime since)
  changedPathsSince,
}) {
  final stale = <StaleVersion>[];
  for (final package in unchangedPackages) {
    // Never published at all is a different problem (`unresolvableDependenciesOf`
    // already reports it), not this check's to raise a second time.
    final at = publishedAt(package.name, package.version);
    if (at == null) continue;

    final changed = changedPathsSince(package.directory, at);
    if (changed.isNotEmpty) {
      stale.add(StaleVersion(package.name, package.version, changed));
    }
  }
  return stale;
}
