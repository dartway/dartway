import 'dart:async';

import 'compose_files.dart';
import 'deploy_target.dart';
import 'nginx_upstreams.dart';
import 'outside_probe.dart';
import 'remote_steps.dart';
import 'renderer.dart';
import 'secret_store.dart';
import 'ssh_runner.dart';
import 'stack.dart';

/// One step of a deployment.
///
/// Steps are data so that the same list drives execution, a dry run and the
/// tests that pin their order.
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

  /// Whether the step's output belongs in the log even when it succeeded —
  /// on where the output is the result, off where it is noise.
  final bool showOutput;

  /// A second opinion on a step that exited 0: why it must fail anyway, or null
  /// when it is genuinely fine. An exit code is a claim about the process, not
  /// about the work.
  final String? Function(DwSshResult result)? verdict;
}

/// Deploys an already-provisioned server: update the checkout, render the
/// environment, build, start the server — which migrates as it starts — then
/// the web image and the proxy, and finally ask the result from outside.
///
/// `docker-compose.yml` and `nginx.conf` are rendered here too, on every run.
/// They used to be written by `setup` alone, so that a routine push would not
/// turn into an infrastructure change — but they are derived from
/// `deploy/config.yaml` and the CLI, and a derived file written once goes
/// stale in silence: a CLI that had learnt a new build argument met a compose
/// file rendered before it existed, and the deploy died inside `docker build`
/// blaming the project's Dockerfile. What keeps a push routine is that the
/// rendering is reported and idempotent — "unchanged" on a run that changes
/// nothing — not that it is skipped.
class DwDeployRunner {
  DwDeployRunner({
    required this.ssh,
    required this.stack,
    String? appDir,
    String? storeDir,
    DwOutsideProbe? probe,
    this.remote,
    this.buildContext = '.',
  }) : appDir = appDir ?? stack.target.appDir,
       store = DwSecretStore(
         ssh: ssh,
         target: stack.target,
         directory: storeDir,
       ),
       probe = probe ?? DwOutsideProbe();

  final DwSshRunner ssh;
  final DwStack stack;

  /// The checkout, where the rendered compose file and `.env` live.
  final String appDir;

  final DwSecretStore store;
  final DwOutsideProbe probe;

  /// Where the rendered compose file builds the images from, relative to
  /// [appDir]: the checkout itself on a server. The local stack proof builds
  /// from a copy of the project elsewhere, and the stack is rendered again on
  /// every run (D-075), so the runner has to know it rather than the file.
  final String buildContext;

  /// Runs every step detached from the connection, when set — see
  /// [DwRemoteSteps]. Without it a step lives as long as its `ssh` call, which
  /// is what the local proof and the tests want.
  final DwRemoteSteps? remote;

  /// The step whose script the next [_as] call is, while [steps] runs one.
  String? _step;

  /// Where [remote] keeps the record of the deployment on the server.
  static String remoteDirectoryOf(DwDeployTarget target) =>
      '${target.runtimeConfigDir}/deploy-run';

  DwDeployTarget get target => stack.target;

  bool get _tls => stack.front is DwTlsFront;

  /// Every Compose call of a deployment goes through here, which is why the
  /// project's override can be named explicitly instead of copied.
  Future<DwSshResult> _compose(String arguments) =>
      _as(DwComposeFiles.commandIn(appDir, arguments));

  /// Every script of a deployment goes through here: detached when it is a
  /// step and [remote] is set, over the plain connection otherwise.
  Future<DwSshResult> _as(String script) {
    final step = _step;
    _step = null;
    final detached = remote;
    if (step != null && detached != null) return detached.run(step, script);
    return ssh.runAs(target.deployUser, script);
  }

  /// Brings the checkout to the tip of the deployment branch.
  ///
  /// `reset --hard` rather than `pull`: the server mirrors the repository, and
  /// a stray edit on the box must not be able to block a deploy. Ignored and
  /// untracked files — the rendered files among them — survive this.
  Future<DwSshResult> updateCheckout() => _as(
    "cd '$appDir' && "
    "git fetch origin '${target.branch}' --prune && "
    "git checkout -B '${target.branch}' 'origin/${target.branch}' && "
    "git reset --hard 'origin/${target.branch}'",
  );

  /// The commit the checkout is at: the full hash on the first line, the
  /// short one and the subject on the second.
  Future<DwSshResult> deployedRevision() =>
      _as("cd '$appDir' && git log -1 --format='%H%n%h %s'");

