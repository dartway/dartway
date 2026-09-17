import 'dart:io';

import 'package:args/args.dart';

import '../checker/dw_check_type.dart';
import '../deploy/deploy_check.dart';
import '../deploy/deploy_progress.dart';
import '../deploy/deploy_runner.dart';
import '../deploy/outside_probe.dart';
import '../deploy/remote_steps.dart';
import '../deploy/ssh_runner.dart';
import '../deploy/stack.dart';

/// Runs a deployment against an already-provisioned server.
///
/// Lives beside the command rather than inside it so the orchestration reads
/// top to bottom without the argument plumbing in the way.
Future<int> runDeploy(DwStack stack, ArgResults results) async {
  final projectRoot = Directory.current;
  final target = stack.target;
  final environment = target.environment;
  final progress = results.option('progress') == 'json'
      ? DwDeployProgress.json()
      : DwDeployProgress.text();
  final out = progress.human;
  final resume = results.flag('resume');

  int finish(int code, {String? failedStep, String? reason}) {
    progress.event('run_finished', {
      'ok': code == 0,
      'exit_code': code,
      'failed_step': ?failedStep,
      'reason': ?reason,
    });
    return code;
  }

  final sshUser = results.option('as') ?? target.sshUser;
  final ssh = DwSshRunner(
    host: target.host,
    user: sshUser,
    identityFile: results.option('identity'),
  );
  final remote = DwRemoteSteps(
    ssh: ssh,
    deployUser: target.deployUser,
    directory: DwDeployRunner.remoteDirectoryOf(target),
    onNotice: (notice) {
      out.writeln(notice);
      progress.event('notice', {'message': notice});
    },
  );
  final runner = DwDeployRunner(ssh: ssh, stack: stack, remote: remote);
  var steps = runner.steps(skipGitUpdate: results.flag('skip-git-update'));

  out
    ..writeln('Deploy [$environment]${resume ? ' — resuming' : ''}')
    ..writeln(
      '  server:  $sshUser@${target.host}, runs as ${target.deployUser}',
    )
    ..writeln('  branch:  ${target.branch}')
    ..writeln('  dir:     ${target.appDir}');

  // The working-copy checks are cheap and catch the mismatches that otherwise
  // surface as a half-deployed server.
  final context = DwDeployContext(
    projectRoot: projectRoot,
    stack: stack,
    ssh: ssh,
  );
  var blocking = 0;
  for (final check in dwLocalDeployChecks.where((c) => c.partOfDeploy)) {
    final verdict = await check.evaluate(context);
    if (verdict.passed || verdict.skipped) {
      continue;
    }
    if (check.severity == DwCheckSeverity.error) {
      blocking++;
      progress.problems.writeln('  FAIL  ${check.title} — ${verdict.detail}');
    } else {
      out.writeln('  warn  ${check.title} — ${verdict.detail}');
    }
  }
  if (blocking > 0) {
    progress.problems.writeln(
      'Refusing to deploy: $blocking blocking issue(s). '
      'Run "dartway deploy check --env $environment --local" for the detail.',
    );
    return finish(1, reason: 'checks');
  }

  if (results.flag('dry-run')) {
    out.writeln('\nPlan:');
    for (var index = 0; index < steps.length; index++) {
      out.writeln('  ${index + 1}. ${steps[index].title}');
    }
    out.writeln('  ${steps.length + 1}. Verify from outside:');
    for (final probe in _describeProbes(stack)) {
      out.writeln('       $probe');
    }
    out.writeln('\nDry run — nothing executed.');
    progress.event('plan', {'steps': _stepList(steps)});
    return finish(0);
  }

  Map<String, DwRemoteStepRecord>? record;
  if (resume) {
    try {
      record = await remote.read();
    } on StateError catch (error) {
      progress.problems.writeln(error.message);
      return finish(1, reason: 'unreachable');
    }
    if (record == null) {
      progress.problems.writeln(
        'Nothing to resume: the server keeps no record of a deployment. '
        'Run without --resume.',
      );
      return finish(1, reason: 'nothing-to-resume');
    }
    // The plan of the run being resumed, not a new one: a checkout update
    // slipped in front of steps that already ran would deploy code they
    // never saw.
    final planned = record.keys.toList();
    steps = [for (final id in planned) ...steps.where((step) => step.id == id)];
  }

  progress.event('run_started', {
    'environment': environment,
    'resume': resume,
    'steps': _stepList(steps),
  });

  Future<void> reportRevision() async {
    final revision = await runner.deployedRevision();
    final lines = revision.stdout.trim().split('\n');
    if (!revision.ok || lines.length < 2) return;
    out.writeln('  now at ${lines[1].trim()}');
    progress.event('revision', {
      'commit': lines.first.trim(),
      'subject': lines[1].trim().split(' ').skip(1).join(' '),
    });
  }

  final updates = steps.any(
    (step) =>
        step.id == 'update-checkout' && !(record?[step.id]?.succeeded ?? false),
  );
  if (!updates) await reportRevision();

  final failedStep = await executeDeploySteps(
    steps,
    remote: remote,
    resumeFrom: record,
    retryFailed: results.flag('retry-failed'),
    progress: progress,
    onUpdated: reportRevision,
  );
  if (failedStep != null) {
    return finish(1, failedStep: failedStep);
  }

  out.writeln('\nServices');
  final status = await runner.status();
  final services = <Map<String, String>>[];
  for (final line in status.stdout.split('\n')) {
    if (line.trim().isEmpty) continue;
    out.writeln('  ${line.trim()}');
    final [name, ...rest] = line.trim().split('\t');
    services.add({'name': name, 'status': rest.join(' ')});
  }
  progress.event('services', {'services': services});

  final code = reportOutsideVerification(
    await runner.verifyFromOutside(),
    progress: progress,
  );
  return finish(code, reason: code == 0 ? null : 'verification');
}

