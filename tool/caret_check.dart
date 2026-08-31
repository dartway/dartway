// Do the carets the skeleton states resolve against what is actually published?
//
// `framework-finish` Step 4 and root `CLAUDE.md` item 6 compare the carets in
// `template/` and `example/` against the **local** `packages/*/pubspec.yaml`.
// Both sides move in the same pull request, so that check is green in exactly
// the situation that hurts: local version 0.12.0, caret ^0.12.0, pub.dev 0.11.0.
// Inside the monorepo `dependency_overrides` hide the constraint entirely — for
// an overridden package pub does not check it at all — and `dartway create`
// strips the block on the way out, so the caret is read for the first time in a
// stranger's tree. The only detector before this one was a person running
// `dartway create` from a fresh clone, at step 4 of the promotion ritual.
//
// Usage: dart run tool/caret_check.dart   (from the repository root)
//
// Exit codes are three, on purpose:
//   0  every caret is satisfied by what is published
//   1  at least one is not — findings are listed
//   2  pub.dev could not be asked at all
// The third is separate because this check, unlike `tool/lock_check.dart`,
// needs the network: a lost connection reported as a finding would read as
// "the release is broken" and be believed.

import 'dart:convert';
import 'dart:io';

import 'check_result.dart';

const _host = 'pub.dev';

void main() async {
  final report = await checkCarets();
  report.findings.forEach(stdout.writeln);
  final sink = report.outcome == CheckOutcome.unavailable ? stderr : stdout;
  sink.writeln(report.summary);
  if (report.exitCode != 0) exit(report.exitCode);
}

Future<CheckReport> checkCarets() async {
  const title = 'carets against $_host';
  final constraints = <_Constraint>[];
  for (final tree in ['template', 'example']) {
    final directory = Directory(tree);
    if (!directory.existsSync()) continue;
    for (final package in directory.listSync().whereType<Directory>()) {
      final pubspec = File('${package.path}/pubspec.yaml');
      if (pubspec.existsSync()) constraints.addAll(_carets(pubspec));
    }
  }

  if (constraints.isEmpty) {
    return const CheckReport.unavailable(
      title,
      'No dartway_* carets found under template/ or example/. '
      'Run this from the repository root.',
    );
  }

  final published = <String, _Published>{};
  for (final name in constraints.map((c) => c.package).toSet()) {
    try {
      published[name] = await _latestOf(name);
    } on _Unreachable catch (failure) {
      return CheckReport.unavailable(
        title,
        'Could not ask $_host about $name: ${failure.reason}',
      );
    }
  }

  final findings = <String>[];
  for (final constraint in constraints..sort(_Constraint.order)) {
    final latest = published[constraint.package]!;
    if (latest.missing) {
      findings.add(
        '${constraint.where}: ${constraint.package} '
        '^${constraint.min} — never published',
      );
      continue;
    }
    final version = _Version.tryParse(latest.version!);
    if (version == null) {
      findings.add(
        '${constraint.where}: ${constraint.package} '
        '^${constraint.min} — $_host says "${latest.version}", '
        'which this check does not compare (prerelease or build metadata)',
      );
      continue;
    }
    if (!constraint.min.allows(version)) {
      findings.add(
        '${constraint.where}: ${constraint.package} '
        '^${constraint.min} not satisfied — $_host has $version',
      );
    }
  }

  if (findings.isEmpty) {
    return CheckReport.ok(
      title,
      '✓ all ${constraints.length} dartway carets are satisfied by $_host',
    );
  }

  return CheckReport.findings(
    title,
    findings,
    '${findings.length} caret${findings.length == 1 ? '' : 's'} a stranger '
    'cannot resolve. Fix: publish the packages, or lower the carets to what is '
    'published. Inside the monorepo nothing will fail either way — '
    'dependency_overrides hide this until `dartway create`.',
  );
}

/// Every `dartway_*: ^X.Y.Z` a pubspec states as a real dependency.
///
/// `dependency_overrides` is skipped deliberately: it is the block that hides
/// the constraint, and it does not travel to anyone's project.
Iterable<_Constraint> _carets(File pubspec) sync* {
  var section = '';
  var line = 0;
  for (final text in pubspec.readAsLinesSync()) {
    line++;
    final top = RegExp(r'^([a-z_]+):').firstMatch(text);
    if (top != null) {
      section = top.group(1)!;
      continue;
    }
    if (section != 'dependencies' && section != 'dev_dependencies') continue;

    final entry = RegExp(
      r'^\s+(dartway_[a-z0-9_]+):\s*\^(\S+)\s*$',
    ).firstMatch(text);
    if (entry == null) continue;

    final min = _Version.tryParse(entry.group(2)!);
    if (min == null) continue;
    yield _Constraint(entry.group(1)!, min, pubspec.path, line);
  }
}

Future<_Published> _latestOf(String package) async {
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 10);
  try {
    final request = await client.getUrl(
      Uri.https(_host, '/api/packages/$package'),
    );
    final response = await request.close().timeout(const Duration(seconds: 20));
    if (response.statusCode == 404) {
      await response.drain<void>();
      return const _Published.missing();
    }
    if (response.statusCode != 200) {
      await response.drain<void>();
      throw _Unreachable('HTTP ${response.statusCode}');
    }
    final body = await response.transform(utf8.decoder).join();
    final latest = (jsonDecode(body) as Map)['latest'] as Map?;
    final version = latest?['version'] as String?;
    if (version == null) throw const _Unreachable('no latest.version in reply');
    return _Published(version);
  } on _Unreachable {
    rethrow;
  } catch (error) {
    throw _Unreachable('$error');
  } finally {
    client.close(force: true);
  }
}

class _Constraint {
  const _Constraint(this.package, this.min, this.file, this.line);
  final String package;
  final _Version min;
  final String file;
  final int line;

  String get where => '$file:$line';

  /// File first, then the line **as a number**: sorting the rendered
  /// `path:line` string puts line 10 above line 9, which reads as a bug in
  /// something else the first time you scan the output.
  static int order(_Constraint a, _Constraint b) {
    final byFile = a.file.compareTo(b.file);
    return byFile != 0 ? byFile : a.line.compareTo(b.line);
  }
}

class _Published {
  const _Published(this.version) : missing = false;
  const _Published.missing() : version = null, missing = true;
  final String? version;
  final bool missing;
}

class _Unreachable implements Exception {
  const _Unreachable(this.reason);
  final String reason;
}

/// A plain `X.Y.Z`, and the caret rule pub applies to it.
class _Version implements Comparable<_Version> {
  const _Version(this.major, this.minor, this.patch);

  /// Null for anything carrying a prerelease or build part: this check reports
  /// those rather than ordering them, because ordering them correctly is the
  /// whole of `pub_semver` and getting it subtly wrong here would be a green
  /// answer to a question nobody asked again.
  static _Version? tryParse(String text) {
    final match = RegExp(r'^(\d+)\.(\d+)\.(\d+)$').firstMatch(text.trim());
    if (match == null) return null;
    return _Version(
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
  bool allows(_Version other) =>
      other.compareTo(this) >= 0 && other.compareTo(_nextBreaking) < 0;

  _Version get _nextBreaking =>
      major == 0 ? _Version(0, minor + 1, 0) : _Version(major + 1, 0, 0);

  @override
  int compareTo(_Version other) {
    if (major != other.major) return major.compareTo(other.major);
    if (minor != other.minor) return minor.compareTo(other.minor);
    return patch.compareTo(other.patch);
  }

  @override
  String toString() => '$major.$minor.$patch';
}
