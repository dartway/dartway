import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;

import '../framework_versions.dart';
import '../migration_notes.dart';
import '../monorepo_source.dart';
import '../project_layout.dart';
import '../toolkit_install.dart';
import '../toolkit_manifest.dart';
import '../version_check.dart';

/// Brings a project up to the framework: the toolkit, and the report of
/// everything else that has moved since the project last looked.
///
/// **The command does not edit the project's code, and that is deliberate.** It
/// installs `.claude/` — a generated artifact, whose whole update is a copy —
/// and for everything else it produces the work list: which packages are
/// behind, and which migration notes the project still owes an edit to. Raising
/// a caret is one line; answering a changed API is not, and a command that
/// half-did it would leave a tree nobody can tell apart from a finished one.
/// The `dartway-update` skill is what carries the list out.
///
/// Why a command at all, rather than three remembered ones: nothing else in a
/// project ever says it has fallen behind. The toolkit is a committed artifact
/// that looks the same when it is a month old, and a git dependency shows no
/// version anywhere a person reads. Four projects on this framework had drifted
/// apart by up to three weeks of skills, and every one of them looked fine.
class UpdateCommand extends Command<int> {
  UpdateCommand() {
    addToolkitInstallOptions(
      argParser,
      // Unlike `setup-ai`, the default here is the channel the project is
      // already on: "update" means move forward on my own channel, and a
      // default that meant `stable` would carry a project deliberately put on
      // `master` backwards every time it was run without arguments.
      defaultChannel:
          Platform.environment['DARTWAY_BRANCH'] ??
          MonorepoSource.defaultBranch,
    );
  }

  @override
  String get name => 'update';

  @override
  String get description =>
      'Update the DartWay toolkit in this project and report what else has '
      'moved: package versions and migrations still to apply.';

  @override
  Future<int> run() async {
    final projectRoot = findProjectRoot();
    final installed = ToolkitProvenance.read(projectRoot);

    stdout.writeln(
      installed == null
          ? 'Installed toolkit: not recorded — this project was set up before '
                'the CLI wrote a manifest, so what follows is measured against '
                'the code rather than against the last install.'
          : 'Installed toolkit: ${installed.describe()}',
    );

    final result = await installToolkitInto(
      projectRoot: projectRoot,
      choice: ToolkitInstallChoice.resolve(
        args: argResults!,
        installed: installed,
        followRecordedChannel: true,
      ),
      installed: installed,
    );
    if (result == null) return 1;

    stdout.writeln('Toolkit installed: ${result.provenance.describe()}');

    final frameworkVersions = readFrameworkVersions(result.monorepoDir);
    _reportCliVersion(frameworkVersions);

    final gaps = compareToFramework(
      projectRoot: projectRoot,
      frameworkVersions: frameworkVersions,
    );
    _reportPackages(gaps);
    _reportMigrations(result.monorepoDir, gaps);

    stdout.writeln(
      '\nCommit .claude/ with the rest of the update, so the history says '
      'which skills the code was written with.',
    );
    return 0;
  }

  /// The CLI running this is itself a framework package, and it is the one
  /// nothing else can move: an old CLI installs the toolkit with whatever it
  /// understood a month ago, and says nothing about the parts it does not know
  /// exist. It cannot replace itself mid-run, so it says so and carries on.
  void _reportCliVersion(Map<String, String> frameworkVersions) {
    final channelVersion = frameworkVersions['dartway_cli'];
    if (channelVersion == null) return;
    if (isAtLeastVersion(dartwayCliVersion, channelVersion)) return;
    stdout.writeln(
      '\n⚠️  This CLI is $dartwayCliVersion, the channel has $channelVersion.\n'
      '   Update it first and run this again — an older CLI installs an older '
      'idea of what a project needs:\n'
      '   dart pub global activate dartway_cli',
    );
  }

  void _reportPackages(List<DwPackageGap> gaps) {
    if (gaps.isEmpty) {
      stdout.writeln(
        '\n📦 Framework packages: none resolved — no pubspec.lock here yet. '
        'Run `dart pub get` and this again.',
      );
      return;
    }

    final behind = gaps.where((gap) => gap.isBehind).toList();
    stdout.writeln('\n📦 Framework packages');
    if (behind.isEmpty) {
      stdout.writeln('   all ${gaps.length} up to date with the channel.');
      return;
    }

    for (final gap in behind) {
      stdout.writeln(
        '   ${gap.name.padRight(34)} ${gap.projectVersion} → '
        '${gap.frameworkVersion}   in ${gap.locations.join(', ')}',
      );
    }
    final hosted = behind.where((gap) => !gap.fromGit).toList();
    final git = behind.where((gap) => gap.fromGit).toList();
    if (hosted.isNotEmpty) {
      stdout.writeln(
        '\n   Hosted: raise the caret in pubspec.yaml, then `dart pub get`. '
        'Under a 0.x major a minor behaves like a major, so ^0.4.0 does not '
        'let 0.8.0 in — the caret has to move.',
      );
    }
    if (git.isNotEmpty) {
      stdout.writeln(
        '\n   From git: `dart pub upgrade ${git.map((gap) => gap.name).join(' ')}` '
        'in ${{for (final gap in git) ...gap.locations}.join(', ')}.',
      );
    }
  }

  /// The migrations this project still owes, keyed off the packages it is
  /// actually behind on.
  void _reportMigrations(Directory monorepoDir, List<DwPackageGap> gaps) {
    final read = readMigrationNotes(monorepoDir);
    if (read.problems.isNotEmpty) {
      stdout.writeln(
        '\n⚠️  Migration notes that could not be read (a framework defect, '
        'not this project\'s — file it):',
      );
      for (final problem in read.problems) {
        stdout.writeln('   $problem');
      }
    }

    final projectVersions = {
      for (final gap in gaps) gap.name: gap.projectVersion,
    };
    final pending = migrationNotesToApply(
      notes: read.notes,
      projectVersions: projectVersions,
    );

    if (pending.isEmpty) {
      stdout.writeln(
        '\n🧭 Migrations: none — nothing in this update asks the project to '
        'change its own code.',
      );
      return;
    }

    stdout.writeln(
      '\n🧭 Migrations to apply (${pending.length}), oldest first:',
    );
    for (final note in pending) {
      stdout.writeln('   • ${note.title}');
      stdout.writeln('     ${p.join(monorepoDir.path, note.path)}');
      stdout.writeln(
        '     lands in ${note.affects.entries.map((entry) => '${entry.key} ${entry.value}').join(', ')}',
      );
    }
    stdout.writeln(
      '\n   Read them there and make the edits before moving the packages: '
      'they say what the new version expects that the old one did not.',
    );
  }
}
