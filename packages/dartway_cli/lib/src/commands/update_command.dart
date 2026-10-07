import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

import '../framework_overrides.dart';
import '../framework_versions.dart';
import '../lints_preflight.dart';
import '../migration_state.dart';
import '../toolkit_installer.dart';
import '../update_target.dart';
import '../migration_notes.dart';
import '../monorepo_source.dart';
import '../project_layout.dart';
import '../toolkit_install.dart';
import '../toolkit_manifest.dart';
import '../version_check.dart';

/// Plans an exact framework target before installing its toolkit or lint pin.
/// Migration completion is a separate, verified project record.
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
    argParser
      ..addFlag(
        'plan',
        negatable: false,
        help: 'Read-only plan; no project files are changed.',
      )
      ..addOption(
        'target',
        help:
            'Exact 40-character framework commit from the plan. Required for writes.',
      )
      ..addMultiOption(
        'complete',
        splitCommas: false,
        help: 'Migration note path verified as applied (repeat per note).',
      )
      ..addMultiOption(
        'not-applicable',
        splitCommas: false,
        help:
            'Migration note path verified as not applicable (repeat per note).',
      )
      ..addFlag(
        'verified',
        negatable: false,
        help: 'Confirm the selected note dispositions were verified.',
      )
      ..addOption(
        'verification',
        help:
            'Checks/results or applicability evidence for these dispositions.',
      );
    argParser.addOption(
      'framework-path',
      help:
          'A local DartWay checkout the project builds against: the '
          'dartway_lints plugin is then pinned to it by path, as '
          '`dartway create --framework-path` pins it.',
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
    final args = argResults!;
    final planOnly = args['plan'] as bool;
    final commit = args['target'] as String?;
    final applied = (args['complete'] as List<String>).toSet();
    final notApplicable = (args['not-applicable'] as List<String>).toSet();
    final completing = applied.isNotEmpty || notApplicable.isNotEmpty;
    final verification = (args['verification'] as String?)?.trim();
    if (planOnly && completing) {
      usageException('--plan cannot record completion.');
    }
    if (!planOnly && commit == null) {
      usageException(
        'Run update --plan first, then use its exact --target SHA.',
      );
    }
    if (completing &&
        (!(args['verified'] as bool) ||
            verification == null ||
            verification.isEmpty)) {
      usageException(
        'Completion requires --verified and --verification evidence.',
      );
    }
    if (applied.intersection(notApplicable).isNotEmpty) {
      usageException('A note cannot be both applied and not applicable.');
    }
    if (!completing && ((args['verified'] as bool) || verification != null)) {
      usageException('Verification requires a selected note disposition.');
    }

    final projectRoot = findProjectRoot();
    final layout = ProjectLayout.detect(projectRoot);
    final state = DwMigrationState.read(projectRoot);
    final installed = ToolkitProvenance.read(projectRoot);
    final choice = ToolkitInstallChoice.resolve(
      args: args,
      installed: installed,
      followRecordedChannel: true,
    );
    final source = MonorepoSource(
      branch: choice.channel,
      localDir: choice.localRepo,
      channelChosen: choice.channelChosen,
    );
    final refusal = channelSwitchRefusal(
      installed: installed,
      requestedChannel: choice.channel,
      channelWasExplicit: choice.channelWasExplicit,
      fromLocalCheckout: source.isNamedCheckout,
      cliCheckout: source.isNamedCheckout ? null : source.localDir,
    );
    if (refusal != null) throw StateError(refusal);
    final target = await DwUpdateTarget.resolve(source, commit: commit);
    try {
      stdout.writeln('Update target: ${target.source} @ ${target.commit}');
      stdout.writeln(
        'Committed target files only; local uncommitted edits are excluded.',
      );
      choice.describe(stdout);
      final versions = readFrameworkVersions(target.directory);
      if (versions.isEmpty)
        throw StateError('Target has no framework packages.');
      for (final entry in versions.entries) {
        if (!isPackageAtLeastVersion(entry.value, entry.value)) {
          throw StateError(
            'Invalid target version: ${entry.key} ${entry.value}',
          );
        }
      }
      _reportCliVersion(versions);
      final gaps = compareToFramework(
        projectRoot: projectRoot,
        frameworkVersions: versions,
      );
      _reportPackages(gaps);
      final read = readMigrationNotes(target.directory);
      if (read.problems.isNotEmpty) {
        throw StateError(
          'Unreadable migration notes:\n${read.problems.join('\n')}',
        );
      }
      final packages = {for (final gap in gaps) gap.name};
      // A project with no lock still has declared dependencies. Locks describe
      // installed packages, never migration completion.
      for (final dir in [
        projectRoot,
        layout.sharedPackageDir,
        layout.serverPackageDir,
        layout.flutterPackageDir,
      ]) {
        final pubspec = File(p.join(dir.path, 'pubspec.yaml'));
        if (!pubspec.existsSync()) continue;
        final document = loadYaml(pubspec.readAsStringSync());
        if (document is! YamlMap) continue;
        for (final section in ['dependencies', 'dev_dependencies']) {
          final dependencies = document[section];
          if (dependencies is YamlMap) {
            packages.addAll(dependencies.keys.whereType<String>());
          }
        }
      }
      final notes = read.notes
          .where(
            (note) => note.affects.entries.any(
              (entry) =>
                  packages.contains(entry.key) &&
                  versions[entry.key] != null &&
                  isPackageAtLeastVersion(versions[entry.key]!, entry.value),
            ),
          )
          .toList();
      if (completing) {
        final byPath = {for (final note in notes) note.path: note};
        for (final path in {...applied, ...notApplicable}) {
          if (!byPath.containsKey(path)) {
            throw StateError(
              'Note is not relevant to this target/project: $path',
            );
          }
        }
        for (final path in {...applied, ...notApplicable}) {
          state.record(
            byPath[path]!,
            disposition: applied.contains(path) ? 'applied' : 'not-applicable',
            target: target.commit,
            verification: verification!,
          );
        }
        state.write(projectRoot);
        stdout.writeln(
          'Verified dispositions recorded; toolkit and locks do not complete notes.',
        );
        _reportMigrations(notes, state);
        return 0;
      }
      _reportMigrations(notes, state);
      final version = versions['dartway_lints'];
      if (version == null)
        throw StateError('Target has no dartway_lints package.');
      final frameworkPath = args['framework-path'] as String?;
      final pluginPath = frameworkPath == null
          ? null
          : frameworkPackageDirectories(
              Directory(p.normalize(p.absolute(frameworkPath))),
            )['dartway_lints'];
      if (frameworkPath != null && pluginPath == null) {
        throw StateError('No dartway_lints package under --framework-path.');
      }
      final options = File(
        p.join(layout.flutterPackageDir.path, 'analysis_options.yaml'),
      );
      final lintPlan = await DwLintsPlan.preflight(
        options,
        version,
        path: pluginPath,
      );
      stdout.writeln(
        'Analyzer plugin: resolvable; ${lintPlan.change ?? 'existing source retained'}.',
      );
      stdout.writeln('   ${lintPlan.sourceDescription}');
      if (planOnly) {
        stdout.writeln(
          'Read-only plan. To install, run update with the same source/options '
          'and --target ${target.commit}. Verify each note before recording its disposition.',
        );
        return 0;
      }
      await ToolkitInstaller.install(
        toolkitDir: Directory(p.join(target.directory.path, 'toolkit')),
        projectRoot: projectRoot,
        tokens: layout.toolkitTokens(
          baseBranch: choice.baseBranch,
          language: choice.language,
          notesTracker: choice.notesTracker,
        ),
        agent: choice.agent,
        provenance: ToolkitProvenance(
          source: target.source,
          channel: source.isLocalCheckout ? null : choice.channel,
          commit: target.commit,
          cliVersion: dartwayCliVersion,
          installedAt: DateTime.now().toUtc().toIso8601String(),
          settings: choice.settings,
        ),
      );
      lintPlan.apply(options);
      stdout.writeln(
        'Commit toolkit and instruction blocks with the update. '
        'No migration notes were marked complete.',
      );
      return 0;
    } finally {
      target.dispose();
    }
  }

  /// The CLI running this is itself a framework package, and it is the one
  /// nothing else can move: an old CLI installs the toolkit with whatever it
  /// understood a month ago, and says nothing about the parts it does not know
  /// exist. It cannot replace itself mid-run, so it says so and carries on.
  void _reportCliVersion(Map<String, String> frameworkVersions) {
    final channelVersion = frameworkVersions['dartway_cli'];
    if (channelVersion == null) return;
    if (isPackageAtLeastVersion(dartwayCliVersion, channelVersion)) return;
    stdout.writeln(
      '\n⚠️  This CLI is $dartwayCliVersion, the target has $channelVersion.\n'
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
      stdout.writeln('   all ${gaps.length} up to date with the target.');
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

  void _reportMigrations(List<DwMigrationNote> notes, DwMigrationState state) {
    if (state.records.isEmpty) {
      stdout.writeln(
        '\nMigration baseline: unknown — no verified completion records. '
        'Dependency locks and toolkit installs are not migration evidence.',
      );
    }
    final pending = notes.where((note) => !state.completed(note)).toList();
    stdout.writeln(
      '\nUnconfirmed migration notes (${pending.length}), oldest first:',
    );
    for (final note in pending) {
      stdout.writeln('   • ${note.title}');
      stdout.writeln('     ${note.path}');
      stdout.writeln(
        '     lands in ${note.affects.entries.map((entry) => '${entry.key} ${entry.value}').join(', ')}',
      );
      stdout.writeln(note.body);
    }
    if (pending.isEmpty) {
      stdout.writeln(
        '   All relevant notes have explicit verified dispositions '
        '(or this target has no relevant notes).',
      );
    }
  }
}
