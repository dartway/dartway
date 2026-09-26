/// pub.dev's `package-created` rate limit, recognised from what
/// `dart pub publish` prints, rather than treated as an ordinary failure
/// (#313).
///
/// pub.dev allows 4 first publications in a few minutes and 12 in a day. The
/// first publication of the rewrite hit both: `release.dart --publish` read
/// the answer as "this package is broken" and stopped, leaving everything
/// after it in the order unpublished even when nothing about it depended on
/// the package pub.dev actually refused.
library;

/// One `dart pub publish` refusal caused by pub.dev's `package-created` rate
/// limit, parsed from the process's own combined stdout and stderr — never
/// guessed at from the exit code alone, so a wording change on pub.dev's side
/// shows up as "not recognised" (an ordinary failure) rather than silently
/// being read as something it is not.
class PackageCreatedRateLimit {
  const PackageCreatedRateLimit({required this.count, required this.window});

  /// How many `package-created` operations pub.dev counted against the limit
  /// it just refused. Reported for the log; what happens next is decided by
  /// [window], not by this number.
  final int count;

  /// The window text pub.dev named, verbatim — e.g. `a few minutes`, `1 day`.
  final String window;

  /// The short window clears by waiting a few minutes. The long one does
  /// not reset until pub.dev's day rolls over, which this process has no
  /// business waiting out.
  bool get isShortWindow => window.contains('minute');

  static final _pattern = RegExp(
    r'"package-created" operation is blocked, as its rate limit has been '
    r'reached \((\d+) in the last ([^)]+)\)',
  );

  /// Reads [output] (a failed publish's combined stdout and stderr) for the
  /// rate-limit answer, or null when this failure is something else.
  static PackageCreatedRateLimit? parse(String output) {
    final match = _pattern.firstMatch(output);
    if (match == null) return null;
    return PackageCreatedRateLimit(
      count: int.parse(match.group(1)!),
      window: match.group(2)!,
    );
  }

  @override
  String toString() => '$count in the last $window';
}
