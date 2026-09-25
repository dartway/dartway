import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:pub_semver/pub_semver.dart';
import 'package:yaml/yaml.dart';

import 'version_check.dart';

/// Where the notes live inside the monorepo, as a relative path.
const migrationNotesDir = 'docs/migrations';

/// One instruction for projects on the framework: a change that a project has
/// to answer with an edit of its own.
///
/// **Keyed by package version, not by commit.** The obvious design — list what
/// changed between the commit a project last installed and the one it is moving
/// to — cannot be carried out where it is needed: the CLI reads the monorepo
/// from a shallow clone (`--depth 1`), which has no history to diff. Versions
/// need no history, they are written in the tree on both sides, and they are
/// what a project moves anyway.
class DwMigrationNote {
  DwMigrationNote({
    required this.path,
    required this.title,
    required this.affects,
    required this.body,
  });

  /// Path relative to the monorepo root, so a report can point at the file to
  /// read rather than reprint it.
  final String path;

  final String title;

  /// The packages this note is about, each with the version the change lands
  /// in. A project below that version on any of them has the work ahead of it.
  final Map<String, String> affects;

  final String body;

  /// Whether a project standing at [projectVersions] still has this note to
  /// apply.
  ///
  /// A package the project does not depend on cannot make a note apply: that is
  /// the "who is affected" filter, and it is mechanical rather than a sentence
  /// somebody has to read.
  bool appliesTo(Map<String, String> projectVersions) {
    for (final entry in affects.entries) {
      final current = projectVersions[entry.key];
      if (current == null) continue;
      if (!isPackageAtLeastVersion(current, entry.value)) return true;
    }
    return false;
  }

  /// [affects], parsed as semver where it parses at all — a problem the
  /// frontmatter check above already reports on a version that does not.
  ///
  /// Used to rank two notes of the same day by the family version they land
  /// at — see [compareMigrationNotes].
  Map<String, Version> get parsedAffects => {
    for (final entry in affects.entries)
      if (_tryParseVersion(entry.value) case final version?) entry.key: version,
  };
}

Version? _tryParseVersion(String value) {
  try {
    return Version.parse(value);
  } on FormatException {
    return null;
  }
}

/// A note that could not be read, and why.
///
/// Reported rather than skipped, and this is the whole reason the type exists:
/// a note dropped for a typo in its frontmatter is a migration nobody is told
/// about, which is exactly the failure the notes are there to prevent. A loud
/// broken note is recoverable; a silent one is not.
class DwMigrationNoteProblem {
  DwMigrationNoteProblem({required this.path, required this.problem});

  final String path;
  final String problem;

  @override
  String toString() => '$path — $problem';
}

class DwMigrationNotes {
  DwMigrationNotes({required this.notes, required this.problems});

  final List<DwMigrationNote> notes;
  final List<DwMigrationNoteProblem> problems;
}

/// Reads `docs/migrations/` out of a monorepo checkout.
///
/// Notes come back ordered by [compareMigrationNotes] — chronological, which
/// is the order they are applied in when a project has fallen several
/// releases behind.
DwMigrationNotes readMigrationNotes(Directory monorepoDir) {
  final dir = Directory(p.join(monorepoDir.path, migrationNotesDir));
  if (!dir.existsSync()) {
    return DwMigrationNotes(notes: const [], problems: const []);
  }

  final notes = <DwMigrationNote>[];
  final problems = <DwMigrationNoteProblem>[];

  final files =
      dir
          .listSync()
          .whereType<File>()
          .where((file) => p.extension(file.path) == '.md')
          .where((file) => p.basename(file.path) != 'README.md')
          .toList()
        ..sort((a, b) => p.basename(a.path).compareTo(p.basename(b.path)));

  for (final file in files) {
    final relative = p.join(migrationNotesDir, p.basename(file.path));
    if (!_datedName.hasMatch(p.basename(file.path))) {
      problems.add(
        DwMigrationNoteProblem(
          path: relative,
          problem:
              'the file name must start with the date the note opened, '
              'YYYY-MM-DD-: notes are applied in that order',
        ),
      );
      continue;
    }
    final parsed = parseMigrationNote(
      contents: file.readAsStringSync(),
      path: relative,
    );
    if (parsed is DwMigrationNote) {
      notes.add(parsed);
    } else if (parsed is DwMigrationNoteProblem) {
      problems.add(parsed);
    }
  }

  notes.sort(compareMigrationNotes);

  return DwMigrationNotes(notes: notes, problems: problems);
}

