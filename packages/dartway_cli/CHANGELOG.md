# Changelog

## 0.13.0

- **BREAKING: the bundled storage is RustFS, not MinIO — `storage: minio` in `deploy/config.yaml`
  becomes `storage: bundled`** (dartway/dartway#331, D-094). MinIO's community edition stopped
  publishing images, and every registry that used to serve them (Docker Hub, quay.io) now answers an
  anonymous pull with `401`; `dartway deploy run` failed on a fresh host at the step that started it,
  and `dartway test`/`dartway_core_server`'s file suites failed the same way on a clean machine. The
  rendered compose services are renamed `storage`/`storage-init` (were `minio`/`minio-init`), the
  data volume is renamed `<project>_storage_data`, and `storage-init` is a generic, pinned S3 client
  (`amazon/aws-cli:2.31.13`) rather than MinIO's own — it sets bucket CORS through the S3 API
  (`put-bucket-cors`) on both buckets instead of the server-wide environment variable MinIO's
  community edition needed in its place. Migration note:
  `docs/migrations/2026-09-26-storage-minio-to-rustfs.md`.
- **`dartway deploy check` resolves every pinned base image against its registry** (`images-resolve`,
  new remote check): a manifest `HEAD`, with the anonymous bearer token the registry's own
  `WWW-Authenticate` challenge asks for — the same handshake `docker pull` performs, without pulling
  a layer. Catches a vanished tag (Postgres, nginx, certbot, and with `storage: bundled` the storage
  and its init image) before `deploy run` reaches the step that actually pulls it, which is where
  this exact failure used to surface for MinIO, well after the images that build locally had already
  succeeded.

## 0.12.0

- **BREAKING: `dartway check` holds the server's `lib/src/` to a layout** (D-093, `invalidTopLevelLayout`): folders only — `core/`, `migrations/`, and one per feature declaring its `DwServerFeature` in `<feature>_feature.dart`. A file at the top of `src/`, a layer folder (`handlers/`, `rows/`, `entities/`, `domain/`, `objects/`, `publications/`, `services/`, `models/`) or a feature folder without its declaration is an error. `src/` used to be "the project's": three projects on the framework arranged it three ways, and the largest arranged it two ways at once, with one area in four folders. The skeleton `dartway create` hands out has the layout. Migration note: `docs/migrations/2026-09-25-server-features.md`.
- **`readFrameworkVersions` and `frameworkPackageDirectories` walk `packages/` one level deep, not two.** `packages/` has been flat since the 1.0 rewrite; the leftover second level silently read a package's own `example/` (`dartway_core_flutter_example`, `dartway_lints_example`) as a framework package in its own right, which `dartway update`'s framework-gap report and `--framework-path` both then acted on. Neither exists as a `dartway_*` release.
- **`dartway update`'s migration notes sort by the version they land in, then by name — the file's date decides between two different days, not the version.** Sorting by file name put same-day notes out of order (2026-09-24's `account-deletion-choice` printed before `contract-version`, though it lands later); sorting by raw version across every note put a satellite's small number (`dartway_lints` `0.4.0`) ahead of an earlier family note (`0.20.0-dev.2`) that has nothing to do with it. Now: the file's date first, then — only for two notes of the same day naming a package in common — the version that package lands at, then the file name.
- **Retired the 0.x-era `setup-ai`/`update` recognition that no rewrite project can still trigger**: the `dartway-audit.md` command-retirement entry, the report of root `dartway_notes.md`/`dev_notes.md` journals and of `tools/dw_claude_setup/` leftovers from the pre-CLI shell installer.

## 0.11.1

- **The toolkit's resident `CLAUDE.md` is half its size** (#281): 7 400 words paid in every session of every project become 3 450. The laws stay resident; what only one kind of task needs moves to skills loaded on demand — `dartway-documentation` (specs, ADRs, dev notes), `dartway-framework-notes` (filing a finding upstream), the old shapes into `dartway-update`, localization in full into `dartway-ui-kit` — each with a resident line saying when to load it.
- **`dartway create` pins the `dartway_lints` analyzer plugin** (#295): the skeleton enables it under `plugins:` in the Flutter package's `analysis_options.yaml` by a path into this repository, which `create` replaces with the version the template was taken from — or the checkout's path with `--framework-path`. The skeleton no longer depends on `custom_lint` or `dartway_lints`.
- **The toolkit teaches the CLI a project pins** (#289). 133 command blocks in `toolkit/` and the skeleton's README wrote `dartway generate|check|test|deploy|dev|stats`, the form those commands refuse from any `dartway` but the pinned one since 0.10.1; they now write `dart run dartway_cli:dartway <command>`, run in the Flutter package, and `toolkit/CLAUDE.md` says so once. The public documentation (`docs/`, 97 more) is rewritten the same way. `toolkit_pinned_commands_test.dart` fails on a bare one in code — in the toolkit, the skeleton's README and `docs/` — against the CLI's own list of project commands (`DwPinnedCli.projectCommands`).
- **`dart run dartway_cli:dartway test` runs from the Flutter package** (#289): it read only the working directory and answered that there was no `*_server` package — in the one place the pinned form runs.
- **`By check` counts every section** (#287). The tally belonged to the Flutter section and left out what the sections before it found: a layout error was shown and counted in `Errors: 4`, while the tally named three. It is now printed by the command over all of them, and a tally that disagrees with the error count stops the check as a bug in it. The generated-code section's fix names the pinned command too.
- **The web image installs the Flutter the project's `.fvmrc` names** (D-082). The skeleton's build stage cloned nothing and started `FROM ghcr.io/cirruslabs/flutter:3.44.0`, while the skeleton pins 3.47.2, which no image publishes: Flutter pins some of the packages an app resolves, so the image's `pub get --enforce-lockfile` refused every new project's lock. A new local check, `web-flutter-version` (error), compares an image built `FROM` a Flutter image with `.fvmrc`. Migration note: `docs/migrations/2026-09-23-web-image-flutter-from-fvmrc.md`.

- **The web image grants everyone read on the files it serves** (#292). The skeleton's `Dockerfile` runs `chmod -R a+rX build/web` after the build: `COPY` keeps modes, and under a deploy user's umask of `077` the assets a commit added were served as 403 while every page answered 200. A new local check, `web-file-modes` (warning), names a web image that leaves the modes to the build host. Migration note: `docs/migrations/2026-09-23-web-image-file-modes.md`.
- **Deploy ssh sessions notice a dead connection** (#286): every `ssh` and `scp` call opens with `ServerAliveInterval=30` and `ServerAliveCountMax=4`. A step is watched through one session that is silent while a web build runs; a NAT dropped it, and the CLI waited for an hour on a step that had long finished. A connection lost now ends within two minutes, and the watch reconnects and reads the step's result.
- **A project without `pubspec.lock` is told to resolve, not to edit its images** (#278). `locked-dependencies` said "add `--enforce-lockfile`" to a project whose Dockerfiles carry it — the first deploy of a project nobody has resolved yet, since `dartway create` does not copy the skeleton's lock. It now says to run `pub get` in both packages and commit the locks.
- **`dartway update` compares a framework package's pre-release correctly against the release it precedes.** `isAtLeastVersion` ignores a pre-release suffix entirely — right for an SDK check, wrong here: a project on `dartway_core_server` `0.20.0-dev.1` read as caught up with a channel already at `0.20.0`, and a migration note keyed to `0.20.0-dev.4` looked satisfied by every other `-dev.N` of that release. `isPackageAtLeastVersion` (`package:pub_semver`) is the comparison a package's own version needs: a pre-release sorts below the release it precedes, and its identifiers compare numerically (`dev.9` below `dev.10`), never as text (review of #308).

## 0.11.0 — DartWay 1.0

**Breaking:** `dartway deploy secret …` is now `dartway secret …` (D-078).

- **`doctor` asks for Flutter `>=3.44.0`** (#290), the minimum `dartway_core_flutter` compiles on.

- **`dartway quickstart` names `DW_ADMIN_IDENTIFIER`**, the framework's own name for the first administrator (D-079); the skeleton's `APP_BOOTSTRAP_ADMIN` is gone.

- **`local` is an environment of `deploy/config.yaml`, and `dartway secret` is a top-level command** (D-078). The two files that describe every environment now describe this machine too: `config.yaml > local` holds what the team shares, `secrets.yaml > local` what is the developer's own, and `dartway secret list --env local` answers "what is set, what is missing" in the same words it answers for a server. `dartway deploy secret …` is now `dartway secret …`, and `init`, `put-file`, `push` and `pull` say why they have nothing to do for `local`.

- **`requires` is read at the top level of `deploy/config.yaml`**, where it states what the project needs wherever it runs; an environment's own `requires` adds to it. The same list repeated per environment drifted in the one direction nobody notices — the environment that was forgotten is the one whose deploy stops.

- **Two advisory checks in `dartway check`**: `localSecretMissing` (a `requires` secret with no value for `local`) and `devComposeDrifted` (the development containers' credentials in `docker-compose.yaml` against the ones the server is told to reach them by — two files stating the same password, with nothing making them agree). `migrationsDrift` takes the same local environment, so it stops asking for a `DW_DATABASE_*` the project has already declared.

- **`deploy/config.yaml.example` is gone**: the skeleton ships `deploy/config.yaml` itself, with `local` filled in and a deployment commented out beside it. A new project runs before it has a server to deploy to, and one file is one file.

- **BEHAVIOUR (deploy): `deploy run` renders `docker-compose.yml` and `nginx.conf` on every run** (D-075), from `deploy/config.yaml` and the CLI's own version, saying of each whether it changed. They used to be written by `setup` alone, and a stack rendered by an older CLI met a build argument it did not carry: the deploy died inside `docker build` blaming the project's Dockerfile, while the file to fix was on the server and in no repository (reported by U90). A hand edit on a server is therefore overwritten — project additions belong in `deploy/compose.override.yml` and `deploy/nginx.d/`, which are not touched.

- **`deploy` and `deploy secret` find the project instead of demanding to be run from its root.** They read the working directory, so `dart run dartway_cli:dartway deploy …` — which runs from the package that pins the CLI — answered "no `*_server` package found" to somebody standing inside their own project (reported by Studio). They now walk up to the directory holding the `*_server` and `*_shared` packages, as `generate` and `check` already did.

- **`locked-dependencies` judges a package's own `pub get`, not a stage building something else.** A multi-stage Dockerfile that checks out another repository and builds it in its own `WORKDIR` had that `pub get` attributed to the project and checked against the project's lock file (reported by Studio). Instructions resolving elsewhere are now named in the verdict and not judged: another repository's lock is not this project's to check.

- **The web image is built with `STUDIO_APP_ORIGIN`** — the address it answers on, which the Studio binding checks a connecting Studio's token against. Projects kept it as a default in their Dockerfile, where a renamed stand makes it quietly wrong (reported by U90).

- **`deploy run --resume` no longer repeats a step that failed**: it stops with that step's recorded reason and output (`step_failed` with `resumed: true`), and `--retry-failed` is how to run it again. A self-deploy resumes after every interruption, so a failing step used to be repeated until the attempts ran out, stopping the server each time (reported by Studio).

- **The proxy and certbot images are pinned** (#269): `nginx:1.30.5-alpine`, `certbot/certbot:v5.8.0`, like Postgres and MinIO. A server set up earlier keeps the old names in its rendered `docker-compose.yml` until `deploy setup` renders it again.

- **BREAKING (deploy): the server is replaced one version at a time** (D-070). `deploy run` no longer starts the new server beside the serving one: the serving server stops gracefully, the new image migrates in a one-off run (`DW_MIGRATE_ONLY=true`), the new server starts; on a failure the previous image is started again. The gap is covered by the client's retries. Step `server-candidate` is gone; `server` does all of it.

- **`dartway check` holds the contract's names to the naming law** (`contractNameInvalid`, error — #167): a DTO in the shared package named one word, a read not named `Get…`/`List…`, or a command named like a read. The class name is the wire name, so the check fires before a build carries it. The example's `SearchChatMessages` is `ListChatMessagesMatching`.

- **`dartway create --language` sets the app's language** (#230). The project keeps only that translation (`en` or `ru`), makes it the template ARB and `AppLocaleController.productLocale`, and regenerates `lib/l10n/gen`. The skeleton no longer takes the device's language, and no longer falls back to whichever ARB sorts first.

- **A host added to a live stand gets into its certificate.** `deploy run` left a lineage certbot already managed untouched, so a `storage_domain` or `site` added later was served with a certificate that did not name it. The certificate step now reads the lineage's domains and extends it (`--expand`, same name) when a served host is missing.

- **MinIO comes from quay.io** (#264): MinIO removed `minio/minio` and `minio/mc` from Docker Hub, so every `storage: minio` deploy failed at the pull. Same releases, `quay.io/minio/…`; `dartway test` and the template's compose file follow. **`registry_mirror` now applies only to official Docker Hub images** (`postgres`, `nginx`): prefixed onto an image of another registry or a Hub organisation it named nothing. A server set up earlier keeps the old image names in its rendered `docker-compose.yml` until `dartway deploy setup` renders it again.

- **`dartway deploy run` survives the machine that started it** (D-068, #266). Every step runs on the server detached from the `ssh` session (`setsid`, streams and exit code in `~/.config/<project>/deploy-run/`); a broken connection is waited through for up to fifteen minutes. `--resume` finishes the deployment the server remembers — passing over done steps, waiting for a running one, running the rest — and a new run refuses while a step of the last one still runs. `--progress json` writes step events as JSON lines on stdout (prose on stderr). `now at` and the `revision` event are also reported with `--skip-git-update`.

- **`dartway check` names an override the framework caught up with** (`frameworkOverrideOutlived`, warning — D-032). A `dependency_overrides` version pin on a `dartway_*` package is reported when a resolved framework package depending on it already allows the locked version, with the file to edit; path and git overrides are left alone.

- **BREAKING: `dartway create` hands out the 1.0 skeleton.** Three packages — `*_shared` (the
  contract), `*_server` and `*_flutter`, no generated client package — with sign-in by a one-time
  code to a phone or an e-mail, the terms accepted on sign-up, a profile with a photo and its
  sign-in identifiers, roles, an admin panel with a members table and user cards, migrations, a
  dev seed and tests on both sides. Everything is named after the project: packages, types, the
  generated registry and schema (`dartwayStarter…` becomes `myApp…`) and the default storage
  buckets (`my-app-public`, `my-app-private`, as `dartway deploy` names them). The result is
  formatted, since the renames move line breaks. A project name must now also fit a bucket name:
  no leading, trailing or doubled underscore, at most 55 characters.

- **`dartway create --framework-path <monorepo>`** resolves the new project's framework packages
  from a local checkout by path — `dependency_overrides` onto `<monorepo>/packages` for exactly
  the packages each pubspec reaches — instead of pub.dev, and takes the template from the same
  checkout. For building the framework, and for versions not yet published.

- **`dartway deploy check` refuses a path dependency that leaves the project**
  (`dependencies-inside-context`, error). Images build from the project root, so a package taken
  by path from above it — a local framework checkout, the overrides `--framework-path` writes —
  resolves in every working copy and fails inside the image as `pub get` exit code 66. Read from
  `dependencies`, `dev_dependencies` and `dependency_overrides`, through sibling packages, and from
  `pubspec_overrides.yaml` unless `.dockerignore` keeps it out. `docker-context-packages` no longer
  also asks to `COPY` such a package. The template's and the example's `.dockerignore` keep
  `**/pubspec_overrides.yaml` out of images.

- **`dartway deploy setup` takes back a directory on the way to the secret store that the deploy
  user cannot write** — `~/.config` left as root's by an earlier tool — non-recursively and only
  inside the user's own home, and says so. It used to fail as "cannot change permissions … No such
  file or directory", naming neither the directory nor its owner; when the ownership cannot be
  changed, the failure now names both and the `chown` that fixes it.

- **`dartway create` records the language and the notes tracker it was given**, so the first
  `dartway update` keeps them instead of reinstalling the toolkit in the defaults.

- **BREAKING: a CLI with the framework beside it hands out its own revision.** `create`,
  `setup-ai` and `update` without a named checkout or a chosen channel (`--channel`,
  `DARTWAY_BRANCH`, or the channel a project recorded for `update`) take the template and the
  toolkit from the monorepo the CLI runs from — activated by path or by git ref, or run inside the
  monorepo — instead of cloning `stable`. The rewrite's CLI used to create 0.x projects that way.
  A CLI installed from pub.dev has nothing beside it and still takes `stable`. A project that
  recorded a channel is not moved onto the checkout by a plain `setup-ai`: it is refused, naming
  `--channel` and `--local-repo`.

- **BREAKING: the toolkit is installed whole or not at all.** `setup-ai`, `update` and `create`
  require a `*_shared` package beside `*_server` and `*_flutter`, and the installer no longer knows
  `__CLIENT_PKG__` (1.0 has no client package; it filled the token with an empty string, and an
  older toolkit's skills then named `..//lib/src/protocol`). Before writing anything the installer
  reads the toolkit and refuses one holding a token it does not fill, or would fill with nothing,
  naming each token and its file.

- **`dartway test` starts a MinIO beside the Postgres** (`DW_STORAGE_ENDPOINT`/`_ACCESS_KEY`/
  `_SECRET_KEY`, the image a deployment runs, in memory, on a port Docker picks) so upload
  suites run like the database ones. `--no-storage` skips it; `--storage-image` picks the image.

- **BREAKING: `dartway check` judges a 1.0 project.** Removed with the Serverpod core:
  `crudConfigMissing`, `crudConfigUnregistered`, `crudRuleUntested` (there are no CRUD configs)
  and `generatedCodeUnformatted` (the generator formats its own output). Added:
  `generatedCodeStale` (error) runs the project's `dartway_generator --check`, and
  `migrationsDrift` (error) runs `bin/migrate.dart check` when `DW_DATABASE_*` names a Postgres —
  without one it says it did not run. The server layout rule now expects `lib/<package>.dart`,
  `lib/generated/` and `lib/src/` with `src/migrations/migrations.dart`, instead of the 0.x
  `server.dart` and `crud`/`endpoints`/`models` areas. `toolkit_law_list_test` is skipped until the
  toolkit is rewritten for 1.0 (D-033): its law table still names the removed checks.

- **`dartway quickstart` and `dartway doctor` describe 1.0**: the server configured by its
  environment and migrating as it starts, Postgres and MinIO from `docker compose`, the dev seed,
  `APP_BOOTSTRAP_ADMIN`, `dartway dev web` for the browser, and the checks a change passes.

- **BREAKING: `dartway deploy` deploys the 1.0 stack, and nothing of Serverpod is left in it.**
  One server process configured by its environment alone, behind one front proxy serving three
  hosts (R2.7): `app` — the Flutter web image, with `/dw/` (the `/dw/live` WebSocket upgrade
  included) and `/health` proxied to the server on the same origin; `api` — the server for mobile
  apps and webhooks; and an optional static `site`. Postgres 17, an optional MinIO with its bucket
  and the CORS rule a browser needs for a presigned PUT, certbot. The Serverpod configuration
  reader, `passwords.yaml`, the insights and web-server ports, Redis and the migration-output
  parser are gone.

  `deploy/config.yaml` describes the whole environment — `api_domain`, `app_domain`, `site`,
  `storage: minio|external` with `storage_domain` — and refuses a key it does not know, so an
  older config fails naming `web_app_domain` rather than deploying without it. Every problem is
  reported at once.

- **The secret store is an environment file.** `~/.config/<project>/secrets.env` on the server,
  `KEY='value'` lines Compose takes literally. Every deploy renders the checkout's `.env` from it
  and refuses — by key name, never by value — a missing or empty required secret, a malformed
  line, a duplicate, or a name the compose file sets itself and would silently override.
  `secret init` generates `DW_DATABASE_PASSWORD` (and the MinIO keys); `set`, `list`, `put-file`,
  `push` and `pull` keep their shape, the last two against a git-ignored `deploy/secrets.yaml`.
  Secret files are mounted at `/run/secrets/<name>`.

- **The migration outcome is the server's exit.** The server applies its migrations as it starts
  and exits non-zero when one fails, so `run` starts the new image *beside* the serving one and
  waits for `/health`; an exit prints the server's own log and stops the deploy with the previous
  version still answering. Only then is the server replaced, and waited for.

- **`run` ends by asking from outside**, with the same probes `deploy check` uses: `/health` 200
  through both hosts, the Flutter `index.html` on the app host with a revalidating cache policy,
  the cache policy of the build's entry points, `/dw/live` upgrading through both hosts with the
  server answering on the socket, the site, and the storage preflight from the app's origin.
  Before the proxy restart it compares every upstream of the rendered configuration and the
  snippets with the applied stack, runs `nginx -t` inside the running proxy, and after the
  restart checks the proxy is still running.

- **New local checks**: the server image receives SIGTERM itself (exec-form `ENTRYPOINT`); the web
  image declares `ARG DW_BACKEND_URL`; a deployed site directory is committed; required secret
  names are not ones the compose file sets. `.dockerignore` may admit packages by role glob
  (`!*_server/`), and the template and example ignore files do — they no longer restate the package
  list. The example's ignore file had admitted a package that no longer exists and kept out the
  shared one both its images copy.

- **A local proof of the whole deployment**: `dart test -t docker --run-skipped
  test/deploy_local_stack_test.dart` renders the example's stack in plain-HTTP mode, runs the
  deploy steps through a local shell, and verifies it — a real sign-in and DTO call through both
  hosts, a presigned upload through the storage host, a failing candidate that leaves the
  running server serving, and a graceful stop.

- **`dartway test` passes `DW_DATABASE_*`** (the maintenance database, TLS off) to the suite;
  `doctor` no longer checks a Serverpod CLI; `create` no longer writes a `passwords.yaml`; a
  project needs no `*_client` package to be recognised.

- **`dartway dev` — the web app and the server on one origin, as deployed (D-039).** `dev proxy`
  serves `http://localhost:8000`: `/dw/*` (the `/dw/live` socket included) and `/health` to the
  server, everything else to a Flutter web dev server (`--web`) or a build (`--web-dir`, with the
  `index.html` fallback and the `Cache-Control` of the project's web image `nginx.conf`). `dev web`
  runs `flutter run -d web-server` compiled against that origin with the proxy in front, and stops
  both together. The browser's `Host` is passed on as the deployed Nginx passes it, so the live
  socket's origin check passes without `DW_ALLOWED_ORIGINS`; sockets — the live one and Flutter's
  hot-reload one — are tunnelled as bytes, close codes included, and responses stream unbuffered.
  Replaces the proxy each project wrote for itself.
