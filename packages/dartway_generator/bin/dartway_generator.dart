import 'dart:io';

import 'package:args/args.dart';
import 'package:dartway_generator/dartway_generator.dart';

/// `dart run dartway_generator [--project <dir>] [--check] [--sdk <dir>]`
Future<void> main(List<String> arguments) async {
  final parser = ArgParser()
    ..addOption(
      'project',
      abbr: 'p',
      help:
          'The project root (holding the *_shared and *_server packages), '
          'or one of those packages.',
      defaultsTo: '.',
    )
    ..addFlag(
      'check',
      negatable: false,
      help:
          'Write nothing; exit 1 when a generated file is out of date or stale. '
          'For CI.',
    )
    ..addOption(
      'sdk',
      help: 'The Dart SDK to analyze against (default: the running dart).',
    )
    ..addFlag('verbose', abbr: 'v', negatable: false, help: 'List every file.')
    ..addFlag('help', abbr: 'h', negatable: false);

  final ArgResults options;
  try {
    options = parser.parse(arguments);
  } on FormatException catch (error) {
    stderr
      ..writeln(error.message)
      ..writeln(parser.usage);
    exitCode = 64;
    return;
  }
  if (options.flag('help')) {
    stdout
      ..writeln('Generates the code of a DartWay project.')
      ..writeln()
      ..writeln(parser.usage);
    return;
  }

  final report = await DwGenerator.run(
    options.option('project')!,
    sdkPath: options.option('sdk'),
    check: options.flag('check'),
  );

  for (final diagnostic in report.diagnostics) {
    stderr.writeln(diagnostic.format(report.root));
  }
  if (options.flag('verbose') || report.check) {
    final verb = report.check ? 'out of date' : 'wrote';
    for (final path in report.written) {
      stdout.writeln('  $verb ${_relative(path, report.root)}');
    }
    final removal = report.check ? 'stale' : 'removed';
    for (final path in report.removed) {
      stdout.writeln('  $removal ${_relative(path, report.root)}');
    }
  }
  (report.hasErrors ? stderr : stdout).writeln(report.summary);

  if (report.hasErrors) {
    exitCode = 1;
  } else if (report.check && !report.isUpToDate) {
    exitCode = 1;
  }
}

String _relative(String path, String root) =>
    path.startsWith('$root${Platform.pathSeparator}')
    ? path.substring(root.length + 1)
    : path;
