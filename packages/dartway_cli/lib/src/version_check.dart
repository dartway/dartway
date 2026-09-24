/// Compares dotted versions numerically.
///
/// Its own file because the obvious implementation is wrong in a way that
/// survives casual testing: compared as text, `3.9.0` sorts above `3.11.0`, and
/// a doctor built on that would wave through an SDK two minor versions too old
/// and let the failure surface much later as something unrelated.
///
/// Pre-release and build suffixes are ignored — `3.12.0-beta.1` is treated as
/// `3.12.0`, which is the answer a prerequisite check wants.
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
///
/// Splitting the whole string on `[.\-+]` (the previous shape of this
/// function) reads a suffix's own digits as extra release components:
/// `0.20.0-dev.4` became `[0, 20, 0, 4]`, a version `isAtLeastVersion` then
/// judged *greater* than the plain `0.20.0` it was a prerelease of — exactly
/// backwards, and invisible until a package left `-dev.N` behind, which none
/// of the versions this was tested against ever did (#307). The suffix is cut
/// off first, whole, so nothing inside it is ever mistaken for a release
/// component.
List<int> _numericParts(String version) => version
    .split(RegExp(r'[-+]'))
    .first
    .split('.')
    .map(int.tryParse)
    .whereType<int>()
    .toList();
