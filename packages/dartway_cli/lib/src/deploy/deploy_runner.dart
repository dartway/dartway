import 'dart:io';

import 'compose_files.dart';
import 'deploy_target.dart';
import 'migration_report.dart';
import 'nginx_upstreams.dart';
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

  /// Keeps a hand-typed `docker compose` in the checkout honest.
  ///
  /// The CLI names the project override on every call of its own; nothing
  /// makes the command a person types do the same, and in a directory holding
  /// only the rendered file that command applies a strictly smaller stack
  /// without saying so. See [DwComposeFiles.bridgeIn].
  Future<DwSshResult> bridgeOverride() =>
      ssh.runAs(target.deployUser, DwComposeFiles.bridgeIn(_appDir));

  /// Marks the boundary between the two answers [checkUpstreams] collects.
  static const String _upstreamMarker = '--dw-nginx-d--';

  /// Asks the server what the stack actually holds and what nginx expects.
  ///
  /// On the server, not against the working copy: the checkout can be right
  /// while the invocation was not, and that is exactly the case that took a
  /// stand down — `deploy/compose.override.yml` was committed and present at
  /// the deployed revision, and the container stamps show it was never
  /// applied. The local check answers a different question and both are worth
  /// asking.
  Future<DwSshResult> checkUpstreams() => ssh.runAs(
    target.deployUser,
    "cd '$_appDir' && ${DwComposeFiles.selectFiles} && "
    '${DwComposeFiles.invoke} config --services && '
    "echo '$_upstreamMarker' && "
    "{ find nginx.d -name '*.conf' -exec cat {} + 2>/dev/null || true; }",
  );

  /// Why a stack that came up is still not fit to have its proxy restarted.
  ///
  /// Null when it is. Separate from [checkUpstreams] because the command
  /// exits 0 either way: it asks two questions, and the disagreement between
  /// the answers is the finding.
  static String? upstreamVerdict(DwSshResult result) {
    final parts = result.stdout.split(_upstreamMarker);
    if (parts.length < 2) {
      return null;
    }
    final missing = DwNginxUpstreams.missing(
      snippets: {'nginx.d': parts[1]},
      services: DwNginxUpstreams.servicesInListing(parts.first),
    );
    if (missing.isEmpty) {
      return null;
    }
    final names = missing.map((line) => line.split(': ').last).join(', ');
    return 'Nginx is configured to proxy to $names, and the applied stack has '
        'no such service. Restarting nginx now would make it read that '
        'configuration for the first time and refuse to start, taking the whole '
        'stand down. Nothing has been restarted.';
  }

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
    if (!skipGitUpdate)
      DwDeployStep(
        id: 'update-checkout',
        title: 'Update the checkout to origin/${target.branch}',
        run: updateCheckout,
      ),
    // After the checkout and before anything reads the stack: the bridge names
    // a file in the working copy, so it has to judge the revision this deploy
    // is applying. Judged before the update, a deploy that itself introduces
    // deploy/compose.override.yml would see a tree without it.
    DwDeployStep(
      id: 'bridge-override',
      title: 'Bridge a bare docker compose to the project override',
      run: bridgeOverride,
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
    // Between `up` and the restart, and it has to be exactly here: the stack
    // is now the one nginx will be pointed at, and the proxy has not been
    // touched yet. A step later this is a post-mortem.
    DwDeployStep(
      id: 'check-upstreams',
      title: 'Check nginx upstreams against the applied stack',
      run: checkUpstreams,
      verdict: upstreamVerdict,
    ),
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