  /// Keeps a hand-typed `docker compose` in the checkout equal to the deploy.
  /// See [DwComposeFiles.bridgeIn].
  Future<DwSshResult> bridgeOverride() => _as(DwComposeFiles.bridgeIn(appDir));

  /// Renders the stack itself — the compose file and the proxy's
  /// configuration — from `deploy/config.yaml` and this version of the CLI,
  /// on every deploy, for the reason `.env` is rendered on every deploy: both
  /// are derived files, and a derived file that is only written once goes
  /// stale silently.
  ///
  /// It went stale exactly once and cost an afternoon: a CLI that had learnt
  /// to pass a new build argument met a compose file rendered before it
  /// existed, and the deploy failed inside `docker build` with a message
  /// about the project's Dockerfile — while the file to fix was on the server
  /// and not in the repository. Nothing named `deploy setup`, because nothing
  /// knew.
  ///
  /// Written through `cat >`, never a `mv`: the proxy has its configuration
  /// bind-mounted, and replacing the file would leave the container holding
  /// the old one.
  Future<DwSshResult> renderStack() {
    final renderer = DwStackRenderer(stack: stack, buildContext: buildContext);
    return _as(
      "cd '$appDir'\n"
      '${_renderFileScript(DwComposeFiles.rendered, renderer.composeFile)}\n'
      "install -d 'nginx.d/http' 'nginx.d/api' 'nginx.d/app'\n"
      '${_renderFileScript('nginx.conf', renderer.nginxFile)}',
    );
  }

  /// Writes [contents] to [name] when it differs, and says which it was.
  static String _renderFileScript(String name, String contents) {
    // A marker the rendered text cannot hold: it is YAML and Nginx
    // configuration, and neither carries a line of this shape.
    const marker = 'DW_RENDERED_FILE_END';
    return '''
dw_new=\$(mktemp)
cat >"\$dw_new" <<'$marker'
$contents
$marker
if cmp -s "\$dw_new" '$name' 2>/dev/null; then
  echo '$name: unchanged'
else
  cat "\$dw_new" >'$name'
  echo '$name: rendered again by this version of dartway'
fi
rm -f "\$dw_new"''';
  }

  /// Renders `.env` from the secret store — see
  /// [DwSecretStore.renderEnvironment]. Every deploy, so a secret changed with
  /// `secret set` takes effect on the next one.
  Future<DwSshResult> renderEnvironment() => _as(
    store.renderEnvironmentScript(
      appDir: appDir,
      required: stack.requiredSecretKeys,
      reserved: stack.reservedSecretKeys,
    ),
  );

  /// Asks Compose whether the merged stack is one it can run, before anything
  /// is built: a broken override or a missing interpolation is found here in
  /// a second, not after a ten-minute build.
  Future<DwSshResult> checkComposeConfig() => _compose('config --quiet');

  Future<DwSshResult> build() => _compose('build');

  /// Starts the bundled storage and runs the initialisation of both buckets,
  /// whose output says what it did.
  ///
  /// `</dev/null` is not decoration: without it `compose run -T` consumes the
  /// rest of the surrounding script from stdin.
  Future<DwSshResult> startStorage() => _as(
    '${DwComposeFiles.commandIn(appDir, 'up -d --wait ${DwStack.storageService}')} && '
    '${DwComposeFiles.invoke} run --rm -T ${DwStack.storageInitService} </dev/null',
  );

  Future<DwSshResult> startDatabase() =>
      _compose('up -d --wait ${DwStack.postgresService}');

  /// Waits for a container to be healthy; on anything else prints why and the
  /// container's own log, and fails.
  ///
  /// The server applies its migrations before it opens its port and exits
  /// non-zero when one fails, so the log printed on an exit *is* the migration
  /// outcome, in the server's words — nothing here reads it for meaning.
  static String waitHealthyFunction({int timeoutSeconds = 660}) =>
      '''
dw_wait_healthy() {
  dw_cid=\$1
  dw_label=\$2
  dw_deadline=\$(( \$(date +%s) + $timeoutSeconds ))
  while :; do
    dw_state=\$(docker inspect -f '{{.State.Status}} {{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}} {{.RestartCount}} {{.State.ExitCode}}' "\$dw_cid") || return 1
    set -- \$dw_state
    if [ "\$1" = running ] && [ "\$2" = healthy ]; then
      echo "\$dw_label is healthy"
      return 0
    fi
    if [ "\$2" = none ]; then
      echo "ERROR: \$dw_label has no healthcheck, so nothing can say it is serving" >&2
      return 1
    fi
    if [ "\$1" = exited ] || [ "\$1" = dead ] || [ "\$1" = restarting ] || [ "\$3" -gt 0 ]; then
      echo "ERROR: \$dw_label exited (code \$4) before it became healthy. Its log:" >&2
      docker logs --tail 200 "\$dw_cid" >&2 2>&1 || true
      return 1
    fi
    if [ "\$2" = unhealthy ]; then
      echo "ERROR: \$dw_label is running and failing its healthcheck. Its log:" >&2
      docker logs --tail 200 "\$dw_cid" >&2 2>&1 || true
      return 1
    fi
    if [ "\$(date +%s)" -ge "\$dw_deadline" ]; then
      echo "ERROR: \$dw_label was not healthy within $timeoutSeconds s. Its log:" >&2
      docker logs --tail 200 "\$dw_cid" >&2 2>&1 || true
      return 1
    fi
    sleep 2
  done
}
''';

