# Deployment probe for #505

Throwaway experiment on `probe/kamal`, based on framework master
`0820447be7d6a58b03e0ff6eb6a3c4e2c0f2e49f`. No framework implementation changes.
The draft PR and the result comment on #505 are the handoff; this branch must not merge.

Only `82.26.151.195` is an authorized target. DNS was checked against
`ns1.reg.ru`. Secrets and full logs stay on that server or in the ignored
`.probe-private/` directory. No workstation daemon restart, other server,
live project, DNS change, or GitHub repository creation is part of this probe.

## Files

- `baseline.yaml`: deployment configuration for a `dartway create probe_dw`
  project. `registry.probe.stageserver.ru` temporarily serves bundled RustFS
  during the baseline; it is released before the registry phase.
- `dw`: runs the unchanged CLI sources of this worktree with the private pinned
  FVM SDK and an isolated package configuration. `sync_source.sh` updates the
  throwaway server-local bare Git upstream; no GitHub project is needed.
- `measure.py`: times a command, records its exit, and makes one external curl
  request per second per supplied URL. The curl timeout is 0.9 seconds. Counts
  are observations at that sampling rate, not exact outage durations.
- `authenticate.py`, `live_probe.dart`: log-only sign-in to the disposable
  template and a real native DartWay client listening to its profile channel.
  The author issues sequential profile commands; HTTP retries pause publication
  while the API is unavailable. This does not prove replay from an independent
  database publisher.
- `add_column.dart`, `fail_migration.dart`: migration inputs copied into the
  created project and sealed with `bin/migrate.dart rehash` before building.
- `node/`: React/Vite + Express and its own Postgres. Its Compose stack is
  separate. The baseline Nginx snippet joins the two projects at the shared
  front proxy. Setup expands the certificate to all five provided names.
- `self-deploy.Dockerfile.patch`, `self-deploy.override.yml`, `self-redeploy.sh`:
  self-deploy instrumentation. The running server image carries a compiled
  copy of the unchanged CLI and OpenSSH; a server-generated key and source
  checkout are mounted read-only. The global Mac key is never copied there.
- `ssh-drop.sh`, `drop_ssh.py`: kill only the descendant SSH process of the
  observed probe CLI. The recorded G interruption hit `bridge-override`:
  the original observer matched the build entry in the initial step catalog.
  The helper now requires a build `step_started` event; that observer correction
  has syntax validation only. The G Dockerfile adds `RUN sleep 12` before its
  runtime stage; this pause was reached on the successful rerun.
- `disk-fill.sh`, `disk-full.sh`: fill the authorized target during an observed
  `sleep 31` process in the build, then free the filler. The I Dockerfile adds
  `RUN sleep 31 && dd if=/dev/zero of=/probe-disk-layer bs=1048576 count=200`
  to its runtime stage. A detached 180-second watchdog also removes each
  uniquely named filler.
- `rollback-baseline.sh`: attempt the previous immutable image ID; this is an
  explicit Docker procedure, since the current CLI has no rollback command.
- `snapshot.sh`: capture image, container, cache, and filesystem usage.
- `kamal-{api,web,node}.yml`, `web-proxy.conf`: candidate Kamal layer, with
  separate service identities, boot-time migrations in the template binary,
  loopback accessory ports, root SSH, and proxy v0.10.2. These are not evidence
  of a successful Kamal deployment. Add the web snippet to the generated
  project's existing Nginx server block before building its web image.
- `registry.compose.yml`, `registry-nginx.conf`, `prepare-registry.sh`:
  standalone TLS/basic-auth registry bootstrap after baseline removal.
- `otel_receiver.py`: loopback OTLP JSON collector. `kamal` uses the private
  Ruby gem installation; Kamal is pinned to 2.12.0.
- `evidence/`: sanitized measurements and native-client counts. Credentials
  and complete logs are deliberately outside Git.

## Build boundary

The baseline uses the normal target-side `dartway deploy run` build. Kamal
requires images built **off the target**, pushed to the TLS registry, followed
by `kamal deploy --skip-push --version <sha>`. Do not substitute a target-side
build when the Mac Docker engine is unavailable. Mark dependent gates not run.

The registry bootstrap binds host ports 80/443. A complete Kamal run would
hand those ports to kamal-proxy and route the registry gateway through it,
including separate public/private RustFS bucket paths. That handoff is not
validated by the bootstrap or the candidate configs.

Configuration references: [Kamal deploy](https://kamal-deploy.org/docs/commands/deploy/)
and [proxy configuration](https://kamal-deploy.org/docs/configuration/proxy/).
