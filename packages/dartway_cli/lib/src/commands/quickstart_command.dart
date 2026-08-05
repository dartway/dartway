import 'dart:io';

import 'package:args/command_runner.dart';

import '../quickstart_brief.dart';

/// Prints the agent-facing setup brief.
///
/// The entry point to DartWay is two commands a human pastes anywhere —
/// `dart pub global activate dartway_cli` and `dartway quickstart` — after
/// which whatever assistant is at hand has the full instruction in its context.
/// Deliberately not a plugin for one particular assistant: the framework's
/// front door must not depend on a vendor's extension format.
class QuickstartCommand extends Command<int> {
  @override
  String get name => 'quickstart';

  @override
  String get description =>
      'Print the setup instructions for an AI coding agent (or a human).';

  @override
  String get invocation => 'dartway quickstart';

  @override
  Future<int> run() async {
    stdout.write(quickstartBrief);
    return 0;
  }
}