List<Map<String, String>> _stepList(List<DwDeployStep> steps) => [
  for (final step in steps) {'id': step.id, 'title': step.title},
];

/// Runs [steps] in order and reports each. Answers the id of the step that
/// failed, or null when all of them did their work.
///
/// With [remote], each step runs detached on the server and a new run starts
/// a new record there. With [resumeFrom] — that record, read back — the steps
/// it shows done are passed over, a step still running or finished unjudged is
/// waited for instead of started again, and from the first step that actually
/// runs everything after it runs too. A step that ended badly stops the
/// resume with its own reason unless [retryFailed] says to run it again.
Future<String?> executeDeploySteps(
  List<DwDeployStep> steps, {
  Future<void> Function()? onUpdated,
  DwRemoteSteps? remote,
  Map<String, DwRemoteStepRecord>? resumeFrom,
  bool retryFailed = false,
  DwDeployProgress? progress,
}) async {
  final report = progress ?? DwDeployProgress.text();
  final out = report.human;
  if (remote != null && resumeFrom == null) {
    remote.beginFresh([for (final step in steps) step.id]);
  }
  var passingOver = resumeFrom != null;
  for (var index = 0; index < steps.length; index++) {
    final step = steps[index];
    final position = {'index': index + 1, 'count': steps.length, 'id': step.id};
    final previous = passingOver ? resumeFrom![step.id] : null;
    if (previous != null && previous.succeeded && step.verdict == null) {
      out.writeln(
        '\n[${index + 1}/${steps.length}] ${step.title} — done by the run '
        'being resumed',
      );
      report.event('step_skipped', position);
      continue;
    }
    passingOver = false;
    // A step the run being resumed ended badly is not tried again by itself:
    // a self-deploy resumes after every interruption, and a failing step
    // would be repeated until the attempts ran out, each time stopping the
    // server it just started again. The reason is read from the server and
    // reported; `--retry-failed` is how a person says to run it once more.
    final failedBefore =
        remote != null &&
        previous != null &&
        !retryFailed &&
        (previous.state == DwRemoteStepState.rejected ||
            (previous.state == DwRemoteStepState.exited &&
                !previous.succeeded));
    if (failedBefore) {
      final recorded = await remote.collect(step.id);
      out.writeln(
        '\n[${index + 1}/${steps.length}] ${step.title} — failed in the run '
        'being resumed',
      );
      report.problems.writeln(
        'Step "${step.id}" failed before this resume '
        '(${previous.state == DwRemoteStepState.rejected ? 'its work was refused' : 'exit ${previous.exitCode}'}); '
        'fix what it reports, or run again with --retry-failed to repeat it.',
      );
      _indent(report.problems, '${recorded.stdout}\n${recorded.stderr}');
      report.event('step_failed', {
        ...position,
        'reason': previous.state == DwRemoteStepState.rejected
            ? 'verdict'
            : 'exit',
        'exit_code': ?previous.exitCode,
        'resumed': true,
        'stdout': recorded.stdout,
        'stderr': recorded.stderr,
      });
      return step.id;
    }
    // Finished but not judged yet, or still going: its result is on the
    // server already, and running it again would do the work twice.
    final pickUp =
        remote != null &&
        previous != null &&
        (previous.state == DwRemoteStepState.running || previous.succeeded);

    out.writeln(
      '\n[${index + 1}/${steps.length}] ${step.title}'
      '${pickUp ? ' — picking up the step already on the server' : ''}',
    );
    report.event('step_started', {
      ...position,
      'title': step.title,
      'picked_up': pickUp,
    });

    final DwSshResult result;
    try {
      result = pickUp ? await remote.collect(step.id) : await step.run();
    } on DwDeployBusy catch (busy) {
      report.problems.writeln(busy);
      report.event('step_failed', {
        ...position,
        'reason': 'busy',
        'message': busy.toString(),
      });
      return step.id;
    }

    // A step that declares it prints its own output prints it whatever
    // happened: "only on failure" is how a step that reports its outcome in
    // text comes out green and blank.
    if (step.showOutput) {
      _indent(out, '${result.stdout}\n${result.stderr}');
    }

    if (!result.ok) {
      report.problems.writeln(
        'Step "${step.id}" failed (exit ${result.exitCode}).',
      );
      if (!step.showOutput) {
        _indent(report.problems, '${result.stdout}\n${result.stderr}');
      }
      report.event('step_failed', {
        ...position,
        'reason': 'exit',
        'exit_code': result.exitCode,
        'stdout': result.stdout,
        'stderr': result.stderr,
      });
      return step.id;
    }

    final verdict = step.verdict?.call(result);
    if (verdict != null) {
      await remote?.reject(step.id);
      report.problems
        ..writeln('Step "${step.id}" exited 0 and did not do its work:')
        ..writeln(verdict);
      report.event('step_failed', {
        ...position,
        'reason': 'verdict',
        'exit_code': 0,
        'message': verdict,
      });
      return step.id;
    }
    report.event('step_finished', {
      ...position,
      'exit_code': 0,
      if (step.showOutput) ...{
        'stdout': result.stdout,
        'stderr': result.stderr,
      },
    });
    if (step.id == 'update-checkout') {
      await onUpdated?.call();
    }
    // Says nothing on a server whose bridge is already in place.
    if (step.id == 'bridge-override' && result.stdout.trim().isNotEmpty) {
      out.writeln('  ${result.stdout.trim()}');
    }
  }
  return null;
}

