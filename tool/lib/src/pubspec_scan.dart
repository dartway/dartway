/// Reading just enough of a `pubspec.yaml` for the release scripts — without a
/// YAML parser, because every value read here is a single scalar on its own
/// line, and the packages in this repository are formatted uniformly by
/// `dart format`.
library;

/// The value of a top-level scalar key (`name:`, `version:`, `publish_to:`),
/// or null when [lines] has none.
String? pubspecValue(List<String> lines, String key) {
  for (final line in lines) {
    final match = RegExp('^$key:\\s*(\\S+)\\s*\$').firstMatch(line);
    if (match != null) return match.group(1);
  }
  return null;
}

/// The `dartway_*` packages named under `dependencies:`, and the caret text
/// stated for each — never `dependency_overrides`, which resolves only
/// inside this workspace and never travels to pub.dev.
///
/// A previous version of this pattern ended in `\$` inside a raw string —
/// two literal characters, an escaped dollar sign matched against the input —
/// rather than the end-of-line anchor a non-raw string gets from the same two
/// characters. Every dependency constraint came back empty, silently: the
/// ordering check had nothing to order, and the resolvability check had
/// nothing to refuse. `pubspec_scan_test.dart` pins the correct behaviour
/// with a fixture the wrong pattern is verified to fail against.
Map<String, String> dartwayDependencyConstraints(List<String> lines) {
  final deps = <String, String>{};
  var section = '';
  for (final line in lines) {
    final top = RegExp(r'^([a-z_]+):').firstMatch(line);
    if (top != null) {
      section = top.group(1)!;
      continue;
    }
    if (section != 'dependencies') continue;
    final entry = RegExp(
      r'^\s+(dartway_[a-z0-9_]+):\s*(\S+)\s*$',
    ).firstMatch(line);
    if (entry != null) deps[entry.group(1)!] = entry.group(2)!;
  }
  return deps;
}
