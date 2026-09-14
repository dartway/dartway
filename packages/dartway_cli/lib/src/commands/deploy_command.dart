import 'dart:io';

import 'package:args/args.dart';
import 'package:args/command_runner.dart';

import '../checker/dw_check_type.dart';
import '../deploy/deploy_check.dart';
import '../deploy/deploy_target.dart';
import '../deploy/remote_checks.dart';
import '../deploy/ssh_runner.dart';
import '../deploy/stack.dart';
import '../project_layout.dart';
import 'deploy_run.dart';
import 'deploy_setup.dart';
import 'secret_commands.dart';

/// Deployment commands.
class DeployCommand extends Command<int> {
  DeployCommand() {
    addSubcommand(DeploySetupCommand());
    addSubcommand(DeployRunCommand());
    addSubcommand(DeployCheckCommand());
    addSubcommand(SecretCommand());
  }

  @override
  String get name => 'deploy';

  @override
  String get description => 'Deploy the project to a configured server.';
}

/// The environment named by `--env`, read and validated, with the project's
/// packages found by suffix.
DwStack resolveDeployStack(
  Command<int> command,
  ArgResults results,
  Directory projectRoot,
) {
  final environment = results.option('env');
  if (environment == null) {
    final known = DwDeployTarget.environmentsIn(projectRoot);
    command.usageException(
      'Specify --env.'
      '${known.isEmpty ? '' : ' Declared in deploy/config.yaml: ${known.join(', ')}.'}',
    );
  }
  final layout = ProjectLayout.detect(projectRoot);
  return DwStack(
    target: DwDeployTarget.load(
      projectRoot: projectRoot,
      environment: environment,
    ),
    serverPackage: layout.serverPackage,
    flutterPackage: layout.flutterPackage,
  );
}

/// Provisions a server and renders the infrastructure it runs on.
class DeploySetupCommand extends Command<int> {
  DeploySetupCommand() {
    argParser
      ..addOption('env', help: 'Environment declared in deploy/config.yaml.')
      ..addOption(
        'as',
        help: 'SSH login. Defaults to ssh_user from the config.',
      )
      ..addOption('identity', help: 'SSH private key file.')
      ..addFlag(
        'dry-run',
        negatable: false,
        help: 'Print the rendered files and change nothing.',
      );
  }

  @override
  String get name => 'setup';

  @override
  String get description =>
      'Provision the server and render its Compose and Nginx configuration.';

  @override
  String get invocation =>
      'dartway deploy setup --env <environment> [--dry-run]';

  @override
  Future<int> run() => runSetup(
    resolveDeployStack(this, argResults!, Directory.current),
    argResults!,
  );
}

/// Deploys to an already-provisioned server.
class DeployRunCommand extends Command<int> {
  DeployRunCommand() {
    argParser
      ..addOption('env', help: 'Environment declared in deploy/config.yaml.')
      ..addOption(
        'as',
        help: 'SSH login. Defaults to ssh_user from the config.',
      )
      ..addOption('identity', help: 'SSH private key file.')
      ..addFlag(
        'skip-git-update',
        negatable: false,
        help: 'Deploy what is already checked out on the server.',
      )
      ..addFlag(
        'dry-run',
        negatable: false,
        help: 'Print the plan and change nothing.',
      );
  }

  @override
  String get name => 'run';

  @override
  String get description =>
      'Update, build, start the server (it migrates on start), the web app and '
      'the proxy, then verify from outside.';

  @override
  String get invocation =>
      'dartway deploy run --env <environment> [--dry-run] [--skip-git-update]';

  @override
  Future<int> run() => runDeploy(
    resolveDeployStack(this, argResults!, Directory.current),
    argResults!,
  );
}

/// Validates that the project is deployable to the given environment.
class DeployCheckCommand extends Command<int> {
  DeployCheckCommand() {
    argParser
      ..addOption('env', help: 'Environment declared in deploy/config.yaml.')
      ..addFlag(
        'local',
        negatable: false,
        help: 'Skip DNS, the server and the site; check the working copy only.',
      )
      ..addOption(
        'as',
        help: 'SSH login to connect as. Defaults to ssh_user from the config.',
      )
      ..addOption(
        'identity',
        help: 'SSH private key file to authenticate with.',
      );
  }

