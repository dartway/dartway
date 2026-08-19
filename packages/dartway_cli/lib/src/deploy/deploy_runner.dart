import 'dart:io';

import 'compose_files.dart';
import 'deploy_target.dart';
import 'migration_report.dart';
import 'serverpod_config.dart';
import 'ssh_runner.dart';

/// One step of a deployment.
///
/// Steps are data so that the same list drives execution, a dry run and, later,
/// an exported instruction list.
class DwDeployStep {
  const DwDeployStep({
    required this.id,
    required this.title,
    required this.run,
    this.showOutput = false,
    this.verdict,
  });

  final String id;
  final String title;
  final Future<DwSshResult> Function() run;

  /// Whether the step's output belongs in the log even when it succeeded.
  ///
  /// Off for most steps — a deploy that reprints every `docker compose` line is
  /// a deploy nobody reads. On where the output *is* the result and the exit
  /// code is not.
  final bool showOutput;

  /// A second opinion on a step that exited 0: why it must fail anyway, or null
  /// when it is genuinely fine.
  ///
  /// An exit code is a claim about the process, not about the work. Where the
  /// two can disagree, the step says which text settles it.
  final String? Function(DwSshResult result)? verdict;
}

/// Deploys an already-provisioned server: update the checkout, rebuild, apply
/// migrations, restart.
///
/// Rendering `docker-compose.yml` and `nginx.conf` is deliberately not here —
/// that belongs to server bootstrap. A deploy that re-renders infrastructure
/// on every run turns a routine push into an infrastructure change.
class DwDeployRunner {
  DwDeployRunner({
    required this.ssh,
    required this.target,
    required this.serverpod,
    required this.stdout,
  });

  final DwSshRunner ssh;
  final DwDeployTarget target;
  final DwServerpodConfig serverpod;
  final Stdout stdout;

  String get _appDir => target.appDir;

  /// Every Compose call of a deployment goes through here, which is why the
  /// project's override can be named explicitly instead of copied to the
  /// server under the name Compose picks up on its own.
  String _compose(String arguments) =>
      DwComposeFiles.commandIn(_appDir, arguments);

  /// Moves aside the automatically loaded override copy older CLIs wrote.
  ///
  /// A server that has one merges it into every deploy, silently and forever,
  /// while the committed override it was copied from goes on being ignored.
  /// Idempotent, and a no-op on a server that never had the copy.
  Future<DwSshResult> retireOverrideCopy() =>
      ssh.runAs(target.deployUser, DwComposeFiles.retireLegacyCopyIn(_appDir));

  /// Brings the checkout to the tip of the deployment branch.
  ///
  /// `reset --hard` rather than `pull`: the server mirrors the repository, and
  /// a stray edit on the box must not be able to block a deploy. Ignored files
  /// — the runtime secrets among them — survive this.
  Future<DwSshResult> updateCheckout() => ssh.runAs(
    target.deployUser,
    "cd '$_appDir' && "
    "git fetch origin '${target.branch}' --prune && "
    "git checkout -B '${target.branch}' 'origin/${target.branch}' && "
    "git reset --hard 'origin/${target.branch}'",
  );

  Future<DwSshResult> deployedRevision() => ssh.runAs(
    target.deployUser,
    "cd '$_appDir' && git log -1 --format='%h %s'",
  );

  Future<DwSshResult> build() =>
      ssh.runAs(target.deployUser, _compose('build'));

  /// Applies pending migrations in a throwaway container.
  ///
  /// `</dev/null` is not decoration: without it `compose run -T` consumes the
  /// rest of the surrounding script from stdin and the following commands
  /// silently never run.
  ///
  /// Whether this did anything is read out of the output, not out of the exit
  /// code — see [DwMigrationReport].
  Future<DwSshResult> applyMigrations() {
    final entrypoint = target.serverEntrypoint;
    final override = entrypoint == null ? '' : "--entrypoint '$entrypoint' ";
    return ssh.runAs(
      target.deployUser,
      '${_compose('run --rm -T $override'
      'backend --mode=${target.environment} --server-id=default '
      '--logging=normal --role=maintenance --apply-migrations')} '
      '</dev/null',
    );
  }

  Future<DwSshResult> up() =>
      ssh.runAs(target.deployUser, _compose('up -d --remove-orphans'));

  /// Nginx resolves service names once at start; after the backend container
  /// is recreated its cached address points at a container that is gone.
  Future<DwSshResult> restartProxy() =>
      ssh.runAs(target.deployUser, _compose('restart nginx'));

  Future<DwSshResult> status() => ssh.runAs(
    target.deployUser,
    _compose("ps --format '{{.Name}}\t{{.Status}}'"),
  );

  List<DwDeployStep> steps({required bool skipGitUpdate}) => [
    DwDeployStep(
      id: 'retire-override-copy',
      title: 'Retire the setup-time compose override copy',
      run: retireOverrideCopy,
    ),
    if (!skipGitUpdate)
      DwDeployStep(
        id: 'update-checkout',
        title: 'Update the checkout to origin/${target.branch}',
        run: updateCheckout,
      ),
    DwDeployStep(id: 'build', title: 'Build images', run: build),
    DwDeployStep(
      id: 'migrate',
      title: 'Apply database migrations',
      run: applyMigrations,
      // The container's own account of what it did is the only account there
      // is: it exits 0 either way. Printing it unconditionally is half of that
      // — the other half is refusing to continue when it says the schema did
      // not move.
      showOutput: true,
      verdict: (result) =>
          DwMigrationReport.read('${result.stdout}\n${result.stderr}').failure,
    ),
    DwDeployStep(id: 'up', title: 'Start services', run: up),
    DwDeployStep(
      id: 'restart-proxy',
      title: 'Restart nginx',
      run: restartProxy,
    ),
  ];

  /// URLs a successful deployment must answer on.
  List<String> get smokeUrls => [
    for (final endpoint in serverpod.endpoints)
      if (endpoint.publicHost != null) 'https://${endpoint.publicHost}/',
    'https://${target.webAppDomain}/',
  ];

  /// Polls [url] until it answers or the attempts run out.
  Future<bool> smoke(String url, {int attempts = 18}) async {
    for (var attempt = 1; attempt <= attempts; attempt++) {
      try {
        final result = await Process.run('curl', [
          '--fail',
          '--silent',
          '--show-error',
          '--max-time',
          '15',
          '--output',
          Platform.isWindows ? 'NUL' : '/dev/null',
          url,
        ]);
        if (result.exitCode == 0) {
          return true;
        }
      } on ProcessException {
        return false;
      }
      await Future<void>.delayed(const Duration(seconds: 5));
    }
    return false;
  }
}