/// Orders two notes the way they are applied: by the date their file name
/// starts with; within one day, notes naming the family come first, in the
/// order of the family version they land at; then by file name.
///
/// **The date decides first, on purpose.** A note's `affects` can name a
/// satellite alone (`dartway_lints: "0.4.0"`) beside a note naming only the
/// family (`dartway_core_server: "0.20.0-dev.2"`) — the two numbers are not on
/// the same line, and comparing them as semver put the `0.4.0` note ahead of
/// every family note dated before it.
///
/// **Within a day only the family's version is compared.** The six family
/// packages move in lockstep, so any of them names the same line; a
/// satellite's version is on a line of its own and never ranks against
/// another note. Reducing each note to one sort key keeps the order total —
/// comparing "a package both notes name" pair by pair does not: A < B and
/// B < C by name while C < A by version.
int compareMigrationNotes(DwMigrationNote a, DwMigrationNote b) {
  final byDate = _datePrefix(a.path).compareTo(_datePrefix(b.path));
  if (byDate != 0) return byDate;

  final familyA = _familyVersion(a);
  final familyB = _familyVersion(b);
  if (familyA != null && familyB == null) return -1;
  if (familyA == null && familyB != null) return 1;
  if (familyA != null && familyB != null) {
    final byVersion = familyA.compareTo(familyB);
    if (byVersion != 0) return byVersion;
  }

  return p.basename(a.path).compareTo(p.basename(b.path));
}

/// The packages that carry one version between them.
const _family = {
  'dartway_core_shared',
  'dartway_core_server',
  'dartway_core_flutter',
  'dartway_orm',
  'dartway_client',
  'dartway_generator',
};

/// The highest family version a note names, or null when it names none.
Version? _familyVersion(DwMigrationNote note) {
  Version? highest;
  for (final MapEntry(key: package, value: version)
      in note.parsedAffects.entries) {
    if (!_family.contains(package)) continue;
    if (highest == null || version > highest) highest = version;
  }
  return highest;
}

final _datedName = RegExp(r'^\d{4}-\d{2}-\d{2}-');

/// The `YYYY-MM-DD` a migration note's file name starts with — guaranteed by
/// [readMigrationNotes], which reports any other name as a problem.
String _datePrefix(String path) {
  final name = p.basename(path);
  return _datedName.hasMatch(name) ? name.substring(0, 10) : name;
}

/// Parses one note. Returns a [DwMigrationNote] or a [DwMigrationNoteProblem]
/// saying what is wrong with it — never null, because there is no third answer
/// worth acting on.
Object parseMigrationNote({required String contents, required String path}) {
  const marker = '---';
  final lines = contents.split('\n');
  if (lines.isEmpty || lines.first.trim() != marker) {
    return DwMigrationNoteProblem(
      path: path,
      problem:
          'no frontmatter: the file must start with a --- block '
          'stating title: and affects:',
    );
  }

  final end = lines.indexOf(marker, 1);
  if (end == -1) {
    return DwMigrationNoteProblem(
      path: path,
      problem: 'the frontmatter block is never closed with ---',
    );
  }

  final Object? frontmatter;
  try {
    frontmatter = loadYaml(lines.sublist(1, end).join('\n'));
  } on YamlException catch (error) {
    return DwMigrationNoteProblem(
      path: path,
      problem: 'the frontmatter is not valid YAML: ${error.message}',
    );
  }
  if (frontmatter is! YamlMap) {
    return DwMigrationNoteProblem(
      path: path,
      problem: 'the frontmatter is not a mapping',
    );
  }

  final title = frontmatter['title'];
  if (title is! String || title.trim().isEmpty) {
    return DwMigrationNoteProblem(path: path, problem: 'no title:');
  }

  final affects = frontmatter['affects'];
  if (affects is! YamlMap || affects.isEmpty) {
    return DwMigrationNoteProblem(
      path: path,
      problem:
          'affects: must name at least one package and the version the '
          'change lands in',
    );
  }

  final parsedAffects = <String, String>{};
  for (final entry in affects.entries) {
    final name = entry.key;
    final version = entry.value;
    if (name is! String || !name.startsWith('dartway_')) {
      return DwMigrationNoteProblem(
        path: path,
        problem: 'affects: names "$name", which is not a framework package',
      );
    }
    // A YAML scalar like 0.8 parses as a number, and "0.8" is not a version.
    // Quoting it is the fix, and saying so is cheaper than a wrong comparison.
    if (version is! String || !RegExp(r'^\d+\.\d+\.\d+').hasMatch(version)) {
      return DwMigrationNoteProblem(
        path: path,
        problem:
            'affects: $name must state a full version in quotes '
            '(got "$version")',
      );
    }
    parsedAffects[name] = version;
  }

  return DwMigrationNote(
    path: path,
    title: title.trim(),
    affects: parsedAffects,
    body: lines.sublist(end + 1).join('\n').trim(),
  );
}

/// The notes a project standing at [projectVersions] still has to apply, in the
/// order to apply them.
List<DwMigrationNote> migrationNotesToApply({
  required List<DwMigrationNote> notes,
  required Map<String, String> projectVersions,
}) => notes.where((note) => note.appliesTo(projectVersions)).toList();
