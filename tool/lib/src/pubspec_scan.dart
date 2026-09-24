/// Reading a `pubspec.yaml` for the release scripts, through real YAML
/// rather than a line-based regex.
///
/// A regex read one line at a time, and every one of its patterns anchored
/// the whole line: `dartway_client: ^0.20.0  # local dev only` matched
/// nothing (the comment made the line not end where the pattern expected),
/// a dependency pinned as a map (`hosted:`/`version:` on their own lines)
/// matched nothing (the pattern wanted the version on the same line as the
/// name), and `publish_to: none  # see #142` matched nothing either. Every
/// one of those came back as "this package has no such thing" — the same
/// answer as a package that genuinely has none — which is exactly how a
/// dependency this script never priced into `unresolvableDependenciesOf`, or
/// a package this script never excluded from the release plan, would have
/// gone unnoticed (review of #308). Real YAML reads every one of these forms
/// correctly, and what it still cannot make sense of is a loud
/// [FormatException] instead of a silent null.
library;

import 'package:yaml/yaml.dart';

/// Parses [contents] as a pubspec. Throws [FormatException] when the
/// document is not a YAML mapping — a corrupt `pubspec.yaml` under
/// `packages/` is a bug in this monorepo, not a stranger's file this script
/// owes any leniency to.
YamlMap parsePubspec(String contents) {
  final Object? document;
  try {
    document = loadYaml(contents);
  } on YamlException catch (error) {
    throw FormatException('not valid YAML: ${error.message}');
  }
  if (document is! YamlMap) {
    throw const FormatException('not a YAML mapping');
  }
  return document;
}

/// The value of a top-level scalar key (`name:`, `version:`, `publish_to:`),
/// or null when [document] has none or it is not a plain scalar.
///
/// A mapping or a list under this key answers null the same as absent,
/// rather than being strung together into something scalar-shaped: a caller
/// asking for `name:` or `version:` wants exactly the string a person reads
/// in the file, or nothing.
String? pubspecValue(YamlMap document, String key) {
  final value = document[key];
  return value is String ? value : null;
}

/// The `dartway_*` packages named under `dependencies:`, and the caret text
/// stated for each.
///
/// `dependency_overrides` is skipped on purpose: it is the block that makes
/// the workspace resolve locally, it never travels to anyone's project, and
/// reading it here would invent an ordering constraint that does not exist
/// on pub.dev.
///
/// A dependency this cannot read as a version constraint — a `git:` or
/// `path:` source under `dependencies:` (as opposed to `dependency_overrides:`,
/// which is skipped rather than read) — throws rather than being treated as
/// "no constraint": `dart pub publish` itself refuses a package with a git or
/// path dependency, so a `dartway_*` entry shaped like one under
/// `dependencies:` is not a form this monorepo's own packages should ever
/// have, and silently reading it as "depends on nothing" would hide exactly
/// the kind of mistake this whole script exists to catch before publishing.
Map<String, String> dartwayDependencyConstraints(YamlMap document) {
  final dependencies = document['dependencies'];
  if (dependencies == null) return const {};
  if (dependencies is! YamlMap) {
    throw const FormatException('dependencies: is not a mapping');
  }

  final constraints = <String, String>{};
  for (final MapEntry(key: name, value: spec) in dependencies.entries) {
    if (name is! String || !name.startsWith('dartway_')) continue;
    constraints[name] = _constraintTextOf(name, spec);
  }
  return constraints;
}

/// The version constraint text of one dependency [spec] — a bare string
/// (`^0.20.0`), or the `version:` of a map form (`hosted:`/`version:`).
String _constraintTextOf(String name, Object? spec) {
  if (spec is String) return spec;
  if (spec is YamlMap) {
    final version = spec['version'];
    if (version is String) return version;
  }
  throw FormatException(
    'dartway_* dependency "$name" is not a version this script can read: '
    '$spec',
  );
}