/// Prints the outside verification and answers the exit code.
int reportOutsideVerification(
  List<DwProbeResult> results, {
  DwDeployProgress? progress,
}) {
  final report = progress ?? DwDeployProgress.text();
  report.human.writeln('\nVerify from outside');
  for (final result in results) {
    report.human.writeln('  $result');
    report.event('probe', {
      'title': result.title,
      'passed': result.passed,
      'detail': result.detail,
    });
  }
  final failed = results.where((result) => !result.passed).length;
  if (failed > 0) {
    report.problems.writeln(
      '\nDeployed, but $failed answer(s) are not what a browser or an app '
      'needs. Each line above says what was observed.',
    );
    return 1;
  }
  report.human.writeln('\nDeployment completed.');
  return 0;
}

List<String> _describeProbes(DwStack stack) => [
  'GET ${stack.apiOrigin}/health and ${stack.appOrigin}/health — 200 "ok"',
  'GET ${stack.appOrigin}/ — the Flutter index.html, revalidated',
  'cache policy of the web build entry points',
  'upgrade ${stack.apiOrigin}/dw/live and ${stack.appOrigin}/dw/live — 101',
  if (stack.siteOrigin case final site?) 'GET $site/ — the site',
  if (stack.storageOrigin case final storage?) ...[
    'preflight PUT $storage/${stack.privateBucketName}/… from ${stack.appOrigin}',
    'GET $storage/{${stack.publicBucketName},${stack.privateBucketName}}/'
        '${DwStack.visibilityProbeKey} without credentials — public 200, '
        'private refused, neither listed',
  ],
];

/// Writes [text] under the step that produced it, one indented line at a time,
/// dropping the blank ones.
void _indent(IOSink sink, String text) {
  for (final line in text.split('\n')) {
    final trimmed = line.trimRight();
    if (trimmed.isEmpty) {
      continue;
    }
    sink.writeln('  $trimmed');
  }
}
