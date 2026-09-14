import 'dart:io';

import 'package:args/args.dart';

import '../checker/dw_check_type.dart';
import '../deploy/deploy_check.dart';
import '../deploy/deploy_runner.dart';
import '../deploy/outside_probe.dart';
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

  final sshUser = results.option('as') ?? target.sshUser;
  final ssh = DwSshRunner(
    host: target.host,
    user: sshUser,
    identityFile: results.option('identity'),
  );
  final runner = DwDeployRunner(ssh: ssh, stack: stack);
  final steps = runner.steps(skipGitUpdate: results.flag('skip-git-update'));

  stdout
    ..writeln('Deploy [$environment]')
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
      stderr.writeln('  FAIL  ${check.title} — ${verdict.detail}');
    } else {
      stdout.writeln('  warn  ${check.title} — ${verdict.detail}');
    }
  }
  if (blocking > 0) {
    stderr.writeln(
      'Refusing to deploy: $blocking blocking issue(s). '
      'Run "dartway deploy check --env $environment --local" for the detail.',
    );
    return 1;
  }

  if (results.flag('dry-run')) {
    stdout.writeln('\nPlan:');
    for (var index = 0; index < steps.length; index++) {
      stdout.writeln('  ${index + 1}. ${steps[index].title}');
    }
    stdout.writeln('  ${steps.length + 1}. Verify from outside:');
    for (final probe in _describeProbes(stack)) {
      stdout.writeln('       $probe');
    }
    stdout.writeln('\nDry run — nothing executed.');
    return 0;
  }

  final failedStep = await executeDeploySteps(
    steps,
    onUpdated: () async {
      final revision = await runner.deployedRevision();
      if (revision.ok) stdout.writeln('  now at ${revision.firstLine}');
    },
  );
  if (failedStep != null) {
    return 1;
  }

  stdout.writeln('\nServices');
  final status = await runner.status();
  for (final line in status.stdout.split('\n')) {
    if (line.trim().isNotEmpty) {
      stdout.writeln('  ${line.trim()}');
    }
  }

  return reportOutsideVerification(await runner.verifyFromOutside());
}

/// Runs [steps] in order and reports each. Answers the id of the step that
/// failed, or null when all of them did their work.
Future<String?> executeDeploySteps(
  List<DwDeployStep> steps, {
  Future<void> Function()? onUpdated,
}) async {
  for (var index = 0; index < steps.length; index++) {
    final step = steps[index];
    stdout.writeln('\n[${index + 1}/${steps.length}] ${step.title}');
    final result = await step.run();

    // A step that declares it prints its own output prints it whatever
    // happened: "only on failure" is how a step that reports its outcome in
    // text comes out green and blank.
    if (step.showOutput) {
      _indent(stdout, '${result.stdout}\n${result.stderr}');
    }

    if (!result.ok) {
      stderr.writeln('Step "${step.id}" failed (exit ${result.exitCode}).');
      if (!step.showOutput) {
        _indent(stderr, '${result.stdout}\n${result.stderr}');
      }
      return step.id;
    }

    final verdict = step.verdict?.call(result);
    if (verdict != null) {
      stderr
        ..writeln('Step "${step.id}" exited 0 and did not do its work:')
        ..writeln(verdict);
      return step.id;
    }
    if (step.id == 'update-checkout') {
      await onUpdated?.call();
    }
    // Says nothing on a server whose bridge is already in place.
    if (step.id == 'bridge-override' && result.stdout.trim().isNotEmpty) {
      stdout.writeln('  ${result.stdout.trim()}');
    }
  }
  return null;
}

/// Prints the outside verification and answers the exit code.
int reportOutsideVerification(List<DwProbeResult> results) {
  stdout.writeln('\nVerify from outside');
  for (final result in results) {
    stdout.writeln('  $result');
  }
  final failed = results.where((result) => !result.passed).length;
  if (failed > 0) {
    stderr.writeln(
      '\nDeployed, but $failed answer(s) are not what a browser or an app '
      'needs. Each line above says what was observed.',
    );
    return 1;
  }
  stdout.writeln('\nDeployment completed.');
  return 0;
}

List<String> _describeProbes(DwStack stack) => [
  'GET ${stack.apiOrigin}/health and ${stack.appOrigin}/health — 200 "ok"',
  'GET ${stack.appOrigin}/ — the Flutter index.html, revalidated',
  'cache policy of the web build entry points',
  'upgrade ${stack.apiOrigin}/dw/live and ${stack.appOrigin}/dw/live — 101',
  if (stack.siteOrigin case final site?) 'GET $site/ — the site',
  if (stack.storageOrigin case final storage?)
    'preflight PUT $storage/${stack.bucketName}/… from ${stack.appOrigin}',
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
