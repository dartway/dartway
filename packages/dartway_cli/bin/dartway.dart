import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:dartway_cli/src/commands/check_command.dart';
import 'package:dartway_cli/src/commands/create_command.dart';
import 'package:dartway_cli/src/commands/deploy_command.dart';
import 'package:dartway_cli/src/commands/dev_command.dart';
import 'package:dartway_cli/src/commands/doctor_command.dart';
import 'package:dartway_cli/src/commands/generate_command.dart';
import 'package:dartway_cli/src/commands/quickstart_command.dart';
import 'package:dartway_cli/src/commands/secret_commands.dart';
import 'package:dartway_cli/src/commands/setup_ai_command.dart';
import 'package:dartway_cli/src/commands/stats_command.dart';
import 'package:dartway_cli/src/commands/test_command.dart';
import 'package:dartway_cli/src/commands/update_command.dart';
import 'package:dartway_cli/src/pinned_cli.dart';
import 'package:dartway_cli/src/project_layout.dart';

/// Commands that read or write an existing project, and so have to be the
/// CLI that project pins. The rest either make a project (`create`,
/// `quickstart`), repair its pins (`update`, `setup-ai`) or touch nothing
/// (`doctor`).
const Set<String> _projectCommands = {
  'generate',
  'check',
  'test',
  'deploy',
  'dev',
  'stats',
};

Future<void> main(List<String> args) async {
  if (args.isNotEmpty && _projectCommands.contains(args.first)) {
    final pinned = DwPinnedCli.of(findProjectRoot());
    if (!pinned.isPinnedOne) {
      stderr.writeln(pinned.complaintFor(args.join(' ')));
      exitCode = 1;
      return;
    }
  }
  final runner =
      CommandRunner<int>(
          'dartway',
          'DartWay framework CLI: setup instructions, environment checks, '
              'project scaffolding, AI toolkit setup and convention checks.',
        )
        ..addCommand(QuickstartCommand())
        ..addCommand(DoctorCommand())
        ..addCommand(CreateCommand())
        ..addCommand(SetupAiCommand())
        ..addCommand(UpdateCommand())
        ..addCommand(GenerateCommand())
        ..addCommand(CheckCommand())
        ..addCommand(DevCommand())
        ..addCommand(DeployCommand())
        ..addCommand(SecretCommand())
        ..addCommand(StatsCommand())
        ..addCommand(TestCommand());

  try {
    exitCode = await runner.run(args) ?? 0;
  } on UsageException catch (exception) {
    stderr.writeln(exception);
    exitCode = 64;
  } on StateError catch (exception) {
    stderr.writeln('Error: ${exception.message}');
    exitCode = 1;
  }
}
