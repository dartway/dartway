import 'dart:io';

import 'package:args/command_runner.dart';

import '../monorepo_source.dart';
import '../project_layout.dart';
import '../toolkit_install.dart';
import '../toolkit_manifest.dart';

/// Installs the DartWay AI toolkit (`.claude/`) in the current project.
///
/// The first-install door. A project that already has the toolkit is carried
/// forward by `dartway update`, which does this and then reports what else has
/// moved — the packages, and the migrations the project still owes.
class SetupAiCommand extends Command<int> {
  SetupAiCommand() {
    addToolkitInstallOptions(
      argParser,
      defaultChannel:
          Platform.environment['DARTWAY_BRANCH'] ??
          MonorepoSource.defaultBranch,
    );
  }

  @override
  String get name => 'setup-ai';

  @override
  String get description =>
      'Install the DartWay AI toolkit (.claude/) in the current project.';

  @override
  Future<int> run() async {
    final projectRoot = findProjectRoot();
    final installed = ToolkitProvenance.read(projectRoot);
    final result = await installToolkitInto(
      projectRoot: projectRoot,
      choice: ToolkitInstallChoice.resolve(
        args: argResults!,
        installed: installed,
      ),
      installed: installed,
    );
    if (result == null) return 1;

    stdout.writeln(
      'Done: .claude/CLAUDE.md, skills and commands installed. '
      'Commit .claude/ to your repository.',
    );
    return 0;
  }
}