  /// Replaces the server with the new image, one version at a time: the
  /// serving server stops gracefully (calls in flight are answered; clients
  /// retry through the gap), the new image applies the migrations in a
  /// one-off run that serves nothing (`DW_MIGRATE_ONLY=true`), then the new
  /// server starts and has to become healthy.
  ///
  /// No two versions ever run at once, so old code never writes into a new
  /// schema and never claims a job it does not know. The price is a short
  /// gap — the stop, the migrations, the start — which the client's retries
  /// cover.
  ///
  /// When the migrations or the new server fail, the image that was serving
  /// is started again, and the step fails with the server's own words. A
  /// migration that failed rolled back; a server that failed after its
  /// migrations applied leaves the previous code on the new schema, which the
  /// message says.
  Future<DwSshResult> replaceServer() => _as('''
set -e
cd '$appDir'
${DwComposeFiles.selectFiles}
${waitHealthyFunction()}
# The image the serving server runs, to start again on a failure. Read from
# the container: the build has already moved the image name to the new one.
old=\$(${DwComposeFiles.invoke} ps -aq ${DwStack.serverService} | head -n 1)
image=""
previous=""
if [ -n "\$old" ]; then
  image=\$(docker inspect -f '{{.Config.Image}}' "\$old")
  previous=\$(docker inspect -f '{{.Image}}' "\$old")
fi
dw_start_previous() {
  if [ -z "\$previous" ]; then
    echo "there is no previous server to start again" >&2
    return 0
  fi
  if docker image tag "\$previous" "\$image" && ${DwComposeFiles.invoke} up -d --no-deps ${DwStack.serverService} >/dev/null 2>&1; then
    echo "the previous server is running again" >&2
  else
    echo "ERROR: the previous server could not be started again" >&2
  fi
}
if [ -n "\$old" ]; then
  ${DwComposeFiles.invoke} stop -t 45 ${DwStack.serverService}
fi
if ! ${DwComposeFiles.invoke} run --rm --no-deps -T -e ${DwStack.migrateOnlyVariable}=true ${DwStack.serverService} </dev/null; then
  echo "ERROR: the new image could not apply its migrations (the log is above); they rolled back" >&2
  dw_start_previous
  exit 1
fi
${DwComposeFiles.invoke} up -d --no-deps ${DwStack.serverService}
cid=\$(${DwComposeFiles.invoke} ps -q ${DwStack.serverService})
if [ -z "\$cid" ]; then
  echo "ERROR: Compose started no ${DwStack.serverService} container" >&2
  dw_start_previous
  exit 1
fi
if ! dw_wait_healthy "\$cid" 'the new server'; then
  echo "ERROR: the new server did not become healthy; its migrations are applied, so the previous code runs on the new schema" >&2
  dw_start_previous
  exit 1
fi
''');

  Future<DwSshResult> startWeb() =>
      _compose('up -d --no-deps --wait ${DwStack.webService}');

  /// Converges everything else — the proxy, certbot, whatever the project's
  /// override adds — and removes services the stack no longer declares.
  Future<DwSshResult> startStack() => _compose('up -d --remove-orphans');

  /// Marks the boundary between the two answers [checkUpstreams] collects.
  static const String _upstreamMarker = '--dw-nginx-d--';

  /// Asks the server what the stack actually holds and what nginx expects —
  /// the rendered configuration and every snippet.
  ///
  /// On the server, not against the working copy: the checkout can be right
  /// while the invocation was not.
  Future<DwSshResult> checkUpstreams() => _as(
    "cd '$appDir' && ${DwComposeFiles.selectFiles} && "
    '${DwComposeFiles.invoke} config --services && '
    "echo '$_upstreamMarker' && cat nginx.conf && "
    "{ find nginx.d -name '*.conf' -exec cat {} + 2>/dev/null || true; }",
  );

