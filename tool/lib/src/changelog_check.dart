/// Whether a package's own `CHANGELOG.md` documents the version it is about
/// to publish — the synchronisation law's own item 6 (root `CLAUDE.md`: "the
/// package's `CHANGELOG.md`"), which `dart pub publish --force` never checks
/// on this script's behalf (`--force` is exactly what silences pub's own
/// warning about a missing entry).
///
/// `--cut` deliberately never writes this heading itself (`release_cut.dart`):
/// the version note is human text — what changed, and why — and a maintainer
/// writes it, or copies it forward from the prerelease's own `dev.N` entries.
/// This check is what tells them to, instead of `dart pub publish --force`
/// shipping a package whose changelog still describes the previous version.
library;

/// The version named by the first `## ` heading in [changelog], or null when
/// it has none.
///
/// An optional `# Changelog` title line above it is not itself an entry —
/// only a level-two (`##`) heading is. Text after the version on that same
/// line (`## 2.0.0 - 2026-09-23`) is not read; only the version token itself
/// has to match, so a dated heading is exactly as valid as a bare one.
String? topChangelogVersion(String changelog) {
  final match = RegExp(r'^##\s+(\S+)', multiLine: true).firstMatch(changelog);
  return match?.group(1);
}

/// Why [changelog] does not document [version] as its top entry, or null
/// when it does.
String? changelogMismatch(String changelog, String version) {
  final top = topChangelogVersion(changelog);
  if (top == null) {
    return 'has no "## " entry at all';
  }
  if (top != version) {
    return 'top entry is "$top", not "$version"';
  }
  return null;
}
