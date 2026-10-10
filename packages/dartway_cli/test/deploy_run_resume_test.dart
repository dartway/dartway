import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dartway_cli/src/commands/deploy_run.dart';
import 'package:dartway_cli/src/deploy/deploy_progress.dart';
import 'package:dartway_cli/src/deploy/deploy_runner.dart';
import 'package:dartway_cli/src/deploy/remote_steps.dart';
import 'package:dartway_cli/src/deploy/ssh_runner.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'support/deploy_fixtures.dart';

void main() {
  late Directory temp;
  late DwRemoteSteps remote;
  late _Captured human;
  late _Captured events;
  late DwDeployProgress progress;

  setUp(() {
    temp = Directory.systemTemp.createTempSync('dw_deploy_resume_');
    remote = DwRemoteSteps(
      ssh: LocalShell(),
      deployUser: 'deployer',
      directory: p.join(temp.path, 'deploy-run'),
      pollInterval: const Duration(milliseconds: 50),
    );
    human = _Captured();
    events = _Captured();
    progress = DwDeployProgress.into(human: human.sink, events: events.sink);
  });
  tearDown(() => temp.deleteSync(recursive: true));

  /// A step that appends its id to `ran` on the server, then runs [script].
  DwDeployStep step(
    String id, {
    String script = '',
    String? Function(DwSshResult)? verdict,
  }) => DwDeployStep(
    id: id,
    title: 'Step $id',
    verdict: verdict,
    run: () =>
        remote.run(id, "echo $id >> '${p.join(temp.path, 'ran')}'\n$script\n"),
  );

  List<String> ran() {
    final file = File(p.join(temp.path, 'ran'));
    return file.existsSync() ? file.readAsLinesSync() : [];
  }

  Future<String?> execute(
    List<DwDeployStep> steps, {
    bool resume = false,
    bool retryFailed = false,
  }) async => executeDeploySteps(
    steps,
    remote: remote,
    resumeFrom: resume ? await remote.read() : null,
    retryFailed: retryFailed,
    progress: progress,
  );

  for (final retryFailed in [false, true]) {
    test('resume retries diskFull (retry-failed=$retryFailed)', () async {
      final dir = Directory(remote.directory)..createSync();
      File('${dir.path}/plan').writeAsStringSync('build\n');
      File('${dir.path}/build.pid').writeAsStringSync('99999999\n');
      File('${dir.path}/build.exit.tmp').writeAsStringSync('');
      expect(
        (await remote.read())!['build']!.state,
        DwRemoteStepState.diskFull,
      );
      expect(
        await execute(
          [step('build', script: 'true')],
          resume: true,
          retryFailed: retryFailed,
        ),
        isNull,
      );
      expect(ran(), ['build']);
      expect(File('${dir.path}/build.exit.tmp').existsSync(), isFalse);
    });
  }

  for (final resume in [false, true]) {
    test(
      'failed output is masked in prose and events (resume=$resume)',
      () async {
        const secret = r'pass.*[]\/&$word';
        final encoded = Uri.encodeComponent(secret);
        File(
          p.join(temp.path, 'secrets.env'),
        ).writeAsStringSync("TOKEN='$secret'\n");
        final plan = [
          step(
            'leaks',
            script:
                "printf '%s\\n' 'before $secret after' 'url=$encoded'\n"
                "printf '%s' 'error $secret url=$encoded end' >&2\nexit 7",
          ),
        ];
        if (resume) {
          remote.beginFresh(['leaks']);
          await plan.single.run();
        }
        expect(await execute(plan, resume: resume), 'leaks');
        await human.settle();
        await events.settle();
        final failed = events.lines
            .map((line) => jsonDecode(line) as Map<String, Object?>)
            .singleWhere((event) => event['event'] == 'step_failed');
        expect(failed['stdout'], 'before *** after\nurl=***\n');
        expect(failed['stderr'], 'error *** url=*** end');
        expect(human.lines.join('\n'), contains('before *** after'));
        for (final output in [
          human.lines.join('\n'),
          events.lines.join('\n'),
        ]) {
          expect(output, isNot(contains(secret)));
          expect(output, isNot(contains(encoded)));
        }
      },
    );
  }

  test('successful step output is masked in prose and step_finished', () async {
    File(
      p.join(temp.path, 'secrets.env'),
    ).writeAsStringSync("TOKEN='stored-secret'\n");
    final plan = [
      DwDeployStep(
        id: 'prints',
        title: 'Print output',
        showOutput: true,
        run: () => remote.run('prints', "echo 'before stored-secret after'"),
      ),
    ];
    expect(await execute(plan), isNull);
    await human.settle();
    await events.settle();
    final finished = events.lines
        .map((line) => jsonDecode(line) as Map<String, Object?>)
        .singleWhere((event) => event['event'] == 'step_finished');
    expect(finished['stdout'], 'before *** after\n');
    expect(human.text, contains('before *** after'));
    expect(events.text, isNot(contains('stored-secret')));
  });

  test(
    'a resumed deployment runs only what the first one did not finish',
    () async {
      var failing = true;
      List<DwDeployStep> plan() => [
        step('a'),
        step('b', script: failing ? 'exit 4' : 'true'),
        step('c'),
      ];
      expect(await execute(plan()), 'b');
      failing = false;

      expect(await execute(plan(), resume: true, retryFailed: true), isNull);
      expect(ran(), ['a', 'b', 'b', 'c']);
    },
  );

  test(
    'a step still running on the server is waited for, not started again',
    () async {
      final steps = [step('a'), step('slow', script: 'sleep 1'), step('c')];
      remote.beginFresh(['a', 'slow', 'c']);
      await steps[0].run();
      // The invoker went away while this step ran: nothing waits for it.
      unawaited(steps[1].run());
      await Future<void>.delayed(const Duration(milliseconds: 400));

      expect(await execute(steps, resume: true), isNull);
      expect(ran(), ['a', 'slow', 'c']);
      final started = events.lines
          .map((line) => jsonDecode(line) as Map<String, Object?>)
          .where((event) => event['event'] == 'step_started')
          .toList();
      expect(started.map((event) => event['id']), ['slow', 'c']);
      expect(started.first['picked_up'], isTrue);
    },
  );

  test('a step with a verdict is judged again from its output, and a rejected '
      'one runs again', () async {
    final steps = [step('a', script: 'echo half', verdict: (_) => 'half')];
    expect(await execute(steps), 'a');
    expect((await remote.read())!['a']!.state, DwRemoteStepState.rejected);

    final judged = [
      step(
        'a',
        script: 'echo whole',
        verdict: (r) => r.stdout.contains('whole') ? null : 'half',
      ),
    ];
    expect(await execute(judged, resume: true, retryFailed: true), isNull);
    expect(ran(), ['a', 'a']);
  });

  test('once a step runs, every step after it runs too', () async {
    remote.beginFresh(['a', 'b', 'c']);
    await step('a').run();
    await step('b', script: 'exit 1').run();
    await step('c').run();

    expect(
      await execute(
        [step('a'), step('b'), step('c')],
        resume: true,
        retryFailed: true,
      ),
      isNull,
    );
    expect(ran(), ['a', 'b', 'c', 'b', 'c']);
  });

  test(
    'a matching recorded checkout is skipped after its HEAD was verified',
    () async {
      final checkout = step('update-checkout', verdict: (_) => 'old output');
      remote.beginFresh(['update-checkout', 'after']);
      await checkout.run();

      expect(
        await executeDeploySteps(
          [checkout, step('after')],
          remote: remote,
          resumeFrom: await remote.read(),
          trustedSucceededStepIds: const {'update-checkout'},
          progress: progress,
        ),
        isNull,
      );
      expect(ran(), ['update-checkout', 'after']);
    },
  );

  test('a recorded failed checkout runs again with the pinned plan', () async {
    final failed = step('update-checkout', script: 'exit 1');
    remote.beginFresh(['update-checkout', 'after']);
    await failed.run();

    expect(
      await executeDeploySteps(
        [step('update-checkout'), step('after')],
        remote: remote,
        resumeFrom: await remote.read(),
        retryFailedStepIds: const {'update-checkout'},
        progress: progress,
      ),
      isNull,
    );
    expect(ran(), ['update-checkout', 'update-checkout', 'after']);
  });

  for (final throws in [false, true]) {
    test(
      'cleanup ${throws ? 'exception' : 'invalid summary'} closes its progress step at deploy success',
      () async {
        final cleanup = DwDeployStep(
          id: 'cleanup',
          title: 'Cleanup',
          run: () async {
            if (throws) throw StateError('SSH disconnected');
            return const DwSshResult(
              exitCode: 0,
              stdout: 'invalid',
              stderr: '',
            );
          },
        );
        expect(await execute([cleanup]), isNull);
        await events.settle();
        final decoded = events.lines
            .map((line) => jsonDecode(line) as Map<String, Object?>)
            .toList();
        final terminal = decoded.singleWhere(
          (event) =>
              event['event'] == (throws ? 'step_failed' : 'step_finished'),
        );
        expect(terminal['id'], 'cleanup');
        if (throws) {
          expect(terminal['reason'], 'exception');
          expect(terminal['message'], contains('SSH disconnected'));
        } else {
          expect(terminal['exit_code'], 0);
        }
        expect(
          decoded.singleWhere(
            (event) => event['event'] == 'cleanup',
          )['warning'],
          isTrue,
        );
      },
    );
  }

  test('the events name every step, its position and its end', () async {
    final steps = [step('a'), step('b', script: 'echo bad >&2; exit 2')];
    expect(await execute(steps), 'b');
    await events.settle();
    await human.settle();
    final decoded = [
      for (final line in events.lines) jsonDecode(line) as Map<String, Object?>,
    ];
    expect(decoded.map((event) => event['event']), [
      'step_started',
      'step_finished',
      'step_started',
      'step_failed',
    ]);
    expect(decoded[2], containsPair('index', 2));
    expect(decoded[2], containsPair('count', 2));
    expect(decoded[3], containsPair('exit_code', 2));
    expect(decoded[3], containsPair('stderr', 'bad\n'));
    expect(human.text, contains('[2/2] Step b'));
  });
}

class _Captured {
  _Captured() {
    sink = IOSink(_controller.sink);
    _controller.stream.listen(_bytes.addAll);
  }

  final _controller = StreamController<List<int>>();
  final _bytes = <int>[];
  late final IOSink sink;

  /// Lets what was written reach the buffer.
  Future<void> settle() async {
    await sink.flush();
    await Future<void>.delayed(Duration.zero);
  }

  String get text => utf8.decode(_bytes);
  List<String> get lines =>
      text.split('\n').where((line) => line.isNotEmpty).toList();
}