  /// Why a stack that came up is still not fit to have its proxy restarted.
  static String? upstreamVerdict(DwSshResult result) {
    final parts = result.stdout.split(_upstreamMarker);
    if (parts.length < 2) {
      return 'The server did not answer both questions (services, then nginx '
          'configuration); nothing can be said about the upstreams.';
    }
    final missing = DwNginxUpstreams.missing(
      snippets: {'nginx': parts[1]},
      services: DwNginxUpstreams.servicesInListing(parts.first),
    );
    if (missing.isEmpty) {
      return null;
    }
    final names = missing.map((line) => line.split(': ').last).join(', ');
    return 'Nginx is configured to proxy to $names, and the applied stack has '
        'no such service. Restarting nginx now would make it read that '
        'configuration and refuse to start, taking the whole stand down. '
        'Nothing has been restarted.';
  }

  /// `nginx -t` inside the running proxy, on the stack's network: the syntax,
  /// the certificate files, and every upstream name resolved by the DNS the
  /// restarted proxy will use.
  Future<DwSshResult> testProxyConfiguration() =>
      _compose('exec -T ${DwStack.nginxService} nginx -t');

  /// Asks Let's Encrypt for the certificate of every served host.
  ///
  /// `deploy setup` writes a one-day self-signed certificate so that nginx can
  /// start at all, and certbot's `renew` loop only renews lineages it manages.
  /// Runs after the proxy answers the ACME challenge and before the restart
  /// that makes nginx read what was issued. A lineage certbot already manages
  /// is left alone when it covers every served host, which keeps a routine
  /// deploy off the rate limit; a host added to the configuration since — a
  /// storage domain, a site — extends it.
  Future<DwSshResult> issueCertificate() {
    final certName = target.apiDomain;
    final served = target.servedDomains;
    final domains = served.map((domain) => "-d '$domain'").join(' ');
    final certbot =
        '${DwComposeFiles.invoke} run --rm -T --entrypoint sh '
        '${DwStack.certbotService} -c';
    final request =
        "certbot certonly --webroot -w /var/www/certbot \\\n"
        "    --cert-name '$certName' $domains \\\n"
        "    --email '${target.sslEmail}' --agree-tos --no-eff-email -n";
    return _as('''
set -e
cd '$appDir'
${DwComposeFiles.selectFiles}
# A renewal config is what certbot writes for a lineage it manages, and the
# self-signed bootstrap certificate has none. `-s` rather than `-f`: a failed
# attempt leaves that file behind empty, and certbot then issues under
# `$certName-0001`, a path nginx never names.
if managed=\$($certbot \\
  "test -s /etc/letsencrypt/renewal/$certName.conf && certbot certificates --cert-name '$certName'" </dev/null); then
  covered=\$(printf '%s\\n' "\$managed" | sed -n 's/^ *Domains: *//p')
  missing=""
  for domain in ${served.map((domain) => "'$domain'").join(' ')}; do
    case " \$covered " in *" \$domain "*) ;; *) missing="\$missing \$domain" ;; esac
  done
  if [ -z "\$missing" ]; then
    echo "certbot already manages $certName for every served host"
    exit 0
  fi
  echo "extending $certName to:\$missing"
  $certbot "
  $request --expand
" </dev/null
  exit 0
fi
$certbot "
  set -e
  # certonly refuses to write into an existing live directory, and that
  # directory is exactly what the bootstrap step created.
  rm -rf /etc/letsencrypt/live/$certName \\
         /etc/letsencrypt/archive/$certName \\
         /etc/letsencrypt/renewal/$certName.conf
  $request
" </dev/null
''');
  }

  /// Nginx resolves service names once at start; after the server container
  /// is recreated its cached address points at a container that is gone. The
  /// restart is checked, not assumed: `restart` exits 0 for a proxy that dies
  /// a second later on its configuration.
  Future<DwSshResult> restartProxy() => _as('''
set -e
cd '$appDir'
${DwComposeFiles.selectFiles}
cid=\$(${DwComposeFiles.invoke} ps -q ${DwStack.nginxService})
[ -n "\$cid" ] || { echo "ERROR: there is no nginx container to restart" >&2; exit 1; }
# Compared with the count before, not with zero: a proxy that crash-looped once
# last month is not a failure of this deploy.
before=\$(docker inspect -f '{{.RestartCount}}' "\$cid")
${DwComposeFiles.invoke} restart ${DwStack.nginxService}
sleep 3
state=\$(docker inspect -f '{{.State.Status}} {{.RestartCount}}' "\$cid")
if [ "\$state" != "running \$before" ]; then
  echo "ERROR: nginx is not running after the restart (\$state). Its log:" >&2
  docker logs --tail 50 "\$cid" >&2 2>&1 || true
  exit 1
fi
echo "nginx restarted and running"
''');

