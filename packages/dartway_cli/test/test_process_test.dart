import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'support/test_process.dart';

void main() {
  test(
    'teardown stops an unfinished fixture process before deleting files',
    () async {
      final fixture = Directory.systemTemp.createTempSync('dw-process-');
      int? child;
      addTearDown(() async {
        try {
          expect(Process.killPid(child!, ProcessSignal.sigcont), isFalse);
        } finally {
          Process.killPid(child!, ProcessSignal.sigkill);
          await fixture.delete(recursive: true);
        }
      });
      final process = await startTestProcess('/bin/bash', [
        '-c',
        r'echo "$$"; exec sleep 600',
      ], workingDirectory: fixture.path);
      child = int.parse(
        await process.stdout
            .transform(utf8.decoder)
            .transform(const LineSplitter())
            .first,
      );
      unawaited(process.stderr.drain<void>());
    },
  );

  test(
    'a deadline stops descendants before the fixture can be deleted',
    () async {
      final fixture = Directory.systemTemp.createTempSync('dw-process-');
      final childPid = File(p.join(fixture.path, 'child-pid'));
      addTearDown(() async {
        if (childPid.existsSync()) {
          Process.killPid(
            int.parse(childPid.readAsStringSync()),
            ProcessSignal.sigkill,
          );
        }
        await fixture.delete(recursive: true);
      });

      final running = runTestProcess(
        '/bin/bash',
        [
          '-c',
          r'''sleep 600 &
child=$!
echo "$child" > child-pid
trap 'kill "$child" 2>/dev/null; wait "$child"; exit' TERM
wait "$child"
''',
        ],
        workingDirectory: fixture.path,
        timeout: const Duration(seconds: 2),
      );
      await expectLater(running, throwsA(isA<TimeoutException>()));
      expect(
        childPid.existsSync(),
        isTrue,
        reason: 'the child reached the fixture',
      );
      final child = int.parse(childPid.readAsStringSync());
      expect(
        Process.killPid(child, ProcessSignal.sigcont),
        isFalse,
        reason: 'the timed-out subprocess must not outlive fixture teardown',
      );
    },
  );
}
