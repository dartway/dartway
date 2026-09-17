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