  Future<DwSshResult> status() =>
      _compose("ps --format '{{.Name}}\t{{.Status}}'");

  List<DwDeployStep> steps({required bool skipGitUpdate}) => [
    for (final step in _plannedSteps(skipGitUpdate: skipGitUpdate))
      DwDeployStep(
        id: step.id,
        title: step.title,
        showOutput: step.showOutput,
        verdict: step.verdict,
        run: () {
          _step = step.id;
          try {
            return step.run();
          } finally {
            _step = null;
          }
        },
      ),
  ];

  List<DwDeployStep> _plannedSteps({required bool skipGitUpdate}) => [
    if (!skipGitUpdate)
      DwDeployStep(
        id: 'update-checkout',
        title: 'Update the checkout to origin/${target.branch}',
        run: updateCheckout,
      ),
    // After the checkout and before anything reads the stack: the bridge names
    // a file in the working copy, so it has to judge the revision this deploy
    // is applying.
    DwDeployStep(
      id: 'bridge-override',
      title: 'Bridge a bare docker compose to the project override',
      run: bridgeOverride,
    ),
    // Before anything reads the stack: every Compose call below uses the
    // rendered file, and a stale one fails deep inside a build.
    DwDeployStep(
      id: 'render-stack',
      title: 'Render the stack and the proxy configuration',
      run: renderStack,
      showOutput: true,
    ),
    DwDeployStep(
      id: 'render-env',
      title: 'Render the server environment from the secret store',
      run: renderEnvironment,
      showOutput: true,
    ),
    DwDeployStep(
      id: 'compose-config',
      title: 'Check the merged compose configuration',
      run: checkComposeConfig,
    ),
    DwDeployStep(id: 'build', title: 'Build images', run: build),
    if (target.storage == DwStorageMode.bundled)
      DwDeployStep(
        id: 'storage',
        title: 'Start the bundled storage and set up its public and private '
            'bucket',
        run: startStorage,
        showOutput: true,
      ),
    DwDeployStep(
      id: 'database',
      title: 'Start the database',
      run: startDatabase,
    ),
    DwDeployStep(
      id: 'server',
      title:
          'Replace the server: stop it, migrate, start the new one (the '
          'previous one again on a failure)',
      run: replaceServer,
      showOutput: true,
    ),
    DwDeployStep(id: 'web', title: 'Replace the web app', run: startWeb),
    DwDeployStep(
      id: 'stack',
      title: 'Converge the rest of the stack',
      run: startStack,
    ),
    // Between the stack coming up and the restart, and it has to be exactly
    // here: the stack is now the one nginx will be pointed at, and the proxy
    // has not re-read anything yet. A step later this is a post-mortem.
    DwDeployStep(
      id: 'check-upstreams',
      title: 'Check nginx upstreams against the applied stack',
      run: checkUpstreams,
      verdict: upstreamVerdict,
    ),
    DwDeployStep(
      id: 'nginx-test',
      title: 'Test the proxy configuration inside the running proxy',
      run: testProxyConfiguration,
    ),
    if (_tls)
      DwDeployStep(
        id: 'certificate',
        title: 'Issue the TLS certificate',
        run: issueCertificate,
        showOutput: true,
      ),
    DwDeployStep(
      id: 'restart-proxy',
      title: 'Restart nginx',
      run: restartProxy,
    ),
  ];

  /// Runs every outside probe, retrying the failed ones while the stack
  /// settles, and answers with the last result of each.
  Future<List<DwProbeResult>> verifyFromOutside({
    int attempts = 12,
    Duration pause = const Duration(seconds: 5),
  }) async {
    final probes = dwOutsideProbes(stack, probe);
    final results = List<DwProbeResult?>.filled(probes.length, null);
    for (var attempt = 1; attempt <= attempts; attempt++) {
      for (var index = 0; index < probes.length; index++) {
        if (results[index]?.passed ?? false) continue;
        results[index] = await probes[index]();
      }
      if (results.every((result) => result!.passed) || attempt == attempts) {
        break;
      }
      await Future<void>.delayed(pause);
    }
    return results.cast<DwProbeResult>();
  }
}