  @override
  String get name => 'check';

  @override
  String get description =>
      'Verify the deployment configuration without changing anything.';

  @override
  String get invocation =>
      'dartway deploy check --env <environment> [--local] [--as <user>] '
      '[--identity <key>]';

  @override
  Future<int> run() async {
    final projectRoot = Directory.current;
    final results = argResults!;
    final stack = resolveDeployStack(this, results, projectRoot);
    final target = stack.target;

    final offline = results.flag('local');
    final sshUser = results.option('as') ?? target.sshUser;
    final context = DwDeployContext(
      projectRoot: projectRoot,
      stack: stack,
      ssh: offline
          ? null
          : DwSshRunner(
              host: target.host,
              user: sshUser,
              identityFile: results.option('identity'),
            ),
    );

    stdout
      ..writeln('Deploy check [${target.environment}]')
      ..writeln('  server:    $sshUser@${target.host}')
      ..writeln('  runs as:   ${target.deployUser}')
      ..writeln('  repo:      ${target.repo} [${target.branch}]')
      ..writeln('  packages:  ${stack.serverPackage}, ${stack.flutterPackage}')
      ..writeln('  api:       ${stack.apiOrigin}')
      ..writeln('  app:       ${stack.appOrigin}');
    if (target.site case final site?) {
      stdout.writeln(
        '  site:      ${site.deployed ? '${stack.siteOrigin} from ${site.source}/' : '${site.domain} (external, not deployed)'}',
      );
    }
    stdout.writeln(
      '  storage:   ${switch (target.storage) {
        DwStorageMode.none => 'none',
        DwStorageMode.minio => 'MinIO on ${stack.storageOrigin}, buckets ${stack.publicBucketName} (public) and ${stack.privateBucketName} (private)',
        DwStorageMode.external => 'external (DW_STORAGE_* in the secret store)',
      }}',
    );

    final tally = _Tally();

    stdout.writeln('\nWorking copy');
    for (final check in dwLocalDeployChecks) {
      _report(check, await check.evaluate(context), tally);
    }

    if (offline) {
      stdout.writeln('\nDNS, server and site checks skipped (--local).');
    } else {
      stdout.writeln('\nDNS, server and site');
      var sshUsable = true;
      for (final check in dwRemoteDeployChecks) {
        if (check.requiresSsh && !sshUsable) {
          _report(
            check,
            const DwDeployVerdict.skip('server unreachable'),
            tally,
          );
          continue;
        }
        final verdict = await check.evaluate(context);
        if (check.id == 'ssh-reachable' && !verdict.passed) {
          sshUsable = false;
        }
        _report(check, verdict, tally);
      }
    }

    stdout
      ..writeln('')
      ..writeln(tally.summary);

    return tally.errors > 0 ? 1 : 0;
  }

  void _report(DwDeployCheck check, DwDeployVerdict verdict, _Tally tally) {
    if (verdict.passed) {
      stdout.writeln('  ok    ${check.title} — ${verdict.detail}');
      return;
    }
    if (verdict.skipped) {
      tally.skipped++;
      stdout.writeln('  skip  ${check.title} — ${verdict.detail}');
      return;
    }
    switch (check.severity) {
      case DwCheckSeverity.error:
        tally.errors++;
        stdout.writeln('  FAIL  ${check.title} [${check.id}]');
      case DwCheckSeverity.warning:
        tally.warnings++;
        stdout.writeln('  warn  ${check.title} [${check.id}]');
      case DwCheckSeverity.info:
        stdout.writeln('  info  ${check.title} [${check.id}]');
    }
    stdout.writeln('        ${verdict.detail}');
    if (verdict.fix != null) {
      stdout.writeln('        ${verdict.fix}');
    }
  }
}

class _Tally {
  int errors = 0;
  int warnings = 0;
  int skipped = 0;

  String get summary {
    if (errors > 0) {
      return '$errors error(s), $warnings warning(s), $skipped skipped.';
    }
    final notes = [
      if (warnings > 0) '$warnings warning(s)',
      if (skipped > 0) '$skipped skipped',
    ];
    return notes.isEmpty
        ? 'All checks passed.'
        : 'Checks passed with ${notes.join(' and ')}.';
  }
}
