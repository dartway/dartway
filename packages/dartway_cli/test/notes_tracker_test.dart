import 'dart:io';

import 'package:dartway_cli/src/project_layout.dart';
import 'package:dartway_cli/src/toolkit_installer.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// `__NOTES_TRACKER__` names where a project's findings about the framework go,
/// and every way it can go wrong is quiet. An unsubstituted token is not a crash
/// but a sentence in the installed `CLAUDE.md` reading
/// `**Tracker:** __NOTES_TRACKER__`, and it lands in a git-ignored file, so
/// nothing in a project's review would ever show it.
///
/// Hence what is pinned here: that a project which chose nothing still gets a
/// tracker rather than silence — the default is load-bearing, since a journal
/// pointed nowhere is exactly the failure this mechanism ends — that `none`
/// remains reachable as a deliberate opt-out, and that the token reaches the
/// journal at the project root. That last file the installer writes through a
/// different path than the managed `.claude/` ones, which makes it the one place
/// where forgetting to pass the tokens would go unnoticed.
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

  group('the token', () {
    test('points at the framework tracker when nothing was chosen', () {
      final tokens = layoutIn(sandbox).toolkitTokens(baseBranch: 'master');

      expect(tokens['__NOTES_TRACKER__'], ProjectLayout.defaultNotesTracker);
      expect(
        tokens['__NOTES_TRACKER__'],
        isNot(ProjectLayout.noNotesTracker),
        reason: 'a journal nobody pointed anywhere is the failure this fixes',
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

  group('the installed journal', () {
    /// A toolkit holding the minimum the installer insists on, plus a
    /// `dartway_notes.md` that states the tracker the way the real one does.
    Directory writeToolkit() {
      final toolkitDir = Directory(p.join(sandbox.path, 'toolkit'))
        ..createSync(recursive: true);
      Directory(p.join(toolkitDir.path, 'skills')).createSync();
      Directory(p.join(toolkitDir.path, 'commands')).createSync();
      File(
        p.join(toolkitDir.path, 'CLAUDE.md'),
      ).writeAsStringSync('**Tracker:** `__NOTES_TRACKER__`.\n');
      File(p.join(toolkitDir.path, 'dartway_notes.md')).writeAsStringSync(
        '**Tracker:** `__NOTES_TRACKER__` — where an entry goes.\n',
      );
      return toolkitDir;
    }

    var installCount = 0;

    /// A fresh project root per call: the installer never overwrites an
    /// existing journal, so a second install into the same folder would read
    /// back the first one's text and pass on it.
    Future<String> installWith(String? notesTracker) async {
      final projectRoot = Directory(
        p.join(sandbox.path, 'project${installCount++}'),
      )..createSync(recursive: true);

      await ToolkitInstaller.install(
        toolkitDir: writeToolkit(),
        projectRoot: projectRoot,
        tokens: layoutIn(
          projectRoot,
        ).toolkitTokens(baseBranch: 'master', notesTracker: notesTracker),
      );

      return File(
        p.join(projectRoot.path, 'dartway_notes.md'),
      ).readAsStringSync();
    }

    test('names the tracker it was installed with', () async {
      expect(
        await installWith('acme/internal-tracker'),
        contains('acme/internal-tracker'),
      );
    });

    test('names the framework tracker when none was chosen', () async {
      expect(
        await installWith(null),
        contains(ProjectLayout.defaultNotesTracker),
      );
    });

    test('never keeps the raw token, tracker or not', () async {
      expect(await installWith(null), isNot(contains('__NOTES_TRACKER__')));
      expect(
        await installWith(ProjectLayout.noNotesTracker),
        isNot(contains('__NOTES_TRACKER__')),
      );
    });

    test('reads as an answer when the tracker is opted out of', () async {
      expect(
        await installWith(ProjectLayout.noNotesTracker),
        contains('`${ProjectLayout.noNotesTracker}`'),
      );
    });
  });
}
