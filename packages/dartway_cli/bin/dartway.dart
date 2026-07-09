import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:dartway_cli/src/commands/check_command.dart';
import 'package:dartway_cli/src/commands/create_command.dart';
import 'package:dartway_cli/src/commands/setup_ai_command.dart';
import 'package:dartway_cli/src/commands/stats_command.dart';

Future<void> main(List<String> args) async {
  final runner =
      CommandRunner<int>(
          'dartway',
          'DartWay framework CLI: project scaffolding, AI toolkit setup and convention checks.',
        )
        ..addCommand(CreateCommand())
        ..addCommand(SetupAiCommand())
        ..addCommand(CheckCommand())
        ..addCommand(StatsCommand());

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
