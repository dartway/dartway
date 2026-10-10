import 'dart:io';

import 'package:dartway_cli/src/framework_versions.dart';
import 'package:dartway_cli/src/migration_notes.dart';
import 'package:dartway_cli/src/version_check.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// The migration notes are the framework's only channel to a project that is
/// behind, and they are read by a machine before they are read by a person.
/// Two things therefore have to hold: the parser must refuse a malformed note
/// out loud rather than skip it, and the notes this repository actually ships
/// must be ones a project can act on.
void main() {
  Directory monorepoRoot() {
    var dir = Directory.current.absolute;
    while (!Directory(p.join(dir.path, 'toolkit', 'skills')).existsSync()) {
      final up = dir.parent;
      if (up.path == dir.path) {
        throw StateError('no monorepo root above ${Directory.current.path}');
      }
      dir = up;
    }
    return dir;
  }

  group('parsing', () {
    DwMigrationNote note(String contents) {
      final parsed = parseMigrationNote(contents: contents, path: 'n.md');
      expect(
        parsed,
        isA<DwMigrationNote>(),
        reason: parsed is DwMigrationNoteProblem ? parsed.problem : null,
      );
      return parsed as DwMigrationNote;
    }

    String problem(String contents) {
      final parsed = parseMigrationNote(contents: contents, path: 'n.md');
      expect(parsed, isA<DwMigrationNoteProblem>());
      return (parsed as DwMigrationNoteProblem).problem;
    }

    test('a well-formed note gives its title, packages and body', () {
      final parsed = note(
        '---\n'
        'title: DwCore.init takes its plugins as a list\n'
        'affects:\n'
        '  dartway_core_flutter: "0.8.0"\n'
        '---\n'
        '\n'
        '## What to change\n'
        'Pass a list.\n',
      );

      expect(parsed.title, 'DwCore.init takes its plugins as a list');
      expect(parsed.affects, {'dartway_core_flutter': '0.8.0'});
      expect(parsed.body, contains('Pass a list.'));
    });

    test('an unquoted version is refused rather than compared', () {
      // `0.8` is a YAML number, and comparing a project against it would
      // silently answer a question nobody asked. This is the mistake the form
      // invites, so it is the one that has to fail loudly.
      expect(
        problem(
          '---\n'
          'title: t\n'
          'affects:\n'
          '  dartway_core_flutter: 0.8\n'
          '---\n',
        ),
        contains('full version in quotes'),
      );
    });

    test('a note with no affects: is refused', () {
      expect(problem('---\ntitle: t\n---\n'), contains('at least one package'));
    });

    test(
      'a note naming something that is not a framework package is refused',
      () {
        expect(
          problem('---\ntitle: t\naffects:\n  go_router: "1.0.0"\n---\n'),
          contains('not a framework package'),
        );
      },
    );

    test('a file with no frontmatter is refused, not skipped', () {
      // Skipping is the dangerous answer: a note dropped for a typo is a
      // migration nobody is ever told about.
      expect(problem('# Just a heading\n'), contains('no frontmatter'));
    });
  });

  group('readMigrationNotes orders by date, then version, then name', () {
    late Directory sandbox;

    setUp(() {
      sandbox = Directory.systemTemp.createTempSync('dw_migration_notes');
    });
    tearDown(() => sandbox.deleteSync(recursive: true));

    void writeNote(String fileName, String package, String affectsVersion) {
      final dir = Directory(p.join(sandbox.path, migrationNotesDir))
        ..createSync(recursive: true);
      File(p.join(dir.path, fileName)).writeAsStringSync(
        '---\n'
        'title: "$fileName"\n'
        'affects:\n'
        '  $package: "$affectsVersion"\n'
        '---\n',
      );
    }

    test('a same-day pair out of name order is put back in version order', () {
      // "account-…" sorts before "contract-…" by name, but its version is the
      // later one — exactly the shape of the real 2026-09-24 notes this fix
      // is for. All three name dartway_core_server, so the version comparison
      // applies.
      writeNote(
        '2026-09-24-account-deletion-choice.md',
        'dartway_core_server',
        '0.21.0-dev.3',
      );
      writeNote(
        '2026-09-24-contract-version.md',
        'dartway_core_server',
        '0.20.0-dev.4',
      );
      writeNote(
        '2026-09-24-generate-deliver-code-split.md',
        'dartway_core_server',
        '0.21.0-dev.2',
      );

      final read = readMigrationNotes(sandbox);

      expect(read.problems, isEmpty);
      expect(read.notes.map((note) => p.basename(note.path)), [
        '2026-09-24-contract-version.md',
        '2026-09-24-generate-deliver-code-split.md',
        '2026-09-24-account-deletion-choice.md',
      ]);
    });

    test('two notes at the same version fall back to file name', () {
      writeNote('2026-09-24-b.md', 'dartway_core_server', '0.21.0-dev.3');
      writeNote('2026-09-24-a.md', 'dartway_core_server', '0.21.0-dev.3');

      final read = readMigrationNotes(sandbox);

      expect(read.notes.map((note) => p.basename(note.path)), [
        '2026-09-24-a.md',
        '2026-09-24-b.md',
      ]);
    });

    test('the date wins over the version when the notes name different '
        'packages — a satellite\'s small version is not "behind" the '
        'family\'s', () {
      // Comparing raw semver across packages put a satellite note ahead of
      // an earlier family note purely because 0.4.0 < 0.20.0-dev.2 as
      // numbers — a comparison neither package's version has any business
      // being put through. This is the shape of the real
      // 2026-09-22 (family) / 2026-09-23 (dartway_lints) notes.
      writeNote(
        '2026-09-22-local-environment.md',
        'dartway_core_server',
        '0.20.0-dev.2',
      );
      writeNote(
        '2026-09-23-lints-analyzer-plugin.md',
        'dartway_lints',
        '0.4.0',
      );

      final read = readMigrationNotes(sandbox);

      expect(read.notes.map((note) => p.basename(note.path)), [
        '2026-09-22-local-environment.md',
        '2026-09-23-lints-analyzer-plugin.md',
      ]);
    });

    test('two notes on the same day naming unrelated packages fall back to '
        'file name — their versions cannot be compared at all', () {
      writeNote('2026-09-24-b-lints.md', 'dartway_lints', '0.4.0');
      writeNote('2026-09-24-a-cli.md', 'dartway_cli', '0.11.0');

      final read = readMigrationNotes(sandbox);

      expect(read.notes.map((note) => p.basename(note.path)), [
        '2026-09-24-a-cli.md',
        '2026-09-24-b-lints.md',
      ]);
    });
    test('within a day the family is one version line, and a satellite-only '
        'note follows the family notes — the order stays total', () {
      // A (core_server dev.3), B (lints), C (core_flutter dev.2): comparing
      // pair by pair on a package both name gave A < B, B < C by name and
      // C < A by version — no order at all.
      writeNote('2026-09-24-a.md', 'dartway_core_server', '0.21.0-dev.3');
      writeNote('2026-09-24-b.md', 'dartway_lints', '0.4.0');
      writeNote('2026-09-24-c.md', 'dartway_core_flutter', '0.21.0-dev.2');

      final read = readMigrationNotes(sandbox);

      expect(read.notes.map((note) => p.basename(note.path)), [
        '2026-09-24-c.md',
        '2026-09-24-a.md',
        '2026-09-24-b.md',
      ]);
    });

    test('a file whose name does not start with a date is a problem, '
        'not a crash', () {
      writeNote('x.md', 'dartway_core_server', '0.21.0-dev.3');
      writeNote('2026-09-24-a.md', 'dartway_core_server', '0.21.0-dev.3');

      final read = readMigrationNotes(sandbox);

      expect(read.notes.map((note) => p.basename(note.path)), [
        '2026-09-24-a.md',
      ]);
      expect(read.problems.single.path, endsWith('x.md'));
    });
  });

  group('the notes this repository ships', () {
    test('ships the CI lock gate to projects updating the CLI', () {
      final read = readMigrationNotes(monorepoRoot());
      final lockNotes = read.notes.where(
        (note) =>
            note.path == 'docs/migrations/2026-10-10-ci-holds-the-locks.md',
      );

      expect(
        lockNotes,
        hasLength(1),
        reason: 'projects created before #495 must receive the CI lock gate',
      );
      final note = lockNotes.single;
      expect(note.affects, {'dartway_cli': '0.24.0'});
      expect(
        RegExp(r'pub get --enforce-lockfile').allMatches(note.body),
        hasLength(3),
      );
    });

    test('all parse, and name packages at versions that exist', () {
      final root = monorepoRoot();
      final read = readMigrationNotes(root);
      final versions = readFrameworkVersions(root);

      expect(
        read.problems.map((problem) => problem.toString()),
        isEmpty,
        reason:
            'a note that cannot be read is a migration nobody is told '
            'about — see docs/migrations/README.md for the form',
      );

      for (final note in read.notes) {
        for (final entry in note.affects.entries) {
          final current = versions[entry.key];
          expect(
            current,
            isNotNull,
            reason:
                '${note.path} names ${entry.key}, which is not a package '
                'in this monorepo',
          );
          // A note may name the version it is landing in — the one this pull
          // request bumps to — but never one further out: a version nothing is
          // moving towards is a migration that never becomes due.
          expect(
            isPackageAtLeastVersion(current!, entry.value),
            isTrue,
            reason:
                '${note.path} says ${entry.key} ${entry.value}, but the '
                'package is on $current. Either the bump is missing from this '
                'change, or the note names the wrong version',
          );
        }
      }
    });

    test('file names sort chronologically', () {
      // The notes are applied in the order they are listed, and the only thing
      // making that order meaningful is the date the name starts with.
      final dir = Directory(p.join(monorepoRoot().path, migrationNotesDir));
      final names = dir
          .listSync()
          .whereType<File>()
          .map((file) => p.basename(file.path))
          .where((name) => name != 'README.md' && name.endsWith('.md'));

      for (final name in names) {
        expect(
          RegExp(r'^\d{4}-\d{2}-\d{2}-').hasMatch(name),
          isTrue,
          reason: '$name does not start with a date',
        );
      }
    });
  });
}
