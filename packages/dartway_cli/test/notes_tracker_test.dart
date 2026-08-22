import 'dart:io';

import 'package:dartway_cli/src/project_layout.dart';
import 'package:dartway_cli/src/toolkit_installer.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// `__NOTES_TRACKER__` names where a project's findings about the framework go,
/// and every way it can go wrong is quiet. An unsubstituted token is not a crash
/// but a sentence in the installed `CLAUDE.md` reading
/// `**Tracker:** __NOTES_TRACKER__`.
///
/// Hence what is pinned here: that a project which chose nothing still gets a
/// tracker rather than silence — the default is load-bearing, since a finding
/// pointed nowhere is exactly the failure this mechanism ends — that `none`
/// remains reachable as a deliberate opt-out, and that the token reaches the
/// installed `CLAUDE.md`.
///
/// `docs/dev_notes/` is pinned alongside it, because it is written through a
/// different path than the managed `.claude/` files: it carries
/// `__PROJECT_LANGUAGE__`, so it is the one place where forgetting to pass the
/// tokens would go unnoticed. Its two files answer to different owners and the
/// difference is the point — the form is the toolkit's and is refreshed on every
/// install, the coverage table is the project's and is never overwritten.
void main() {
  late Directory sandbox;

  setUp(() {
    sandbox = Directory.systemTemp.createTempSync('dw_notes_tracker');
  });

  tearDown(() {
    sandbox.deleteSync(recursive: true);
  });

  ProjectLayout layoutIn(Directory root) => ProjectLayout(
    root: root,
    serverPackage: 'my_app_server',
    clientPackage: 'my_app_client',
    flutterPackage: 'my_app_flutter',
  );

  /// A toolkit holding the minimum the installer insists on, plus the
  /// `dev_notes/` templates, each stating a token the way the real ones do.
  Directory writeToolkit() {
    final toolkitDir = Directory(p.join(sandbox.path, 'toolkit'))
      ..createSync(recursive: true);
    Directory(p.join(toolkitDir.path, 'skills')).createSync();
    Directory(p.join(toolkitDir.path, 'commands')).createSync();
    File(
      p.join(toolkitDir.path, 'CLAUDE.md'),
    ).writeAsStringSync('**Tracker:** `__NOTES_TRACKER__`.\n');

    final devNotes = Directory(p.join(toolkitDir.path, 'dev_notes'))
      ..createSync();
    File(p.join(devNotes.path, 'README.md')).writeAsStringSync(
      'The form. **Language:** `__PROJECT_LANGUAGE__`. '
      'Framework findings go to `__NOTES_TRACKER__`.\n',
    );
    File(
      p.join(devNotes.path, '_coverage.md'),
    ).writeAsStringSync('# Deep-pass coverage\n');
    return toolkitDir;
  }

  var installCount = 0;

  /// A fresh project root per call, unless one is handed in — the coverage file
  /// is never overwritten, so a second install into the same folder is exactly
  /// what some of these tests are about.
  Future<Directory> installInto(
    Directory? projectRoot, {
    String? notesTracker,
    String language = 'English',
  }) async {
    final root =
        projectRoot ??
        (Directory(p.join(sandbox.path, 'project${installCount++}'))
          ..createSync(recursive: true));

    await ToolkitInstaller.install(
      toolkitDir: writeToolkit(),
      projectRoot: root,
      tokens: layoutIn(root).toolkitTokens(
        baseBranch: 'master',
        notesTracker: notesTracker,
        language: language,
      ),
    );
    return root;
  }

  String read(Directory root, String relative) =>
      File(p.join(root.path, relative)).readAsStringSync();

  Future<String> claudeMdFor(String? notesTracker) async => read(
    await installInto(null, notesTracker: notesTracker),
    p.join('.claude', 'CLAUDE.md'),
  );

  group('the token', () {
    test('points at the framework tracker when nothing was chosen', () {
      final tokens = layoutIn(sandbox).toolkitTokens(baseBranch: 'master');

      expect(tokens['__NOTES_TRACKER__'], ProjectLayout.defaultNotesTracker);
      expect(
        tokens['__NOTES_TRACKER__'],
        isNot(ProjectLayout.noNotesTracker),
        reason: 'a finding nobody pointed anywhere is the failure this fixes',
      );
    });

    test('carries the repository it was given', () {
      final tokens = layoutIn(sandbox).toolkitTokens(
        baseBranch: 'master',
        notesTracker: 'acme/internal-tracker',
      );

      expect(tokens['__NOTES_TRACKER__'], 'acme/internal-tracker');
    });

    test('honours the opt-out', () {
      final tokens = layoutIn(sandbox).toolkitTokens(
        baseBranch: 'master',
        notesTracker: ProjectLayout.noNotesTracker,
      );

      expect(tokens['__NOTES_TRACKER__'], ProjectLayout.noNotesTracker);
    });
  });

  group('the installed guide', () {
    test('names the tracker it was installed with', () async {
      expect(
        await claudeMdFor('acme/internal-tracker'),
        contains('acme/internal-tracker'),
      );
    });

    test('names the framework tracker when none was chosen', () async {
      expect(
        await claudeMdFor(null),
        contains(ProjectLayout.defaultNotesTracker),
      );
    });

    test('never keeps the raw token, tracker or not', () async {
      expect(await claudeMdFor(null), isNot(contains('__NOTES_TRACKER__')));
      expect(
        await claudeMdFor(ProjectLayout.noNotesTracker),
        isNot(contains('__NOTES_TRACKER__')),
      );
    });

    test('reads as an answer when the tracker is opted out of', () async {
      expect(
        await claudeMdFor(ProjectLayout.noNotesTracker),
        contains('`${ProjectLayout.noNotesTracker}`'),
      );
    });
  });

  group('docs/dev_notes/', () {
    test('is created tracked, and nothing is added to .gitignore', () async {
      final root = Directory(p.join(sandbox.path, 'tracked'))
        ..createSync(recursive: true);
      final gitignore = File(p.join(root.path, '.gitignore'))
        ..writeAsStringSync('build/\n');

      await installInto(root);

      expect(
        File(p.join(root.path, 'docs', 'dev_notes', 'README.md')).existsSync(),
        isTrue,
      );
      expect(
        File(
          p.join(root.path, 'docs', 'dev_notes', '_coverage.md'),
        ).existsSync(),
        isTrue,
      );
      expect(
        gitignore.readAsStringSync(),
        'build/\n',
        reason: 'the findings are meant to travel out in a pull request',
      );
    });

    test('substitutes its tokens, the path they are not managed by', () async {
      final root = await installInto(null, language: 'Russian');
      final form = read(root, p.join('docs', 'dev_notes', 'README.md'));

      expect(form, contains('Russian'));
      expect(form, contains(ProjectLayout.defaultNotesTracker));
      expect(form, isNot(contains('__')));
    });

    test('refreshes the form on a second install', () async {
      final root = await installInto(null);
      final form = File(p.join(root.path, 'docs', 'dev_notes', 'README.md'))
        ..writeAsStringSync('a stale copy of the form');

      await installInto(root);

      expect(
        form.readAsStringSync(),
        contains('The form.'),
        reason:
            'the form is the toolkit\'s; there is no project content to lose',
      );
    });

    test('never overwrites the coverage table', () async {
      final root = await installInto(null);
      final coverage = File(
        p.join(root.path, 'docs', 'dev_notes', '_coverage.md'),
      )..writeAsStringSync('| app/issues | 2026-08-08 | 3 | 1 |');

      await installInto(root);

      expect(
        coverage.readAsStringSync(),
        contains('2026-08-08'),
        reason: 'the table is what this project knows about its own features',
      );
    });

    test('reports the retired journals instead of deleting them', () async {
      final root = Directory(p.join(sandbox.path, 'legacy'))
        ..createSync(recursive: true);
      final oldJournal = File(p.join(root.path, 'dartway_notes.md'))
        ..writeAsStringSync('### a finding nobody else has a copy of');

      final said = StringBuffer();
      await IOOverrides.runZoned(
        () => installInto(root),
        stdout: () => _CapturingStdout(said),
      );

      expect(
        oldJournal.readAsStringSync(),
        contains('nobody else has a copy of'),
        reason: 'an installer that deletes it takes the only copy with it',
      );
      expect(
        said.toString(),
        contains('dartway_notes.md'),
        reason: 'a journal nothing reads and nothing mentions is #100 again',
      );
    });

    test('leaves an entry alone on a re-install', () async {
      final root = await installInto(null);
      final entry = File(p.join(root.path, 'docs', 'dev_notes', 'ci-gap.md'))
        ..writeAsStringSync('# CI runs less than it declares');

      await installInto(root);

      expect(entry.existsSync(), isTrue);
      expect(entry.readAsStringSync(), contains('CI runs less'));
    });
  });
}

/// Enough of a [Stdout] to read back what the installer reported. `stdout` is a
/// `Stdout`, not a `print`, so a zone's print hook does not see it.
class _CapturingStdout implements Stdout {
  _CapturingStdout(this._said);

  final StringBuffer _said;

  @override
  void writeln([Object? object = '']) => _said.writeln(object);

  @override
  void write(Object? object) => _said.write(object);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
