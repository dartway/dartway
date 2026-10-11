import 'dart:io';

import 'package:args/command_runner.dart';

import '../deploy/kamal.dart';
import 'deploy_command.dart';

class DeployKamalCommand extends Command<int> {
  DeployKamalCommand() {
    argParser.addFlag(
      'check',
      negatable: false,
      help: 'Fail on stale generated deployment files, without writing them.',
    );
  }

  @override
  String get name => 'kamal';

  @override
  String get description =>
      'Generate Kamal destinations, the Studio manifest and CI image builds.';

  @override
  Future<int> run() async {
    final check = argResults!.flag('check');
    final stale = DwKamalGenerator(deployProjectRoot()).generate(check: check);
    if (check && stale.isNotEmpty) {
      stderr.writeln(
        'Stale Kamal files: ${stale.join(', ')}. '
        'Run dartway deploy kamal and commit the result.',
      );
      return 1;
    }
    stdout.writeln(
      check
          ? 'Kamal files are current.'
          : 'Updated ${stale.length} Kamal files.',
    );
    return 0;
  }
}
