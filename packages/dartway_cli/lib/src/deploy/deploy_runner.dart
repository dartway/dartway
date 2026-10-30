import 'dart:async';
import 'dart:convert';

import 'compose_files.dart';
import 'data_volumes.dart';
import 'deploy_target.dart';
import 'disk_space.dart';
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
/// the web image and the proxy, ask the result from outside, then clean
/// unused stack images and the build cache.
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
    this.withoutRollbackImage = false,
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

  /// Allows this deployment to proceed only when its running image cannot
  /// be resolved. A resolvable image is always pinned for rollback.
  final bool withoutRollbackImage;

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

  /// Whether this server runs this project's stack, or none at all
  /// ([judgeStackIdentity]): a repository that moved without `project:`
  /// pinning the old name fails here. It lists data volumes and secret
  /// stores, names only ([dwStackIdentityScript]), over the plain connection
  /// — a precondition of `deploy run`, not one of its [steps], so it is
  /// judged afresh on every run and resume and never recorded on the server.
  Future<DwDataVolumeVerdict> checkStackIdentity() async {
    final listed = await ssh.runAs(
      target.deployUser,
      dwStackIdentityScript(target),
    );
    if (!listed.ok) {
      return DwDataVolumeVerdict.fail(
        'cannot list the stacks on the server: ${listed.firstLine}',
      );
    }
    return judgeStackIdentity(
      projectName: target.projectName,
      environment: target.environment,
      volumeListing: listed.stdout,
      configDirListing: listed.stdout,
    );
  }

  /// Brings the checkout to [revision], or the tip of the deployment branch.
  ///
  /// `reset --hard` rather than `pull`: the server mirrors the repository, and
  /// a stray edit on the box must not be able to block a deploy. Ignored and
  /// untracked files — the rendered files among them — survive this.
  Future<DwSshResult> updateCheckout([String? revision]) {
    if (revision == null) {
      return _as(
        "cd '$appDir' && "
        "git fetch origin '${target.branch}' --prune && "
        "git checkout -B '${target.branch}' 'origin/${target.branch}' && "
        "git reset --hard 'origin/${target.branch}'",
      );
    }
    return _as('''
cd '$appDir' || exit \$?
git fetch origin '${target.branch}' --prune || exit \$?
resolved=\$(git rev-parse --verify '$revision^{commit}' 2>/dev/null) || {
  echo "revision-not-found: $revision not found on origin/${target.branch}" >&2
  exit 1
}
git merge-base --is-ancestor "\$resolved" 'origin/${target.branch}' || {
  echo "revision-not-on-branch: $revision not on origin/${target.branch}" >&2
  exit 1
}
head=\$(git rev-parse HEAD) || exit \$?
if [ "\$head" != "\$resolved" ] && git merge-base --is-ancestor "\$resolved" "\$head"; then
  echo "superseded: the server is at \$head, which already contains \$resolved" >&2
  exit 1
fi
git checkout -B '${target.branch}' "\$resolved" &&
git reset --hard "\$resolved" &&
git rev-parse HEAD
''');
  }

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
  Future<DwSshResult> checkComposeConfig() async {
    const marker = '--dw-free-memory--';
    final result = await _as(
      "cd '$appDir' && ${DwComposeFiles.selectFiles} && "
      '${DwComposeFiles.invoke} config --format json && '
      "echo '$marker' && { awk '/^MemAvailable:/ {print \$2 * 1024}' /proc/meminfo 2>/dev/null || true; }",
    );
    if (!result.ok) return result;
    final parts = result.stdout.split(marker);
    if (parts.length != 2) return result;
    final available = num.tryParse(parts.last.trim());
    final config = jsonDecode(parts.first) as Map<String, dynamic>;
    final services = config['services'] as Map?;
    final command = (services?[DwStack.postgresService] as Map?)?['command'];
    if (target.database == DwDatabaseMode.bundled &&
        services?.containsKey(DwStack.postgresService) == true) {
      final problem = DwStackRenderer.postgresCommandProblem(command);
      if (problem != null)
        return DwSshResult(exitCode: 1, stdout: '', stderr: problem);
    }
    final server = services?['server'] as Map?;
    final limit =
        server?['mem_limit'] ??
        server?['deploy']?['resources']?['limits']?['memory'];
    final bytes = num.tryParse(
      '$limit',
    ); // Compose normalizes memory limits to bytes.
    final needed =
        (bytes ?? 0) * 3; // Two servers plus the migration container.
    final warning = available != null && needed > available
        ? 'WARNING: host free memory is $available bytes; two server containers '
              'plus the migration container need $needed bytes at the configured limits. '
              'Reduce the server memory limit or add host memory before deployment.\n'
        : '';
    return DwSshResult(exitCode: 0, stdout: warning, stderr: result.stderr);
  }

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

  Future<DwSshResult> build() async {
    final space = await dwCheckBuildDiskSpace(
      ssh: ssh,
      deployUser: target.deployUser,
      minimum: target.minFreeDisk,
      minimumBytes: target.minFreeDiskBytes,
      dockerImage: stack.resolvedImage(DwStack.postgresImage),
    );
    if (!space.ok) return space;
    return _as('''
set -e
cd '$appDir'
${DwComposeFiles.selectFiles}
${_rememberImage(DwStack.serverService)}
${_rememberImage(DwStack.webService)}
# A Compose deploy has no CI run number. Its UTC epoch second is nevertheless
# monotonic enough for a release label and, unlike the Dockerfile's local-build
# default, distinguishes successive deployed web images.
${DwComposeFiles.invoke} build --build-arg BUILD_NUMBER="\$(date -u +%s)"
''');
  }

  /// Starts the bundled storage and runs the initialisation of both buckets,
  /// whose output says what it did.
  ///
  /// `</dev/null` is not decoration: without it `compose run -T` consumes the
  /// rest of the surrounding script from stdin.
  Future<DwSshResult> startStorage() => _as(
    '${DwComposeFiles.commandIn(appDir, 'up -d --wait ${DwStack.storageService}')} && '
    '${DwComposeFiles.invoke} run --rm -T ${DwStack.storageInitService} </dev/null',
  );

  /// Starts the bundled Postgres, then turns on what `deploy stats` reads:
  /// the `pg_stat_statements` extension (its library is preloaded by the
  /// rendered command line) and the slow-statement log at `slow_query_ms`.
  /// The threshold is `ALTER SYSTEM` and a reload, not a command-line flag,
  /// so changing it never restarts the database under a serving server.
  ///
  /// Nothing to do with `database: external` — there is no such service in
  /// the rendered stack, and the server reaches the managed database directly
  /// through the secrets in `.env`.
  Future<DwSshResult> startDatabase() {
    final name = stack.databaseName;
    final threshold = target.slowQueryMs;
    return _as('''
set -e
cd '$appDir'
${DwComposeFiles.selectFiles}
${DwComposeFiles.invoke} up -d --wait ${DwStack.postgresService}
${DwComposeFiles.invoke} exec -T ${DwStack.postgresService} psql -X -q -v ON_ERROR_STOP=1 -U '$name' -d '$name' >/dev/null <<'DW_SQL'
CREATE EXTENSION IF NOT EXISTS pg_stat_statements;
ALTER SYSTEM SET log_parameter_max_length = 0;
ALTER SYSTEM SET log_parameter_max_length_on_error = 0;
ALTER SYSTEM SET log_min_duration_statement = $threshold;
SELECT pg_reload_conf();
DW_SQL
echo "pg_stat_statements is on; statements over $threshold ms are logged"
''');
  }

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

  String get _journalDirectory =>
      remote?.directory ?? '${store.directory}/deploy-run';

  /// Starts a deployment without [remote], discarding the previous journal.
  /// Call once before its first build or replacement, never on a retry.
  /// Remote deployments start through [DwRemoteSteps.beginFresh] instead.
  Future<DwSshResult> beginLocalDeployment() {
    if (remote != null) {
      throw StateError(
        'Remote deployments start through DwRemoteSteps.beginFresh.',
      );
    }
    return _as("rm -rf '$_journalDirectory'\n");
  }

  // Written before building, once per deployment: a retry or a resumed
  // cleanup must retain the original rollback image, not the newly serving one.
  String _rememberImage(String service) {
    final unresolved = withoutRollbackImage
        ? 'echo "WARNING: this deploy has no rollback image for $service; '
              'a failure leaves the service down until the next deploy." >&2'
        : 'echo "Cannot resolve the running $service image (\$container_image): '
              'neither \$image_name nor ${target.projectName}-$service:dw-previous '
              'holds the running container; refusing to record a rollback image. '
              'Rerun: dartway deploy run --env ${target.environment} '
              '--without-rollback-image" >&2\n        exit 1';
    return """
mkdir -p '$_journalDirectory'
if [ ! -f '$_journalDirectory/$service.previous' ]; then
  previous_container=\$(${DwComposeFiles.invoke} ps -aq $service | head -n 1)
  if [ -n "\$previous_container" ]; then
    image_name=\$(docker inspect -f '{{.Config.Image}}' "\$previous_container")
    container_image=\$(docker inspect -f '{{.Image}}' "\$previous_container")
    # With attestations .Image may be a platform manifest which Docker
    # cannot inspect. A tag is safe only if its exported image still holds
    # this exact container. An interrupted earlier deployment may have moved
    # the name after pinning the serving image as dw-previous: try both.
    if ! docker image inspect -f '{{.Id}}' "\$container_image" >'$_journalDirectory/$service.previous.tmp' 2>/dev/null; then
      : >'$_journalDirectory/$service.previous.tmp'
      full_container=\$(docker inspect -f '{{.Id}}' "\$previous_container")
      for name in "\$image_name" '${target.projectName}-$service:dw-previous'; do
        candidate=\$(docker image inspect -f '{{.Id}}' "\$name" 2>/dev/null) || continue
        holders=\$(docker ps -aq --no-trunc --filter "ancestor=\$candidate")
        if printf '%s\\n' "\$holders" | grep -Fxq "\$full_container"; then
          printf '%s\\n' "\$candidate" >'$_journalDirectory/$service.previous.tmp'
          break
        fi
      done
      if [ ! -s '$_journalDirectory/$service.previous.tmp' ]; then
        $unresolved
      fi
    fi
    # The containerd store can drop the old exported image as soon as a
    # build moves latest, even while its container still runs. Pin it first.
    if [ -s '$_journalDirectory/$service.previous.tmp' ]; then
      docker image tag "\$(cat '$_journalDirectory/$service.previous.tmp')" '${target.projectName}-$service:dw-previous'
    fi
  else
    : >'$_journalDirectory/$service.previous.tmp'
  fi
  mv '$_journalDirectory/$service.previous.tmp' '$_journalDirectory/$service.previous'
else
  # A journal entry is not proof that Docker still has the rollback image.
  # Never replace it with the newly serving image when resuming a deployment.
  rollback_image=\$(cat '$_journalDirectory/$service.previous')
  if [ -n "\$rollback_image" ]; then
    if ! docker image inspect -f '{{.Id}}' "\$rollback_image" >/dev/null 2>&1; then
      echo "The $service rollback image (\$rollback_image) recorded for this deployment is missing; refusing to build or replace services because rollback cannot work. Restore the image or start a fresh deployment without --resume." >&2
      exit 1
    fi
    pinned_image=\$(docker image inspect -f '{{.Id}}' '${target.projectName}-$service:dw-previous' 2>/dev/null) || pinned_image=
    if [ "\$pinned_image" != "\$rollback_image" ]; then
      docker image tag "\$rollback_image" '${target.projectName}-$service:dw-previous'
    fi
  fi
fi
""";
  }

  /// How long the proxy may keep answering from its previous lookup of a
  /// service: two of its re-resolution periods
  /// ([DwStackRenderer.resolveSeconds]) and a second.
  static const int _proxyCatchUpSeconds =
      2 * DwStackRenderer.resolveSeconds + 1;

  /// Defines `dw_roll_out` and `dw_retire`, the two halves of replacing a
  /// service without a moment in which nothing answers for it. Expects
  /// [DwComposeFiles.selectFiles] and [waitHealthyFunction] to have run.
  ///
  /// `dw_roll_out <service> <label> <serving ids…>` starts one container of
  /// the build beside the serving ones (`--scale` one higher,
  /// `--no-recreate` so they are left alone) and waits for its healthcheck;
  /// it leaves its id in `dw_new`, empty when Compose started none.
  /// `dw_retire <ids…>` waits until the proxy has looked the service up
  /// again — it re-resolves every [DwStackRenderer.resolveSeconds] seconds —
  /// then stops each old container gracefully, removes it, and waits for the
  /// proxy to look it up once more, so that nothing after this step meets an
  /// address that is gone.
  static String get _rolloutFunctions =>
      '''
dw_roll_out() {
  dw_new=""
  dw_service=\$1
  dw_label=\$2
  shift 2
  if [ \$# -eq 0 ]; then
    ${DwComposeFiles.invoke} up -d --no-deps "\$dw_service" || return 1
    dw_new=\$(${DwComposeFiles.invoke} ps -q "\$dw_service" | head -n 1)
  else
    ${DwComposeFiles.invoke} up -d --no-deps --no-recreate --scale "\$dw_service=\$((\$# + 1))" "\$dw_service" || return 1
    for dw_c in \$(${DwComposeFiles.invoke} ps -q "\$dw_service"); do
      case " \$* " in *" \$dw_c "*) ;; *) dw_new=\$dw_c ;; esac
    done
  fi
  if [ -z "\$dw_new" ]; then
    echo "ERROR: Compose started no new \$dw_label container" >&2
    return 1
  fi
  dw_wait_healthy "\$dw_new" "the new \$dw_label" || return 1
  # Compose gives every container its service alias immediately, regardless
  # of health. The proxy uses only this separate network's gated alias.
  dw_project=\$(docker inspect -f '{{index .Config.Labels "com.docker.compose.project"}}' "\$dw_new") || return 1
  if [ -z "\$dw_project" ]; then
    echo "ERROR: the new \$dw_label has no Compose project label" >&2
    return 1
  fi
  dw_network="\${dw_project}_routed"
  if ! docker network inspect "\$dw_network" >/dev/null 2>&1; then
    docker network create --label "com.docker.compose.project=\$dw_project" --label 'com.docker.compose.network=routed' "\$dw_network" >/dev/null || return 1
  fi
  docker network connect --alias "dw-\$dw_service" "\$dw_network" "\$dw_new" || return 1
}
dw_retire() {
  [ \$# -gt 0 ] || return 0
  sleep $_proxyCatchUpSeconds
  for dw_c in "\$@"; do
    docker stop -t 45 "\$dw_c" >/dev/null
    docker rm "\$dw_c" >/dev/null
  done
  # And until it has forgotten them: a reload in the meantime starts workers
  # from the lookup that still held the stopped address.
  sleep $_proxyCatchUpSeconds
}
''';

  /// The script that replaces [service] with its new build beside the one
  /// serving — see [replaceServer]; [migrate] runs between the two, with the
  /// previous version still serving, and fails the replacement when it fails.
  String _replaceScript(String service, String label, {String? migrate}) =>
      '''
set -e
cd '$appDir'
${DwComposeFiles.selectFiles}
${waitHealthyFunction()}
$_rolloutFunctions
${_rememberImage(service)}
# The container supplies the image name to restore. The journal holds the
# exported rollback image, pinned before the build moved that name.
old=\$(${DwComposeFiles.invoke} ps -aq $service | head -n 1)
image=""
previous=""
if [ -n "\$old" ]; then
  image=\$(docker inspect -f '{{.Config.Image}}' "\$old")
  previous=\$(cat '$_journalDirectory/$service.previous')
fi
serving=\$(${DwComposeFiles.invoke} ps -q --status running $service)
# A container that is not running serves nothing, and \`up --scale\` would
# start it again instead of the new build.
for c in \$(${DwComposeFiles.invoke} ps -aq $service); do
  case " \$(echo \$serving) " in *" \$c "*) ;; *) docker rm --force "\$c" >/dev/null ;; esac
done
# After a failure: the service's image name means the image that serves
# again, so that a later \`docker compose up\` does not start the failed build;
# and with nothing serving, the previous version is started again.
dw_fall_back() {
  if [ -z "\$previous" ]; then
    echo "there is no previous $label to fall back to" >&2
    return 0
  fi
  if ! docker image tag "\$previous" "\$image"; then
    echo "ERROR: the previous $label image could not be named \$image again" >&2
    return 0
  fi
  if [ -n "\$serving" ]; then
    echo "the previous $label keeps serving" >&2
  elif dw_roll_out $service 'previous $label' >/dev/null 2>&1; then
    echo "the previous $label is running again" >&2
  else
    echo "ERROR: the previous $label could not be started again" >&2
  fi
}
${migrate ?? ''}
if ! dw_roll_out $service '$label' \$serving; then
  if [ -n "\$dw_new" ]; then docker rm --force "\$dw_new" >/dev/null 2>&1 || true; fi
  echo "ERROR: the new $label did not become healthy${migrate == null ? '' : '; its migrations are applied, so the previous code runs on the new schema'}" >&2
  dw_fall_back
  exit 1
fi
dw_retire \$serving
if [ -n "\$serving" ]; then
  echo "the new $label serves; the previous one stopped after it"
fi
''';

  /// Replaces the server with the new image without a moment in which
  /// nothing answers: the new image applies the migrations in a one-off run
  /// that serves nothing (`DW_MIGRATE_ONLY=true`) while the previous server
  /// still serves, the new server starts beside it and has to become
  /// healthy, and only then does the previous one stop gracefully — calls in
  /// flight are answered, live sockets close with "server stopping" and
  /// reconnect to the new one.
  ///
  /// The proxy re-resolves the service every few seconds and retries a
  /// refused connection on the other address (see the rendered `nginx.conf`),
  /// so no request meets the change as a `502`. The price is a few seconds in
  /// which both versions run: the previous code on the new schema, which is
  /// what the migration rule asks a release to allow anyway (expand, then
  /// contract), each taking only the jobs it declares. A publication by a
  /// command on one reaches the live sockets of that one; the sockets of the
  /// other reconnect within seconds and re-read everything they watch.
  ///
  /// When the migrations fail (they roll back) or the new server does not
  /// become healthy, the previous server is still serving, and the step fails
  /// with the server's own words. A server that failed after its migrations
  /// applied leaves the previous code on the new schema, which the message
  /// says. With nothing serving before — a first deploy, a stand that was
  /// down — the new server simply starts, and on a failure the previous image
  /// is started again.
  Future<DwSshResult> replaceServer() => _as(
    _replaceScript(
      DwStack.serverService,
      'server',
      migrate:
          '''
if ! ${DwComposeFiles.invoke} run --rm --no-deps -T -e ${DwStack.migrateOnlyVariable}=true ${DwStack.serverService} </dev/null; then
  echo "ERROR: the new image could not apply its migrations (the log is above); they rolled back" >&2
  dw_fall_back
  exit 1
fi''',
    ),
  );

  /// Replaces the web app the same way as the server ([replaceServer]),
  /// without the migrations: the new image beside the serving one, healthy
  /// first, the previous one stopped after it.
  Future<DwSshResult> startWeb() =>
      _as(_replaceScript(DwStack.webService, 'web app'));

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

  /// Why a stack that came up is still not fit to have its proxy reloaded.
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
        'no such service. Reloading nginx now would make it refuse that '
        'configuration, and the next start of the proxy — a reboot, a '
        'recreated container — would refuse to start on it, taking the whole '
        'stand down. Nothing has been reloaded.';
  }

  /// `nginx -t` inside the running proxy, on the stack's network: the syntax,
  /// the certificate files, and every upstream name resolved by the DNS the
  /// reloaded proxy will use.
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
  /// alone, which keeps a routine deploy off the rate limit. A failed first
  /// issuance puts the bootstrap certificate back: nginx reads its
  /// certificate at every start, and one with none to read does not start
  /// (#436).
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
  /// the stack has started a proxy, before nginx is reloaded to read what
  /// was issued. On a routine deploy the second run finds every host covered
  /// and asks nothing.
  Future<DwSshResult> issueCertificate({bool throughServingProxy = false}) {
    final certName = target.apiDomain;
    final domains = target.servedDomains
        .map((domain) => "-d '$domain'")
        .join(' ');
    final live = '/etc/letsencrypt/live/$certName';
    final archive = '/etc/letsencrypt/archive/$certName';
    final renewal = '/etc/letsencrypt/renewal/$certName.conf';
    // Beside the lineage, on the same volume, where certbot looks for nothing.
    const stashes = '/etc/letsencrypt/dw-bootstrap';
    final stash = '$stashes/$certName';
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
  # directory is exactly what the bootstrap step created. It is moved aside
  # (a rename: the same volume) and put back when no certificate replaces it,
  # so that a failed issuance still leaves nginx a certificate to start with.
  # A stash beside a live directory holding no certificate is an earlier run
  # stopped before it put the bootstrap back.
  if [ -d $stash ] && [ ! -e $live/fullchain.pem ]; then rm -rf $live; mv $stash $live; fi
  rm -rf $stash $archive $renewal
  if [ -d $live ]; then
    mkdir -p $stashes
    mv $live $stash
  fi
  if ! $request; then
    if [ -s $renewal ] && [ -r $live/fullchain.pem ]; then
      rm -rf $stash
      echo 'ERROR: certbot failed after issuing $certName; the issued certificate is kept' >&2
      exit 1
    fi
    rm -rf $live $archive $renewal
    if [ -d $stash ]; then
      mv $stash $live
      echo 'ERROR: issuance failed; the self-signed certificate is back in place' >&2
    else
      echo 'ERROR: issuance failed' >&2
    fi
    exit 1
  fi
  rm -rf $stash
" </dev/null
''');
  }

  /// Makes the running proxy read the rendered configuration and the
  /// certificate: a graceful reload, in which the old workers finish what
  /// they serve and new ones take every new connection — a restart would
  /// refuse connections while the proxy is down. The upstreams follow the
  /// replaced containers by themselves (they are re-resolved, see the
  /// rendered `nginx.conf`); the reload is for what this deploy rendered.
  ///
  /// The outcome is read, not assumed: `nginx -s reload` exits 0 having only
  /// sent a signal, and a master that rejects the configuration keeps the
  /// old one and says so only in its log.
  Future<DwSshResult> reloadProxy() => _as('''
set -e
cd '$appDir'
${DwComposeFiles.selectFiles}
cid=\$(${DwComposeFiles.invoke} ps -q ${DwStack.nginxService})
[ -n "\$cid" ] || { echo "ERROR: there is no nginx container to reload" >&2; exit 1; }
# Compared with the count before, not with zero: a proxy that crash-looped once
# last month is not a failure of this deploy.
before=\$(docker inspect -f '{{.RestartCount}}' "\$cid")
since=\$(date +%s)
${DwComposeFiles.invoke} exec -T ${DwStack.nginxService} nginx -s reload
sleep 3
state=\$(docker inspect -f '{{.State.Status}} {{.RestartCount}}' "\$cid")
if [ "\$state" != "running \$before" ]; then
  echo "ERROR: nginx is not running after the reload (\$state). Its log:" >&2
  docker logs --tail 50 "\$cid" >&2 2>&1 || true
  exit 1
fi
refused=\$(docker logs --since "\$since" "\$cid" 2>&1 | grep -E '\\[(emerg|alert)\\]' || true)
if [ -n "\$refused" ]; then
  echo "ERROR: nginx refused the configuration and keeps serving the previous one:" >&2
  printf '%s\\n' "\$refused" >&2
  exit 1
fi
echo "nginx reloaded its configuration and is running"
''');

  Future<DwSshResult> status() =>
      _compose("ps --format '{{.Name}}\t{{.Status}}'");

  List<DwDeployStep> steps({
    required bool skipGitUpdate,
    bool skipBackup = false,
    String? revision,
    Future<DwSshResult> Function()? verifyOutside,
  }) => [
    for (final step in _plannedSteps(
      skipGitUpdate: skipGitUpdate,
      skipBackup: skipBackup,
      revision: revision,
      verifyOutside: verifyOutside,
    ))
      DwDeployStep(
        id: step.id,
        title: step.title,
        showOutput: step.showOutput,
        verdict: step.verdict,
        run: () async {
          // Outside verification includes read-only status calls. Only its
          // final result is journalled, after the probes have answered.
          _step = step.id == 'verify-outside' ? null : step.id;
          try {
            return await step.run();
          } finally {
            _step = null;
          }
        },
      ),
  ];

  List<DwDeployStep> _plannedSteps({
    required bool skipGitUpdate,
    bool skipBackup = false,
    String? revision,
    Future<DwSshResult> Function()? verifyOutside,
  }) => [
    if (!skipGitUpdate)
      DwDeployStep(
        id: 'update-checkout',
        title: revision == null
            ? 'Update the checkout to origin/${target.branch}'
            : 'Update the checkout to revision $revision',
        run: () => updateCheckout(revision),
        verdict: revision == null
            ? null
            : (result) {
                final head = result.stdout.trim().split('\n').last;
                return RegExp(r'^[0-9a-f]{40,64}$').hasMatch(head) &&
                        head.toLowerCase().startsWith(revision.toLowerCase())
                    ? null
                    : 'Expected checkout HEAD to be revision $revision, got ${head.isEmpty ? 'no revision' : head}.';
              },
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
      showOutput: true,
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
    if (target.environment == 'production' &&
        (target.backup != null || skipBackup))
      DwDeployStep(
        id: skipBackup ? 'backup-skipped' : 'pre-deploy-backup',
        title: skipBackup
            ? 'Record explicit pre-deploy backup skip'
            : 'Dump, encrypt and upload the database before migrations',
        run: () => _as(
          skipBackup
              ? "echo 'PRE-DEPLOY BACKUP SKIPPED BY --skip-backup'"
              : "'${target.runtimeConfigDir}/backup' pre-deploy \$(git -C '$appDir' rev-parse --short HEAD)",
        ),
        showOutput: true,
      ),
    DwDeployStep(
      id: 'server',
      title:
          'Replace the server: migrate, start the new one beside the serving '
          'one, stop the old after it (the previous one serves on a failure)',
      run: replaceServer,
      showOutput: true,
    ),
    DwDeployStep(
      id: 'web',
      title: 'Replace the web app beside the serving one',
      run: startWeb,
    ),
    DwDeployStep(
      id: 'stack',
      title: 'Converge the rest of the stack',
      run: startStack,
    ),
    // Between the stack coming up and the reload, and it has to be exactly
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
      id: 'reload-proxy',
      title: 'Reload nginx onto the rendered configuration',
      run: reloadProxy,
    ),
    DwDeployStep(
      id: 'verify-outside',
      title: 'Verify from outside',
      run:
          verifyOutside ??
          () async {
            final results = await verifyFromOutside();
            final code = results.every((result) => result.passed) ? 0 : 1;
            if (remote case final detached?)
              return detached.run('verify-outside', 'exit $code');
            return ssh.runAs(target.deployUser, 'exit $code');
          },
    ),
    cleanupStep,
  ];

  /// Runs only after outside verification has succeeded.
  DwDeployStep get cleanupStep => DwDeployStep(
    id: 'cleanup',
    title: 'Clean unused stack images and trim the build cache',
    run: () {
      _step = 'cleanup';
      return cleanup();
    },
  );

  /// Removes only this stack's built server and web images. Docker refuses
  /// removal if a container starts using an image between listing and removal.
  /// Image removal comes first: containerd's BuildKit records share snapshots
  /// with exported images, so those references must go before pruning cache.
  Future<DwSshResult> cleanup() => _as("""
set -e
cd '$appDir'
$dwDiskSpaceFunction
$dwDockerRootScript
space=\$(dw_disk_space "\$dw_docker_root" '${stack.resolvedImage(DwStack.postgresImage)}')
before=\$(printf '%s\\n' "\$space" | awk '{print \$3}')
# One line per cache record: whether it is shared with an image, and its size.
dw_cache_stats() {
  docker system df -v --format '{{range .BuildCache}}{{.Shared}} {{.Size}}{{println}}{{end}}'
}
# Bytes of the records whose sharing is \$2 (true or false).
dw_cache_bytes() {
  printf '%s\\n' "\$1" | awk -v shared="\$2" '
    BEGIN {units["B"]=1; units["kB"]=1000; units["MB"]=1000000; units["GB"]=1000000000; units["TB"]=1000000000000}
    NF {
      if (\$1 != "true" && \$1 != "false") exit 1
      size=\$2; value=size+0; sub(/^[0-9.]+/, "", size)
      if (!(size in units)) exit 1
      if (\$1 == shared) total+=value*units[size]
    } END {printf "%.0f\\n", total}'
}
dw_cache_count() {
  printf '%s\\n' "\$1" | awk 'NF {count++} END {print count+0}'
}
cache=\$(dw_cache_stats)
cache_before=\$(dw_cache_count "\$cache")
removed=0
code=0
keep=" "
for service in ${DwStack.serverService} ${DwStack.webService}; do
  # A missing journal means we cannot know which image is the rollback
  # target. Refuse cleanup rather than guessing from creation timestamps.
  [ -f '$_journalDirectory/'"\$service.previous" ] || { echo "Missing rollback image record for \$service" >&2; exit 1; }
  keep="\$keep\$(cat '$_journalDirectory/'"\$service.previous") "
done
for service in ${DwStack.serverService} ${DwStack.webService}; do
  labelled=\$(docker image ls -a -q --no-trunc --filter 'label=com.docker.compose.project=${target.projectName}' --filter "label=com.docker.compose.service=\$service")
  named=\$(docker image ls -a -q --no-trunc --filter "reference=${target.projectName}-\$service:*")
  candidates=\$(printf '%s\\n' \$labelled \$named | sort -u)
  for image in \$candidates; do
    case "\$keep" in *" \$image "*) continue ;; esac
    identity=\$(docker image inspect -f '{{if .Config.Labels}}{{index .Config.Labels "com.docker.compose.project"}},{{index .Config.Labels "com.docker.compose.service"}}{{end}}' "\$image")
    owner=\${identity%%,*}
    image_service=\${identity#*,}
    case "\$owner" in ''|'${target.projectName}') ;; *) continue ;; esac
    case "\$image_service" in ''|${DwStack.serverService}|${DwStack.webService}) ;; *) continue ;; esac
    used=\$(docker ps -aq --filter "ancestor=\$image")
    [ -z "\$used" ] || continue
    if docker image rm "\$image" >/dev/null; then removed=\$((removed + 1)); else code=1; fi
  done
done
# The daemon's docker driver builds Compose images; this command prunes that
# same builder, independent of a user's selected buildx builder.
# Every prune uses the configured budget. Keep shared cache keys for images
# which remain on the daemon, so an unchanged build can reuse their layers.
docker builder prune -a -f --keep-storage '${target.buildCacheKeep}' >'$_journalDirectory/cleanup-prune.out' || code=1
cache=\$(dw_cache_stats)
cache_after=\$(dw_cache_count "\$cache")
# The budget limits the records no kept image shares. Shared records belong
# to images on the daemon, and pruning cannot reclaim them while they remain.
cache_private=\$(dw_cache_bytes "\$cache" false)
cache_shared=\$(dw_cache_bytes "\$cache" true)
if [ "\$cache_private" -gt ${target.buildCacheKeepBytes} ]; then
  echo "Build cache not shared with kept images remains above ${target.buildCacheKeep}: \$cache_private bytes; Docker retains cache references. Inspect docker buildx du --builder default --verbose." >&2
  code=1
fi
cache_removed=\$((cache_before - cache_after))
[ "\$cache_removed" -ge 0 ] || cache_removed=0
space=\$(dw_disk_space "\$dw_docker_root" '${stack.resolvedImage(DwStack.postgresImage)}')
after=\$(printf '%s\\n' "\$space" | awk '{print \$3}')
bytes=\$(((after - before) * 1024))
[ "\$bytes" -ge 0 ] || bytes=0
printf '{"images_removed":%s,"cache_records_removed":%s,"freed_bytes":%s,"cache_shared_bytes":%s}\\n' "\$removed" "\$cache_removed" "\$bytes" "\$cache_shared"
exit "\$code"
""");

  /// The single result line of cleanup, also used by JSON progress.
  static Map<String, Object?>? cleanupReport(DwSshResult result) {
    for (final line in result.stdout.split('\n').reversed) {
      if (!line.startsWith('{')) continue;
      try {
        final decoded = jsonDecode(line);
        if (decoded is Map<String, dynamic> &&
            [
              'images_removed',
              'cache_records_removed',
              'freed_bytes',
              'cache_shared_bytes',
            ].every(
              (key) => decoded[key] is int && (decoded[key] as int) >= 0,
            )) {
          return decoded;
        }
      } on FormatException {
        return null;
      }
    }
    return null;
  }

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
