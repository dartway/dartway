/// A plain `X.Y.Z`, and the caret rule pub applies to it.
class PlainVersion implements Comparable<PlainVersion> {
  const PlainVersion(this.major, this.minor, this.patch);

  /// Null for anything carrying a prerelease or build part: this check reports
  /// those rather than ordering them, because ordering them correctly is the
  /// whole of `pub_semver` and getting it subtly wrong here would be a green
  /// answer to a question nobody asked again.
  static PlainVersion? tryParse(String text) {
    final match = RegExp(r'^(\d+)\.(\d+)\.(\d+)$').firstMatch(text.trim());
    if (match == null) return null;
    return PlainVersion(
      int.parse(match.group(1)!),
      int.parse(match.group(2)!),
      int.parse(match.group(3)!),
    );
  }

  final int major;
  final int minor;
  final int patch;

  /// `^X.Y.Z` is `>=X.Y.Z` and below the next breaking version — which under a
  /// zero major is the next **minor**, not the next major.
  ///
  /// **This is not npm's rule, and it reads as if it were.** Under npm, `^0.0.3`
  /// means `>=0.0.3 <0.0.4`; under pub it does not, and an automated review has
  /// now twice asked for the npm form here. The authority is
  /// `pub_semver`'s `Version.nextBreaking`, which increments the minor whenever
  /// the major is zero, with no separate case for a zero minor. Run rather than
  /// recalled, both when this was written and again when it was questioned:
  ///
  /// ```
  /// Version.parse('0.0.3').nextBreaking            -> 0.1.0
  /// VersionConstraint.parse('^0.0.3').allows(0.0.4) -> true
  /// VersionConstraint.parse('^0.0.3').allows(0.1.0) -> false
  /// VersionConstraint.parse('^0.12.0').allows(0.13.0) -> false
  /// ```
  ///
  /// Taking the npm rule here would make this report a caret as unsatisfiable
  /// while `dart pub get` resolves it happily — a confident red sending someone
  /// to publish a version they do not need.
  bool allows(PlainVersion other) =>
      other.compareTo(this) >= 0 && other.compareTo(_nextBreaking) < 0;

  PlainVersion get _nextBreaking => major == 0
      ? PlainVersion(0, minor + 1, 0)
      : PlainVersion(major + 1, 0, 0);

  @override
  int compareTo(PlainVersion other) {
    if (major != other.major) return major.compareTo(other.major);
    if (minor != other.minor) return minor.compareTo(other.minor);
    return patch.compareTo(other.patch);
  }

  @override
  String toString() => '$major.$minor.$patch';
}
