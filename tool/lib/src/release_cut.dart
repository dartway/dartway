/// The mechanical half of cutting a release (#337): moving the family from a
/// between-releases prerelease (D-086) to the plain version pub.dev receives.
///
/// Between releases the family lives on `X.Y.Z-dev.N`. `release.dart`'s plan
/// used to read that as six unsatisfied carets — `PlainVersion.tryParse`
/// returns null for a prerelease by design (`plain_version.dart`), and the
/// plan reported that as "not satisfying the caret", which sends the reader
/// to look for a broken dependency that is not there. What follows lets the
/// plan say the true thing in one line instead, and lets `--cut` do the
/// mechanical rewrite by hand once meant: the family's own version, and every
/// caret on it, move together; a satellite whose own code moved since its own
/// publish is left for the ordinary stale check (`release_freshness.dart`) to
/// name, since which of patch/minor/major it needs is a judgement on its
/// `CHANGELOG.md`, not something a caret rewrite can decide.
library;

import 'pubspec_scan.dart';

/// The packages that move in lockstep — root `CLAUDE.md`'s monorepo map,
/// D-030/D-032. `dartway_generator` carries the same version and is
/// published in lockstep with the rest, even though it is not a pub
/// workspace member (it pins its own `analyzer`, D-009).
const Set<String> familyPackageNames = {
  'dartway_core_shared',
  'dartway_core_server',
  'dartway_core_flutter',
  'dartway_orm',
  'dartway_client',
  'dartway_generator',
};

/// Why [familyVersions] (name → version, meant to hold one entry per
/// [familyPackageNames]) cannot be read as a single family version, or null
/// when it can.
///
/// A version mismatch among the six is not this function's story to finish —
/// the ordinary caret-satisfaction check already reports whichever pairs
/// disagree, package by package, and duplicating that here in different
/// words would drift from it. This only refuses to guess when there is no
/// single answer to give.
String? familyLockstepProblem(Map<String, String> familyVersions) {
  final missing = familyPackageNames.difference(familyVersions.keys.toSet());
  if (missing.isNotEmpty) {
    final names = missing.toList()..sort();
    return 'the family is missing ${names.join(', ')} from this tree — is '
        'this the repository root?';
  }
  final versions = {
    for (final name in familyPackageNames) familyVersions[name],
  };
  if (versions.length > 1) {
    final detail = (familyPackageNames.toList()..sort())
        .map((name) => '$name ${familyVersions[name]}')
        .join(', ');
    return 'the family is not in lockstep: $detail.';
  }
  return null;
}

/// The one version every family package carries in [familyVersions].
///
/// Only meaningful once [familyLockstepProblem] has answered null for the
/// same map — this reads any one entry, since by then all six agree.
String familyVersion(Map<String, String> familyVersions) =>
    familyVersions[familyPackageNames.first]!;

/// The plain `X.Y.Z` a family prerelease `X.Y.Z-dev.N` cuts to, or null when
/// [version] is already plain.
///
/// A family version is either plain or carries a `-dev.N` prerelease
/// (D-086) — nothing here reads a `+build` metadata suffix specially, since
/// this repository does not put one on a family version; splitting on the
/// first `-` is enough for the one shape that exists.
String? plainOf(String version) {
  final dash = version.indexOf('-');
  return dash == -1 ? null : version.substring(0, dash);
}

/// The one-line message the plan prints in place of listing caret errors,
/// when the family carries a prerelease (#337).
String cutFirstMessage(String familyPrerelease) =>
    'cut the release first: family at $familyPrerelease';

/// [contents]' own top-level `version:` field moved from [from] to [to], or
/// null when it does not apply.
///
/// Restricted to [familyPackageNames] (D-103, review of PR #358): a
/// satellite's own version is never this function's to touch, even when its
/// text happens to carry the same prerelease as the family — [packageName]
/// is read off `contents` itself (its own `name:` field), not trusted from
/// the caller, so this cannot be pointed at the wrong file's identity.
///
/// Anchored at the start of a line: a pubspec has exactly one top-level
/// `version:`, and a same-named key nested under `dependencies:` or
/// `dependency_overrides:` is always indented, so it never matches `^`. Only
/// the version token itself is replaced — a trailing comment on the line, if
/// any, is left exactly as it was.
String? cutOwnVersion(
  String contents, {
  required String from,
  required String to,
}) {
  final name = _packageNameOf(contents);
  if (name == null || !familyPackageNames.contains(name)) return null;

  final pattern = RegExp(
    '^(version:\\s*)${RegExp.escape(from)}\\b',
    multiLine: true,
  );
  if (!pattern.hasMatch(contents)) return null;
  return contents.replaceFirstMapped(pattern, (match) => '${match[1]}$to');
}

/// The `name:` field of a pubspec's own [contents], or null when it cannot be
/// read at all — never thrown from here: a pubspec too broken to parse is a
/// bug `_rawPubspecs()` already reports elsewhere, not this function's to
/// raise a second time.
String? _packageNameOf(String contents) {
  try {
    return pubspecValue(parsePubspec(contents), 'name');
  } on FormatException {
    return null;
  }
}

/// [contents] with every bare-string caret dependency on a family package —
/// `  dartway_core_shared: ^0.21.0-dev.6` — cut from [from] to [to], or null
/// when it states none.
///
/// Only the flat `name: ^version` form: every family caret in this
/// repository is written that way today (`packages/`, `template/` and
/// `example/`, checked by hand) — a `hosted:`/`version:` map form would need
/// a pattern of its own, and this repository has none to prove it against.
/// `dependency_overrides:` entries are untouched by construction: they are
/// written as `path:`, never a caret, so the pattern below does not match
/// them.
String? cutDependencyCarets(
  String contents, {
  required String from,
  required String to,
}) {
  final names = familyPackageNames.map(RegExp.escape).join('|');
  final pattern = RegExp(
    '^(\\s*(?:$names):\\s*\\^)${RegExp.escape(from)}\\b',
    multiLine: true,
  );
  if (!pattern.hasMatch(contents)) return null;
  return contents.replaceAllMapped(pattern, (match) => '${match[1]}$to');
}

/// The rewrite `--cut` applies to one pubspec file's [contents]: its own
/// version, if [contents]' own `name:` is a family package's (`cutOwnVersion`
/// restricts itself to that), and every caret it states on a family package.
/// Null when neither applies — so a caller can tell which files were
/// actually touched from those that were merely read.
String? cutPubspecContents(
  String contents, {
  required String from,
  required String to,
}) {
  var result = contents;
  var changed = false;

  final withOwnVersion = cutOwnVersion(result, from: from, to: to);
  if (withOwnVersion != null) {
    result = withOwnVersion;
    changed = true;
  }

  final withCarets = cutDependencyCarets(result, from: from, to: to);
  if (withCarets != null) {
    result = withCarets;
    changed = true;
  }

  return changed ? result : null;
}
