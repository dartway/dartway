import 'package:pub_semver/pub_semver.dart';

/// Compares dotted SDK versions numerically, ignoring any pre-release or
/// build suffix.
///
/// Its own file because the obvious implementation is wrong in a way that
/// survives casual testing: compared as text, `3.9.0` sorts above `3.11.0`, and
/// a doctor built on that would wave through an SDK two minor versions too old
/// and let the failure surface much later as something unrelated.
///
/// Pre-release and build suffixes are ignored — `3.12.0-beta.1` is treated as
/// `3.12.0`, which is the answer a prerequisite check wants: a beta of the
/// release you asked for still satisfies it. **This is the wrong comparison
/// for a `dartway_*` package's own version** — see [isPackageAtLeastVersion]
/// below, which a fix here used to stand in for and got backwards (#307,
/// review of #308): `0.20.0-dev.4`'s trailing `4` read as a fourth release
/// component, then cutting the whole suffix instead made every `-dev.N` of a
/// release equal to the release itself and to each other. Both are correct
/// for an SDK check and wrong for a package version, which is exactly why
/// this function and [isPackageAtLeastVersion] are not one function.
bool isAtLeastVersion(String version, String minimum) {
  final actual = _numericParts(version);
  final required = _numericParts(minimum);
  for (var index = 0; index < required.length; index++) {
    final actualPart = index < actual.length ? actual[index] : 0;
    if (actualPart != required[index]) {
      return actualPart > required[index];
    }
  }
  return true;
}

/// The dotted release numbers before any pre-release or build suffix.
List<int> _numericParts(String version) => version
    .split(RegExp(r'[-+]'))
    .first
    .split('.')
    .map(int.tryParse)
    .whereType<int>()
    .toList();

/// Whether a `dartway_*` package's own version is at least [minimum], by
/// proper semver ordering: a pre-release sorts below the release it precedes,
/// and its identifiers compare the way semver defines them — numeric
/// identifiers by numeric value, so `dev.9` sorts below `dev.10`, not as text.
///
/// This is what a migration note and a channel comparison need and
/// [isAtLeastVersion] cannot give them: a project on `0.20.0-dev.1` has to
/// read as behind the `0.20.0` that shipped after it, and a note keyed to
/// `0.20.0-dev.4` must not look satisfied by every other `-dev.N` of the same
/// release. `package:pub_semver` already implements this correctly; the
/// point of this wrapper is that nobody reaches for [isAtLeastVersion] here
/// by habit again.
///
/// A version either side cannot parse as semver answers `false` rather than
/// throwing: this reads a stranger's `pubspec.lock`, and a comparison it
/// cannot make is not grounds to crash `dartway update` — callers read
/// `false` as "not known to be at least", which is the conservative answer
/// (a gap reported that may not exist, never one hidden).
bool isPackageAtLeastVersion(String version, String minimum) {
  final actual = _tryParseSemver(version);
  final required = _tryParseSemver(minimum);
  if (actual == null || required == null) return false;
  return actual >= required;
}

Version? _tryParseSemver(String version) {
  try {
    return Version.parse(version.trim());
  } on FormatException {
    return null;
  }
}
