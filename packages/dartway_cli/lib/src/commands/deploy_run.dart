import 'dart:io';

import 'package:args/args.dart';
import 'package:args/command_runner.dart';

import '../checker/dw_check_type.dart';
import '../deploy/deploy_check.dart';
import '../deploy/deploy_runner.dart';
import '../deploy/deploy_target.dart';
import '../deploy/serverpod_config.dart';
import '../deploy/ssh_runner.dart';
import '../project_layout.dart';

/// Runs a deployment against an already-provisioned server.
///
/// Lives beside the command rather than inside it so the orchestration reads
/// top to bottom without the argument plumbing in the way.
Future<int> runDeploy(Command<int> command, ArgResults results) async {
  final projectRoot = Directory.current;
  final environment = results.option('env');
  if (environment == null) {
    final known = DwDeployTarget.environmentsIn(projectRoot);
    command.usageException(
      'Specify --env.'
      '${known.isEmpty ? '' : ' Declared: ${known.join(', ')}.'}',
    );
  }

  final layout = ProjectLayout.detect(projectRoot);
  final target = DwDeployTarget.load(
    projectRoot: projectRoot,
    environment: environment,
  );
  final serverpod = DwServerpodConfig.load(
    projectRoot: projectRoot,
    serverPackage: layout.serverPackage,
    environment: environment,
  );

  final sshUser = results.option('as') ?? target.sshUser;
  final ssh = DwSshRunner(
    host: target.host,
    user: sshUser,
    identityFile: results.option('identity'),
  );
  final runner = DwDeployRunner(
    ssh: ssh,
    target: target,
    serverpod: serverpod,
    stdout: stdout,
  );

  final dryRun = results.flag('dry-run');
  final steps = runner.steps(skipGitUpdate: results.flag('skip-git-update'));

  stdout
    ..writeln('Deploy [$environment]')
    ..writeln(
      '  server:  $sshUser@${target.host}, runs as ${target.deployUser}',
    )
    ..writeln('  branch:  ${target.branch}')
    ..writeln('  dir:     ${target.appDir}');

  // The working-copy checks are cheap and catch the mismatches that otherwise
  // surface as a half-deployed server. Server-side checks are skipped here:
  // the deployment itself is about to talk to the machine anyway.
  final context = DwDeployContext(
    projectRoot: projectRoot,
    serverPackage: layout.serverPackage,
    flutterPackage: layout.flutterPackage,
    target: target,
    serverpod: serverpod,
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
      'Run "dartway deploy check --env $environment" for the detail.',
    );
    return 1;
  }

  if (dryRun) {
    stdout.writeln('\nPlan:');
    for (var index = 0; index < steps.length; index++) {
      stdout.writeln('  ${index + 1}. ${steps[index].title}');
    }
    stdout
      ..writeln('  ${steps.length + 1}. Smoke:')
      ..writeAll(runner.smokeUrls.map((url) => '       $url\n'))
      ..writeln('\nDry run — nothing executed.');
    return 0;
  }

  for (var index = 0; index < steps.length; index++) {
    final step = steps[index];
    stdout.writeln('\n[${index + 1}/${steps.length}] ${step.title}');
    final result = await step.run();
    if (!result.ok) {
      stderr
        ..writeln('Step "${step.id}" failed:')
        ..writeln(result.stderr.trim().isEmpty ? result.stdout : result.stderr);
      return 1;
    }
    if (step.id == 'update-checkout') {
      final revision = await runner.deployedRevision();
      if (revision.ok) {
        stdout.writeln('  now at ${revision.firstLine}');
      }
    }
  }

  stdout.writeln('\nServices');
  final status = await runner.status();
  for (final line in status.stdout.split('\n')) {
    if (line.trim().isNotEmpty) {
      stdout.writeln('  ${line.trim()}');
    }
  }

  stdout.writeln('\nSmoke');
  var failed = 0;
  for (final url in runner.smokeUrls) {
    final ok = await runner.smoke(url);
    stdout.writeln('  ${ok ? 'ok  ' : 'FAIL'} $url');
    if (!ok) {
      failed++;
    }
  }

  if (failed > 0) {
    stderr.writeln(
      '\nDeployed, but $failed endpoint(s) did not answer. '
      'Check the logs on the server.',
    );
    return 1;
  }

  stdout.writeln('\nDeployment completed.');
  return 0;
}
