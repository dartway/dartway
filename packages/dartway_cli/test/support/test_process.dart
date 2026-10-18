import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

final _stops = Expando<Future<void> Function()>();

/// Owns the whole fixture process group, including analyzer/plugin children.
/// Teardown waits for termination before the caller deletes its fixture.
Future<Process> startTestProcess(
  String executable,
  List<String> arguments, {
  String? workingDirectory,
  Map<String, String>? environment,
  String? processGroupFile,
}) async {
  final control = Directory.systemTemp.createTempSync('dw-process-group-');
  final marker = File(processGroupFile ?? p.join(control.path, 'pid'));
  final process = await Process.start(
    '/bin/bash',
    [
      '-c',
      r'''
set -m
group_file=$1
shift
"$@" &
child=$!
printf '%s\n' "$child" > "$group_file"
trap 'kill -s INT "$child" 2>/dev/null; wait "$child"; exit $?' INT
wait "$child"
''',
      'dartway-test-group',
      marker.path,
      executable,
      ...arguments,
    ],
    workingDirectory: workingDirectory,
    environment: environment,
  );
  Future<void>? stopping;
  Future<void> stop() => stopping ??= () async {
    // The shell writes the group before waiting, so an exited wrapper also
    // leaves enough information to stop descendants holding stdout open.
    if (marker.existsSync()) {
      final group = marker.readAsStringSync().trim();
      Future<void> signal(String name) async {
        await Process.run('/bin/bash', [
          '-c',
          r'kill -s "$1" -- "-$2" 2>/dev/null',
          'dartway-test-group',
          name,
          group,
        ]);
      }

      await signal('TERM');
      try {
        await process.exitCode.timeout(const Duration(seconds: 1));
      } on TimeoutException {
        // A fixture may intentionally ignore TERM; it still belongs to us.
      } finally {
        await signal('KILL');
      }
    }
    process.kill(ProcessSignal.sigkill);
    await process.exitCode;
    await control.delete(recursive: true);
  }();
  _stops[process] = stop;
  addTearDown(stop);
  return process;
}

/// A deadline includes draining output, since a descendant can hold the pipes
/// open after the immediate child exits. A timeout always stops the group.
Future<ProcessResult> runTestProcess(
  String executable,
  List<String> arguments, {
  String? workingDirectory,
  Map<String, String>? environment,
  Duration timeout = const Duration(minutes: 2),
}) async {
  final process = await startTestProcess(
    executable,
    arguments,
    workingDirectory: workingDirectory,
    environment: environment,
  );
  final output = process.stdout.transform(utf8.decoder).join();
  final errors = process.stderr.transform(utf8.decoder).join();
  try {
    return await (() async => ProcessResult(
      process.pid,
      await process.exitCode,
      await output,
      await errors,
    ))().timeout(timeout);
  } on TimeoutException {
    await _stops[process]!();
    throw TimeoutException(
      '$executable ${arguments.join(' ')}\n${await output}${await errors}',
      timeout,
    );
  } finally {
    await _stops[process]!();
  }
}
