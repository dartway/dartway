import 'dart:async';

import 'compose_files.dart';
import 'data_volumes.dart';
import 'deploy_target.dart';
import 'nginx_upstreams.dart';
import 'outside_probe.dart';
import 'output_mask.dart';
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
    required DwSshRunner ssh,
    required this.stack,
    String? appDir,
    String? storeDir,
    DwOutsideProbe? probe,
    this.remote,
    this.buildContext = '.',
  }) : ssh = DwMaskedSshRunner(
         ssh,
         deployUser: stack.target.deployUser,
         storeFile:
             '${storeDir ?? stack.target.runtimeConfigDir}/${DwSecretStore.fileName}',
       ),
       appDir = appDir ?? stack.target.appDir,
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

  /// Asks the server which stacks it runs and refuses when it runs others but
  /// not this one ([judgeStackIdentity]) — a repository that moved without
  /// `project:` pinning the old name. First of all, so a refusal leaves the
  /// server exactly as it was.
  Future<DwSshResult> checkStackIdentity() async {
    final listed = await _as(dwStackIdentityScript(target));
    if (!listed.ok) return listed;
    final verdict = judgeStackIdentity(
      projectName: target.projectName,
      environment: target.environment,
      volumeListing: listed.stdout,
      configDirListing: listed.stdout,
    );
    return DwSshResult(
      exitCode: verdict.ok ? 0 : 1,
      stdout: verdict.ok ? verdict.detail : '',
      stderr: verdict.ok ? '' : verdict.detail,
    );
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

  /// The same guard `deploy setup` runs before it ever writes a compose file
  /// ([judgeDataVolumes]) — run again here, because `run` starts the stack
  /// too and a server that has only ever been `run`, never `setup` again
  /// since a config change, would otherwise start an expected volume empty
  /// beside real data on it (#331's storage rename was exactly this shape).
  Future<DwSshResult> checkDataVolumes() async {
    final listed = await _as("docker volume ls --format '{{.Name}}'");
    if (!listed.ok) return listed;
    final verdict = judgeDataVolumes(
      volumeListing: listed.stdout,
      projectPrefix: target.projectName,
      expectedDataVolumes: stack.dataVolumeNames,
    );
    return DwSshResult(
      exitCode: verdict.ok ? 0 : 1,
      stdout: verdict.ok ? verdict.detail : '',
      stderr: verdict.ok ? '' : verdict.detail,
    );
  }

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

  /// Starts the bundled Postgres. Nothing to do with `database: external` —
  /// there is no such service in the rendered stack, and the server reaches
  /// the managed database directly through the secrets in `.env`.
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

  /// Defines `dw_certificate_coverage`, which prints what certbot manages
  /// under the certificate's name, in one word: `unmanaged` when it manages
  /// nothing there yet (the self-signed bootstrap certificate `deploy setup`
  /// writes has no renewal config), `covered` when the certificate names every
  /// served host, `missing` followed by the hosts it does not name otherwise.
  /// Fails when the question cannot be asked. Expects
  /// [DwComposeFiles.selectFiles] to have run.
  ///
  /// The hosts are read from the certificate nginx serves, with `openssl`,
  /// not from `certbot certificates`: that report is prose, and certbot 5
  /// renamed its `Domains:` line to `Identifiers:`. Parsed for the old word,
  /// every lineage read as covering nothing, and every deploy asked Let's
  /// Encrypt to extend a certificate that already named every host
  /// (dartway/dartway#433).
  String get _coverageFunction {
    final certName = target.apiDomain;
    final hosts = target.servedDomains.map((domain) => "'$domain'").join(' ');
    // `-s` rather than `-f`: a failed attempt leaves the renewal config behind
    // empty, and certbot then issues under `$certName-0001`, a path nginx
    // never names.
    return '''
dw_certificate_coverage() {
  dw_found=\$($_certbot "if [ -s /etc/letsencrypt/renewal/$certName.conf ]; then openssl x509 -in /etc/letsencrypt/live/$certName/fullchain.pem -noout -ext subjectAltName; else echo unmanaged; fi" </dev/null) || return 1
  if [ "\$dw_found" = unmanaged ]; then
    echo unmanaged
    return 0
  fi
  dw_covered=" \$(printf '%s\\n' "\$dw_found" | tr ',' '\\n' | sed -n 's/^ *DNS://p' | tr '\\n' ' ')"
  dw_missing=""
  for dw_host in $hosts; do
    case "\$dw_covered" in *" \$dw_host "*) ;; *) dw_missing="\$dw_missing \$dw_host" ;; esac
  done
  if [ -z "\$dw_missing" ]; then echo covered; else echo "missing\$dw_missing"; fi
}''';
  }

  /// A one-off certbot container with a shell as its entrypoint; the script
  /// it runs follows.
  static const String _certbot =
      '${DwComposeFiles.invoke} run --rm -T --entrypoint sh '
      '${DwStack.certbotService} -c';

  /// Makes the certificate cover every served host, asking Let's Encrypt only
  /// when it does not.
  ///
  /// `deploy setup` writes a one-day self-signed certificate so that nginx can
  /// start at all, and certbot's `renew` loop only renews lineages it manages:
  /// this replaces the bootstrap certificate with a real one, and extends a
  /// lineage certbot manages to a host added to the configuration since — a
  /// storage domain, a site. A lineage that already names every host is left
  /// alone, which keeps a routine deploy off the rate limit.
  ///
  /// Runs twice in a deployment ([steps]). First before anything is built or
  /// replaced, through the proxy the previous deploy left running
  /// ([throughServingProxy]): Let's Encrypt is an outside service that fails
  /// for reasons of its own, and failing there stops the deploy with the
  /// previous version still serving. That proxy answers the challenge for a
  /// host it was never configured for too: its port-80 server comes before
  /// the project's http snippets, so nginx makes it the default for any name
  /// no project port-80 server claims. With no proxy running — a first
  /// deploy, a stand that is down — nothing serves that a failure could take
  /// down, and the first run leaves the issue to the second: after
  /// the stack has started a proxy, before nginx is restarted to read what
  /// was issued. On a routine deploy the second run finds every host covered
  /// and asks nothing.
  Future<DwSshResult> issueCertificate({bool throughServingProxy = false}) {
    final certName = target.apiDomain;
    final domains = target.servedDomains
        .map((domain) => "-d '$domain'")
        .join(' ');
    final request =
        "certbot certonly --webroot -w /var/www/certbot \\\n"
        "    --cert-name '$certName' $domains \\\n"
        "    --email '${target.sslEmail}' --agree-tos --no-eff-email -n";
    final deferral = throughServingProxy
        ? '''
# An assignment, so that Compose failing to answer fails the step instead of
# reading as "no proxy" and putting the request after the point of no return.
proxy=\$(${DwComposeFiles.invoke} ps -q --status running ${DwStack.nginxService})
if [ -z "\$proxy" ]; then
  echo "no proxy is running to answer Let's Encrypt, so nothing is serving that a failure could take down: the certificate is issued once this deploy has started one"
  exit 0
fi
'''
        : '';
    return _as('''
set -e
cd '$appDir'
${DwComposeFiles.selectFiles}
$deferral$_coverageFunction
coverage=\$(dw_certificate_coverage)
case "\$coverage" in
  covered)
    echo "certbot already manages $certName for every served host"
    exit 0
    ;;
  missing\\ *)
    echo "extending $certName to:\${coverage#missing}"
    $_certbot "
  $request --expand
" </dev/null
    exit 0
    ;;
  unmanaged) ;;
  *)
    echo "ERROR: cannot tell which hosts the certificate covers: \$coverage" >&2
    exit 1
    ;;
esac
$_certbot "
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
    // Before anything touches the server: every path below is named after the
    // project, and a project whose name changed with its repository would
    // otherwise find no checkout, or start a second, empty stack.
    DwDeployStep(
      id: 'stack-identity',
      title: "Check this server runs this project's stack",
      run: checkStackIdentity,
    ),
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
    // Before anything starts: an expected data volume that does not exist
    // while another one of this project's does is a config change about to
    // start serving fresh data next to the real one, silently — catch it
    // before the build, not after the stack is already up and green.
    DwDeployStep(
      id: 'data-volumes',
      title: 'Check no data volume would start empty beside existing data',
      run: checkDataVolumes,
    ),
    // Before anything is built, started or replaced: Let's Encrypt can fail
    // for reasons of its own, and failing here leaves the previous version
    // serving. A step later, the same failure strands a replaced server
    // behind a proxy that was never restarted (#433).
    if (_tls)
      DwDeployStep(
        id: 'certificate',
        title:
            'Make the TLS certificate cover every served host, through the '
            'proxy still serving',
        run: () => issueCertificate(throughServingProxy: true),
        showOutput: true,
      ),
    DwDeployStep(id: 'build', title: 'Build images', run: build),
    if (target.storage == DwStorageMode.bundled)
      DwDeployStep(
        id: 'storage',
        title:
            'Start the bundled storage and set up its public and private '
            'bucket',
        run: startStorage,
        showOutput: true,
      ),
    if (target.database == DwDatabaseMode.bundled)
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
    // Issues what the first certificate step could not, with no proxy running
    // to answer the challenge then; asks nothing on a routine deploy.
    if (_tls)
      DwDeployStep(
        id: 'certificate-started-proxy',
        title:
            'Make the TLS certificate cover every served host, through the '
            'proxy now running',
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
