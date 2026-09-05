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
        '  dartway_flutter: "0.8.0"\n'
        '---\n'
        '\n'
        '## What to change\n'
        'Pass a list.\n',
      );

      expect(parsed.title, 'DwCore.init takes its plugins as a list');
      expect(parsed.affects, {'dartway_flutter': '0.8.0'});
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
          '  dartway_flutter: 0.8\n'
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

  group('selection', () {
    final note = DwMigrationNote(
      path: 'docs/migrations/2026-09-05-plugins.md',
      title: 'plugins as a list',
      affects: const {'dartway_flutter': '0.8.0'},
      body: '',
    );

    test('applies to a project below the version it lands in', () {
      expect(note.appliesTo({'dartway_flutter': '0.4.0'}), isTrue);
    });

    test('does not apply once the project has that version', () {
      expect(note.appliesTo({'dartway_flutter': '0.8.0'}), isFalse);
      expect(note.appliesTo({'dartway_flutter': '0.9.1'}), isFalse);
    });

    test('does not apply to a project without the package at all', () {
      // The "who is affected" filter, done mechanically: a project that never
      // depended on the package has nothing to change.
      expect(note.appliesTo({'dartway_router': '1.0.0'}), isFalse);
    });

    test('one package behind is enough when a note names several', () {
      final wide = DwMigrationNote(
        path: 'n.md',
        title: 't',
        affects: const {
          'dartway_flutter': '0.8.0',
          'dartway_serverpod_core_server': '0.12.0',
        },
        body: '',
      );
      expect(
        wide.appliesTo({
          'dartway_flutter': '0.8.0',
          'dartway_serverpod_core_server': '0.11.4',
        }),
        isTrue,
      );
    });
  });

  group('the notes this repository ships', () {
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
            isAtLeastVersion(current!, entry.value),
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
