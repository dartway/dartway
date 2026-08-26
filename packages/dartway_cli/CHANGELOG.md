# Changelog

## 0.9.0

- **`doctor` checks the two prerequisites that used to let a machine through and then stop it dead:
  the route to the pub host, and a git identity.**

  Doctor's promise is that a machine can create and run a project. It was possible for it to report
  one problem, have that fixed, and then hand over to a `dart pub get` that hung for an hour: pub
  sets no deadline on a connection that opens and then goes quiet, so a filtered or throttled route
  to pub.dev surfaces as a resolve step printing one line and nothing after it, with no error, no
  progress and no exit. That is the worst shape a prerequisite failure can take, and it is one
  request to rule out. The check asks the pub host for bytes rather than for a socket — a TCP
  connect succeeds even when the handshake after it is being filtered — honours `PUB_HOSTED_URL` so
  it probes whatever pub itself would talk to, gives up after ten seconds and fails, since a machine
  that cannot fetch packages cannot create or run anything.

  The git half is a warning, not a failure. `create` clones the template with git and then commits
  the result, and with no `user.name`/`user.email` that commit fails: the project is complete and
  usable, but its repository has no initial commit, and the reason arrives as a wall of git's own
  text in the machine's locale in the middle of otherwise successful output. Doctor now names the
  two config commands up front. A missing git binary is a failure — the clone needs it.

## 0.8.0

- **The two git-ignored journals are retired; the project's own findings become `docs/dev_notes/`,
  tracked.** The installer no longer writes anything to the project root and no longer edits
  `.gitignore`.

  Being ignored is what broke them. A finding written into `dartway_notes.md` or `dev_notes.md` never
  travelled out in a pull request, never appeared in review, and `git worktree remove` deleted it
  without a word — `git status` says nothing about ignored files, so a worktree holding a day's
  findings looks clean. On one project five framework findings and one project finding had to be
  pulled out of throwaway working copies by hand before they were deleted, while three more copies
  held nothing but the empty template the installer had just put there.

  What replaces them:

  - **A finding about the framework is filed straight as an issue** in the repository
    `--notes-tracker` names. There is no local file in between and no step where somebody remembers
    to carry entries over — which finishes what `--notes-tracker` started, since a filed entry
    already carried an address and kept no status of its own.
  - **A finding of the project's own is one file under `docs/dev_notes/`**, committed like anything
    else. One file per finding rather than one appended to: parallel branches appending to a single
    journal conflict on the same lines in every second pull request, while separate files have
    nothing to conflict on and a finished one is deleted whole.
  - **A finding that belongs to one feature is unchanged** — a line in that feature's `knownIssues`.
    The boundary between the three is written down once, in the installed `CLAUDE.md`: the test is
    whether the finding has an address in code.

  `setup-ai` creates two files there. `README.md` states the entry form and is **refreshed on every
  install**, since it holds nothing of the project's to lose. `_coverage.md` — the table
  `/dartway-checkup` keeps of which features it has read properly — is written **once and never
  overwritten**. Entries are never touched.

  A project still holding the old journals is **told, not edited**: they contain findings nobody else
  has a copy of, and an installer that deletes such a file is a different kind of tool. The migration
  entry in the installed `CLAUDE.md` says what to do with what has accumulated. Read them before
  anything else touches the working copy.

  Closes the way `setup-ai` inside a `git worktree` used to create empty look-alike journals: a
  tracked file in a worktree travels out through the pull request like any other, so there is nothing
  left to detect.

- **`dartway check` reads the server now, and names three things a project is missing.** Every one
  of them fails *closed*: the code compiles, the server starts, the migration applies, and the app
  quietly cannot do something.

  `crudConfigMissing` (warning) — a model with a table and no `DwCrudConfig`. Generic CRUD is secure
  by default, so an unconfigured model answers `notConfigured` to every read and write; the list is
  simply empty forever. A warning and not an error because the absence has a second, legitimate
  reading — a table the server owns alone — which the check cannot tell apart and you can.

  `crudConfigUnregistered` (error) — a config that exists and is not in the `crudConfigurations`
  list. The same failure with no second reading, and the one that hides best: the file is there, it
  has the access rules in it, it reviews as finished, and the API answers exactly as if it had never
  been written. Nothing else in the toolchain has an opinion — it compiles, and a config is a value
  nobody is obliged to use.

  `crudRuleUntested` (warning) — a config carrying hand-written save or delete logic that no test in
  the server package names. The rule runs inside a request and reads the database to decide, so no
  widget test can reach it; one proving the admin-only button is hidden proves only that.

  **None of the three counts anything** — each finding names one model and one thing to do. Two
  things the checker could have guessed at are deliberately absent for that reason: a Flutter
  feature's tests are not countable without becoming a coverage percentage, and an *Event model* is a
  domain reading with no marker in the YAML (a rule keyed off an `*Event` suffix would miss the one
  called `BalanceEntry` and fire on a lookup table).

- **The migration step of a deploy can now report its outcome, and until now it could not.** It
  printed its title and nothing else, because a step's output was shown only when its exit code was
  non-zero — and this particular exit code answers a different question. Serverpod wraps the whole
  apply in a `try`/`catch`: a failure sets `verified = false`, and `verified` aborts the process
  **only in development**. Outside it the failure is swallowed, the maintenance role ends with
  `throw ExitException(_exitCode)` having never touched `_exitCode`, and a container that applied
  nothing exits 0 exactly like one that applied everything. So the deploy reported success for work
  it did not do: the application went on running new code against an old schema, nothing in the log
  mentioned it, and re-running produced the same green step and the same broken schema — while the
  command's own help describes `deploy run` as "update, rebuild, migrate, restart".

  The step now prints the container's output whatever happened, and reads the outcome out of it.
  `Applied database migration:` with the versions it names, or `Latest database migration already
  applied.`, passes. `Failed to apply migration <version>.`, `Failed to apply database migrations.`
  and Serverpod's own `The database does not match the target database:` each fail it — the last
  being the case where nothing threw and the schema still did not catch up. So does silence: a
  container that exits 0 without mentioning the schema never reached the migration code, which is
  usually an `ENTRYPOINT` in shell form swallowing `--apply-migrations`. A failed step stops the
  deploy before `up`, so the previous version keeps serving while the reason — quoted, with what to
  run next — is read.

  The mechanism is a step-level one rather than a special case: `DwDeployStep` gained `showOutput`
  and `verdict`, so any step whose exit code and result can disagree says which text settles it.
  The Serverpod literals are pinned by tests, and a Serverpod that renames one turns the step silent
  rather than green.

  No `deploy check` assertion was added for the schema, deliberately. The authoritative comparison
  already runs inside the migration container — Serverpod checks the live schema against the target
  definition table by table on every maintenance start — and the fix was to stop discarding its
  verdict rather than to add a second one. Comparing `migration_registry.txt` against the
  `serverpod_migrations` table would compare two version strings rather than a schema, pass on a
  database whose row says the right version while a table is missing, and answer before the deploy
  had run: green exactly where the deploy is red.

- **The deploy templates now ship the configuration that serves a Flutter web build, and it caches
  by what is actually hashed.** Nothing was shipped before, so every project wrote its own, and what
  they wrote applied the rule everybody knows — "fingerprinted assets are immutable, cache them for
  a year" — to a build that fingerprints nothing. `index.html`, `flutter_bootstrap.js`, `flutter.js`,
  `main.dart.js`, `main.dart.wasm` and every file under `assets/` are named identically in every
  build, so the immutable rule landed on precisely the files that change on every deploy. A browser
  that took one under a long `max-age` never asks again: it goes on running the previous build while
  the server serves the new one. In the reported case the served bundle carried a newer bridge
  protocol and the browser ran the older one — half a day of diagnosis, and the expensive part was
  the silence, since every check anyone thought to run said the right thing.

  `<project>_flutter/nginx.conf` is now a file of its own beside the Dockerfile that copies it. It
  serves everything a build emits with `Cache-Control: no-cache` — the copy is kept and merely has
  to be confirmed, which with an ETag costs a 304 rather than a download — and keeps the long-lived,
  immutable rule for names that genuinely carry a content hash.

- **Two new assertions, and they ask different questions.** `web-cache-policy` (local, warning)
  reads the configuration the web image is built with — the file it copies, or a heredoc written
  straight into the Dockerfile, so a project that never split it out is judged too — resolves every
  Flutter entry point through Nginx's own `location` precedence, and reports the ones that would be
  served for reuse without revalidation. It warns rather than blocks, because reading configuration
  text can miss an `include` outside the build context or a header a front proxy adds.
  `web-cache-headers` (remote, error) asks the deployed site over HTTPS, exactly as a browser would,
  and judges the header it was actually handed; a path answering 404 is not part of that build and
  says nothing about caching. Neither is satisfied by a file being present — the failure this is
  about is a server serving the right thing to a browser that will not ask for it.

  Both spell out the half a fix does not cover: a browser already holding a copy taken under
  `max-age=2592000` stays that way for the rest of the thirty days, and no server-side change
  reaches it. Hard-reload for whoever you can reach; for the rest, wait the window out or move the
  app to a URL that was never poisoned.

- `requires.secrets` and `requires.files` are documented as a split by **shape**, not by importance:
  a short value is a password, a whole document is a file. `config.yaml.example` had been suggesting
  the opposite — `firebaseServiceAccountKey` under `secrets` — which is how a couple of thousand
  characters of service-account JSON end up in the master copy of every environment's secrets, where
  an unquoted leading `{` is read by YAML as a mapping rather than as text.

- **A file declared in `requires.files` is now mounted into the container, and `deploy check` asks
  whether the application can see it.** The mechanism was wired halfway: `secret put-file` delivered
  the file, `check` confirmed it was on the server, and the rendered compose file mounted exactly one
  thing — `passwords.yaml`. Twenty-one checks passed and the deploy died applying migrations, because
  the application could not find a file that was demonstrably on the machine. Every declared file is
  now mounted read-only at `/app/config/<name>` beside `passwords.yaml`, so the application reads it
  as `config/<name>`. An entry has to be a file name: a pattern is refused at render time rather than
  turned into a mount Docker takes literally and satisfies with a directory called `*.json`.

  The check changed with it, because the wrong question is the more expensive half. It used to ask
  "is the file on the server?" while the deploy dies on "can the application see it?", and a check
  that is green where the deploy is red is worse than no check — people read it and stop looking. It
  now asks the server for the configuration Compose will actually run (`docker compose config`, the
  rendered file merged with the project's override) and looks for the file's own path among the
  backend's mounts. It deliberately stops short of starting a container: `compose run` builds the
  image when it is absent, which would turn a check into a ten-minute build, and probing the
  container that happens to be up answers about the previous deploy rather than the one about to
  happen.

- **`run` no longer deploys a setup-time copy of the project's compose override.** `setup` used to
  copy `deploy/compose.override.yml` to `docker-compose.override.yml` next to the rendered file — the
  name Compose loads on its own — so that no later call had to remember a `-f` flag. There is nobody
  to forget it: every Compose invocation is built by the CLI in one place. The price was a second
  copy that a deploy silently preferred over the committed one, so a merged change to the override
  did nothing while the run printed the very commit that made it and the checkout on the server
  visibly held the new file. Compose is now given `-f docker-compose.yml -f deploy/compose.override.yml`,
  and the checkout — refreshed by the `git reset --hard` a deploy already performs — is the only copy.

  **A server that already has the copy gets it retired**, by `setup` and by `run` alike, since a
  leftover would otherwise be merged into every deploy forever and be harder to see than before. It
  is renamed to `docker-compose.override.yml.retired` rather than deleted: the file is normally a
  stale copy of a committed one and worth nothing, but a server may carry a hand edit made while
  debugging, and losing that silently would be its own bug. The step is idempotent and says nothing
  on a server that never had the copy.

- The comment the deploy template writes into a project's `docker-compose.yml` — the one
  explaining why `$$` is spelled that way — was in Russian, and it shipped into every
  generated file. It is in English now.

- **`--notes-tracker owner/repo`: the framework journal gets somewhere to go.** `dartway_notes.md`
  collects what the framework got wrong, and until now that was the end of it — the file is
  git-ignored and lives on one machine, so an entry travelled only when somebody remembered it. The
  transport was never the expensive half, though. One project's journal was carried over in full
  within a fortnight and still advertised eleven `open` findings afterwards, the entry asking for this
  very mechanism among them: the fixes landed in the monorepo and nothing wrote back. Given a tracker,
  a filed entry records `**Issue:** owner/repo#123` **instead of a status**, and the state is read
  from the tracker rather than restated in the file — a state written in two places is a state that
  goes stale in one of them without a sound, and on GitHub a pull request saying `Fixes #123` closes
  the loop without anyone's discipline.

  **It defaults to the framework's own tracker, and the default is the point.** Requiring the option
  would have made every project decide a question it has no particular reason to think about, and the
  projects that never got around to deciding are precisely the ones whose findings never left the
  laptop. It is still a repository slug rather than a hardcoded address: a company running DartWay
  internally may want its developers' findings triaged in its own tracker before any are offered
  upstream, and that should cost one option rather than an edit in every installed `.claude/`.
  `--notes-tracker none` opts out entirely, at which point the journal behaves exactly as before and no
  command reaches the network — a state reached deliberately, never by omission.

  What the installed `CLAUDE.md` now requires before an issue is created is the part that keeps the
  option honest: the entry restated so it stands without this codebase (paths, class names and the
  app's workaround are what make it useful locally and unpublishable), English instead of the
  project's language, a duplicate search — three projects meeting one API gap is one issue with three
  voices — and an explicit yes, because a public issue is indexed from the moment it exists and
  deleting it does not undo that. `dartway-finish` reports a filed entry by its issue's real state and
  offers to file the ones that have none; it never pushes on its own.

- **`unusedFeatureFile` reads declarations it used to miss, and follows the one link it used to
  cut.** Two false positives, one bill: the only way to a green check was to rewrite working code.
  The symbol index covered classes, enums and top-level variables — and, because the variable
  pattern was not anchored to column 0, every `final blob = …` *inside a function body* as well.
  Functions and getters themselves it did not read at all, so a file whose only public member was a
  top-level function was judged on the names of its own locals, which appear nowhere else by
  definition, and reported as dead while the function was called from the next file over. Functions
  and getters are indexed now, and a top-level variable has to start at column 0 to be one.

  The second is a conditional-import trio — `foo.dart` forwarding to `foo_stub.dart` /
  `foo_web.dart`. It is one symbol in three files: the forwarder declares nothing at all, and each
  half is a platform the other build never compiles, so read one file at a time none of them has a
  visible caller. The three now answer as one unit — alive when anything outside the trio uses any
  of their names, and reported *in full* otherwise, the forwarder included, which is the half the
  check used to leave standing.

- **The `unusedFeatureFile` finding now names where the file should go instead.** "Dead code" is
  half an answer: a file its own feature stopped using is often a file somebody else needs, and the
  message said nothing about where that somebody may reach it from. The intended shape was learned
  by moving the file until the rule stopped firing — which, for a platform trio, meant discovering
  `lib/core/platform/` by elimination. The message now names all three homes: `lib/shared/` for a
  building block with no story of its own, `lib/core/` for wiring several features share, and
  `lib/core/platform/` for a platform trio.

- **`uiKitContainsText` no longer reads a font family as a label.** `fontFamily: 'monospace'` and
  the names inside `fontFamilyFallback` are typeface identifiers the platform's font matcher reads
  and nobody else does: never translated, and with nowhere to be moved to, because the kit is
  exactly where fonts belong. The finding named a line with no fix behind it. String literals in
  those two positions are exempt now — including a fallback list `dart format` broke across several
  lines — and the exemption is positional rather than per line, so a real label sharing the line
  with a font family is still found, and still the one the message quotes.

## 0.7.0

- **`frameworkRefsDiverged` (warning): the framework arriving in halves.** An app that consumes
  DartWay by git states `ref: master` on every package, which reads as "all of it from master" and is
  not what the lock does — a git dependency is pinned to a commit when it is *added*, and stays there
  until something upgrades it by name. Add the core in March and the push module in May and the
  project runs two framework releases against each other, with no version number anywhere to make the
  gap visible, because a git dependency shows none. The check groups the `dartway_*` git entries of
  every `pubspec.lock` in the project by repository and reports a repository resolved to more than one
  commit, naming the packages, their commits and the directories to run `dart pub upgrade` in.
  Different repositories are never compared, and hosted packages are left alone: semver already
  answers this question for them. A warning rather than an error — the state is wrong but the code is
  not, and what fixes it is a command rather than an edit.

## 0.6.0

- **`dartway check` now verifies that the generated code is committed formatted — `generatedCodeUnformatted`.**
  `serverpod generate` writes its output through the `dart_style` bundled with the Serverpod CLI,
  which is not the `dart format` of the project's SDK, and nothing reconciles the two. Left alone,
  the difference means every generation run rewrites files the change never went near: making one
  field nullable produced a diff of 29 files and about 1900 lines, in which the two lines that
  mattered could not be found. The check runs `dart format --output=none --set-exit-if-changed` over
  the server's `lib/src/generated/` and the client's `lib/src/protocol/`, and it insists on **both**
  — a repository that keeps one of them formatted and leaves the other raw has not avoided the diff,
  it has handed it to whoever next formats the second, which in one project meant 33 unrelated files
  arriving in someone else's pull request.

  It is a **warning**, not an error, and that is a decision rather than a softening: the comparison is
  against the `dart_style` of whichever SDK ran the check, so a red result can mean "your SDK is newer
  than the one that formatted this" rather than "you skipped a step". A check that fails the build on
  that is a check people learn to filter out. So the finding names the files, the exact `dart format`
  command with both paths spelled out, and the Dart version it judged against — it has to be
  actionable by someone who did not write the code and does not know why it went red.

  The step this holds is documented alongside it, because its position is not the obvious one: the
  format pass goes **after** `create-migration`, not after `generate`. `create-migration` regenerates
  in order to diff the schema, so a pass placed between the two is silently undone — which turns a
  missing step into a loop of generate → format → generate → format again.

## 0.5.1

- **`quickstart` no longer tells the agent to run a seed, because the skeleton no longer ships one.**
  The first administrator is now declared per environment — `bootstrapAdminIdentifier` in
  `config/passwords.yaml`, which the brief instructs the agent to *ask the human for* rather than
  invent, since whoever receives the one-time code on that identifier becomes the admin. The step it
  replaces was development-only by construction, so staging and production were left with an `UPDATE`
  typed by hand: an operation nobody can read back and nobody can repeat when a new environment goes
  up. Everything else the seed did was already reachable without it — a plain user registers in half
  a minute against the OTP printed in the console, and the app name is set on the admin panel's
  settings screen, which is a better first run than a row put there in advance because it shows the
  write path and the live update.

## 0.5.0

- **`deploy check` now reads `compose.override.yml`, which nothing did before.** The override is the
  one deploy file a project writes by hand, and the deploy copies it to the server unexamined. The
  new `override-web-build` warns when it carries a `build` block for the `web` service: the deploy
  builds that image itself and hands it `DW_BACKEND_URL` from `publicHost`, so an override that
  builds it too states the API domain a second time with nothing comparing the copies — the build
  keeps succeeding against yesterday's API. This is not hypothetical: it is what Studio's deployment
  did, under a comment claiming a check that did not exist. Overriding `web` for a label or a limit
  stays legitimate, which is why this is a warning and why only the build block trips it.

- **`/dartway-audit` becomes `/dartway-checkup`, and looks at the project rather than at the code.**
  The audit judged the Flutter package against the clean-code contract, which left out everything
  that is not code — and that turned out to be where the worst findings live: a check declared in
  `analysis_options.yaml` and executed by no CI step, a test suite excluded months ago with a comment
  older than its reason, a pin trailing the framework so that a local workaround silently duplicates
  what upstream now does. The checkup runs the project's own gates *before* reading anything — those
  answers are certain and cost a minute — then compares them against what CI actually runs, and
  measures the distance to the framework.
- **Depth is budgeted and remembered, so repeated runs go deeper instead of skimming.** Breadth and
  depth compete for one budget and breadth always wins, so the command reads three to five features
  properly per run and records them in a coverage table: never-visited first, then whatever changed
  most since its last pass. A first pass over a feature finds the structural problems; once those are
  fixed the next one sees the design underneath.
- **A finding a command could confirm is a hypothesis until the command has been run**, and is
  labelled as one. Two real errors motivated the rule: a widget parameter called legacy because a doc
  comment said so while the code said otherwise, and a folder reported as missing a passport the
  checker does not in fact demand.
- **`dev_notes.md` — the second journal.** `dartway_notes.md` holds what the *framework* got wrong;
  this one holds what *this project* carries and nobody else can fix — CI, pins, configs, tendencies.
  What belongs to a single feature goes in neither: it is a line in that feature's `knownIssues`,
  next to the code. Installed and git-ignored like its sibling, never overwritten, written by
  `dartway-finish` as well as by the checkup, and both journals' open entries are listed when a task
  ends. Entries are deliberately short — where, what is wrong, what it leads to — because a journal
  of treatises is a journal nobody reads.
- A retired command is now removed from a project on update rather than lingering as a stale
  `/slash`: `managedCommandFiles` keeps the old name until no project can still be carrying it.

## 0.4.0

- **`dartway check` now sees the features it had been walking past, and stops contradicting its own
  exit code.** Three findings, one cause: the checker recognised a widget by matching a list of base
  class names — `(Stateless|Stateful|Consumer|HookConsumer|Hook)Widget` — which silently missed
  `ConsumerStatefulWidget`, the class every form and dialog extends. It now asks whether a public
  class extends anything named `*Widget`: a shape rather than a memory. Its twin, the new
  `notAFeature` (error), closes the other end — a folder in a zone whose entry point declares no
  widget is not a feature, and belongs in `core/` (state several features watch) or `shared/` (a
  helper with no story). While only the spec check existed, a provider-only folder passed *because*
  it was not a widget; a real project had ten of them, every one graded A. Finally, the verdict line
  moves out of the Flutter inspector and into the command: the inspector knew nothing of the layout
  check that ran before it, so a run could print two layout errors, announce "No errors — check
  passes", and exit 1.

## 0.3.0

- **The deploy now supplies the web build's API address, and the template ships the two Dockerfiles
  the compose file has always named.** The rendered compose file builds `<project>_server/Dockerfile`
  and `<project>_flutter/Dockerfile` from the project root, but neither the template nor the example
  had ever contained the second one, and the build argument the first version passed — `FLUTTER_ENV`
  — was read by nothing in the framework. A project reaching deployment therefore wrote its own
  image and invented its own way to tell the app which API to talk to, which is a domain written
  down twice with nothing comparing the copies. The argument is now `DW_BACKEND_URL`, rendered from
  `publicHost` in the Serverpod configuration, and `main.dart` reads it through
  `String.fromEnvironment` with the localhost fallback for local runs.

- Two new local checks. `dockerfiles-present` fails when either image the compose file builds has no
  Dockerfile — previously that surfaced on the server, after the checkout had already moved.
  `dockerfile-entrypoint-form` fails on a shell-form `ENTRYPOINT` in the server image: `docker
  compose run backend … --apply-migrations` appends arguments that this form ignores, so migrations
  quietly start an ordinary server and the deploy reports success. Setting `server_entrypoint`
  declares the shell form deliberate and satisfies the check.

- The rendered compose file states the server's run mode as a `command`, not only as the `runmode`
  environment variable: an exec-form entrypoint takes its arguments from there, and `docker compose
  run` replaces them wholesale for the migration pass.

- **`create` writes `config/passwords.yaml` instead of the template carrying it.** The template used
  to commit the file with throwaway development values so that a new project ran immediately; the
  values were harmless, the habit was not, and `deploy check` fails on a tracked passwords file —
  every project therefore started life with an error against it. The committed record is now
  `passwords.yaml.example`, `create` copies it onto the new project's disk, and `.gitignore` covers
  the copy from the first commit.

- **`invalidTopLevelLayout` — the top level of a project is a closed list, and now something checks
  it.** The Flutter package: `main.dart` and `<project>_app.dart`, the zones `app/` `admin/` `auth/`
  `common/`, the layers `core/` `shared/` `ui_kit/` `l10n/`. The server package: `server.dart` and
  `src/`, and under it `app/` `crud/` `dartway/` `domain/` `endpoints/` `generated/` `models/`
  `web/`. Anything else is an error, as is a missing fixed name — and so is a top-level name used
  one level down, which is the case that prompted the check: `app/admin/` is an ordinary group as
  far as every other rule can tell, so the admin panel sat outside the checks written for zones
  without anything noticing. The list had been written down in three places — the docs, the agent
  toolkit and this checker — and the three had already drifted apart. Now there is one list, in
  code.

- The checker's zone names are matched exactly rather than by prefix, and `data/`/`domain/` are gone
  from the Flutter side: the data layer is `dw.repo`, and what is left of Flutter-side domain logic
  is a helper, so it belongs in `shared/`. Both folders had been conventional and empty since the
  beginning.

- `--dir` skips the layout pass, the same way it already skips `ui_kit/`: both judge a package as a
  whole.

- A new toolkit token, `__FLUTTER_APP_FILE__` — the app's wiring file, whose name follows the
  project (`my_app_flutter` → `my_app_app.dart`).

## 0.2.0

- **`dartway quickstart` — the framework's front door, and it is not a plugin.** It prints the whole
  setup brief to stdout: prerequisites, how to create a project, the order the bring-up steps come in
  and why, the liveness check, how to hand over the sign-in. A human pastes two commands anywhere —
  `dart pub global activate dartway_cli` and `dartway quickstart` — and whatever assistant is at hand
  has the instruction in context. An extension would have tied the way into an open framework to one
  vendor's format and left everyone else copying prose; a printed text is read by all of them, and by
  people. The brief is deliberately shell-neutral: it states the step and the reason and lets the
  agent phrase the command its own platform wants.

- **`dartway doctor` — the failures that are never DartWay's.** Dart and Flutter versions, a
  *responding* Docker daemon (reported separately from a missing one), `serverpod_cli` against the
  pin read from the project's own server package, and the pub global bin directory on PATH. Each
  failure prints the command that fixes it; exit code 1 when something is blocking, so an agent or a
  CI step can branch on it. These surface late and expensively otherwise — as `connection refused`
  during migrations, as generated code that compiles and then misbehaves, as `dartway: command not
  found` right after a successful install.

- **`dartway create .`** uses the current empty folder as the project root instead of nesting a
  directory inside it — the shape people actually start in, an empty folder already open in an editor
  or an agent. The folder names the project, as in `flutter create .`, converting the separators a
  directory may carry and a Dart package may not (`dartway-demo` → `dartway_demo`); a name that
  cannot be converted is refused with the reason. An initialized-but-empty git repository is allowed
  through, since that is how such a folder often arrives, and the initial commit lands in it.

- **`.claude/settings.json` is seeded by the installer**, only when the project has none and never
  overwritten afterwards. It pre-approves this stack's build commands so a first run is not a queue
  of permission prompts, and denies reading `config/passwords.yaml` — a rule the skills stated and
  nothing enforced. Nothing destructive is on the list.

- **Removed dead pubspec rewriting.** `create` no longer retargets `ref: master` to `ref: stable`:
  the template stopped carrying git dependencies, and the code had quietly become a no-op that the
  docs still described.

## 0.1.3

- **The harness now ships the channel back.** A project on the framework is where the rules get
  disproved — but the harness is overwritten on update, so a rule that let you down cannot be fixed
  where you found it, and the finding used to die in a chat. `setup-ai` and `create` now leave a
  git-ignored `dartway_notes.md` at the project root (never overwriting an existing one) and
  `dartway-finish` lists its open entries at the end of a task. `CLAUDE.md` says when to write there:
  a rule that does not exist or is too vague, an API the app had to work around, and the moment you
  are tempted to edit a managed file — that temptation *is* the note.

- **`--language`** records what the project writes its own texts in — feature specs, doc comments,
  its journal — into the installed `CLAUDE.md`. Default English; package APIs and error strings are
  English regardless, since those ship to other people.

- **Leftovers of the old shell installer are reported, not removed.** `tools/dw_claude_setup/` is
  usually a gitlink with no `.gitmodules` entry — invisible to `git submodule update`, silent in
  `git status`, and an empty folder on disk. The installer names it and prints the two commands that
  clear it. It does not run them: an installer that edits somebody's git index is a different kind of
  tool than one that copies files.

- **`unusedFeatureFile` (warning): dead code inside a feature.** A file in `widgets/`/`logic/` that
  its own feature never mentions is unreachable — nobody outside may import it — and the analyzer
  cannot say so, because to it a public class is always possibly used elsewhere. Law 3 is what makes
  the check possible at all: the search is one folder deep, so the answer is complete rather than a
  guess. On one real admin panel a single pass found a replaced save-button bar and a stale copy of a
  moderation list, both compiling and both travelling through every refactor.

  Two false positives cost the first version four hits out of six, and both are now tested: a type is
  not how it is called (an extension answers to its member name, a notifier to its provider
  variable), and dead code keeps dead code alive (a handler nobody calls still calls its own
  settings file, so the sweep repeats until a pass buries nobody).

- **`dartway check` tells apart "must be a feature" from "is checked at all".** The two used to be one
  list, so a widget outside a zone was exempt from the passport rule *and* from every cleanliness and
  UI-Kit rule at once. `lib/shared/` — the home for building blocks under Law 3 — is now read for the
  content rules but never asked for a `DwFeatureSpec`, which is what made moving blocks out of zones
  safe to recommend. `widgets/`/`logic/` are treated as a feature's internals only inside a feature
  area, so `shared/widgets/…` is importable rather than being flagged as reaching into somebody's
  internals. `core/`, `data/` and `domain/` are still skipped entirely — a known gap, unchanged here.

## 0.1.2

- **`dartway deploy` — the server without a folder of shell scripts.** Three verbs: `check` reports
  whether a deployment would work and changes nothing, `run` updates, rebuilds, migrates and
  restarts, `secret` moves credentials between the maintainer's `passwords.yaml` and a server.

  The Serverpod configuration is the source of truth. Domains, ports and the database stay in
  `<project>_server/config/<env>.yaml` and the CLI reads them; `deploy/config.yaml` holds only what
  Serverpod has no concept of. In the two projects this replaced, nine fields existed in both places
  and a whole script existed to keep them from drifting.

  `check` runs seventeen assertions. The one that pays for the rest is DNS: every `publicHost` must
  resolve to the deployment host, because a domain that does not reach the box fails certificate
  issuance and repeated failures hit a rate limit.

  Secret values travel on stdin, never as arguments, and YAML encoding happens locally so the remote
  side never escapes anything. Two guards refuse a push that would lose information: keys the server
  has and the file does not, and values the file would blank.

- **Two more conventions the analyzer cannot see.** `barrelFile` (error) fires on a file that only
  re-exports: it reads as convenience and acts as a hole in the feature boundary, because importers
  name the barrel and reaching into another feature's guts through it looks legitimate — one such
  file laundered three features' internals until it was deleted. `widgetSizesItself` (error) fires
  on `Expanded` or `SizedBox.expand` opening a `build` body: the widget claims the parent's space
  and throws in the first parent that is not a flex, while the analyzer stays silent.

  `SizedBox(width: double.infinity)` was tried in the second check and taken back out. Inside a
  bounded parent it only means "as wide as allowed", so every hit was arguable — and a check whose
  findings are arguable teaches people to skip the checker.

- **`forbiddenUiUsage` now catches `Theme.of(context)` and `context.theme`.** It already flagged
  `context.textTheme` and `context.colorScheme`, so the rule was sidesteppable by writing the same
  thing the long way: `Theme.of(context).textTheme.bodySmall` reads as ordinary Flutter and passed
  the checker while the short form did not. Both spellings mean a screen is styling itself.

- **Asset paths are checked against the file system.** `assetPathMissing` (error) fires when a
  string like `assets/icons/lock.png` names a file that is not there — nothing else catches it: the
  code compiles and the screen renders a blank. `forbiddenAssetPath` (warning) fires on a raw asset
  path outside `ui_kit/`, because a path spelled out in a screen survives a renamed file only by
  accident and cannot be found by search.

  Together these replace what a code generator used to guarantee. A generated constant could not
  name a missing file; a hand-written one can — and DartWay projects now write them by hand, since
  `build_runner` in the edit loop costs minutes per change and punishes the one who forgets to run
  it with errors about code that is perfectly fine.
- **The file-length thresholds are relaxed: nothing below 200 lines, a nudge above it,
  a warning above 350.** Length is the weakest signal the checker has, and a tight limit
  makes it lie — it flagged files that were long because they were well described. That
  is not hypothetical: a feature's `DwFeatureSpec` now lives in the file of the feature it
  describes, and a good description costs twenty lines. A rule that goes off when someone
  documents their feature properly teaches them to document less.
- New check `featureSpecMissing` (warning): a feature whose public file is a widget is
  expected to declare a `DwFeatureSpec` — the spec is what error reports, Studio and the
  agent read. Features whose entry point is an extension or a plain function are left
  alone: there is nothing there to hang a spec on.
- **`create` stops printing a wall of commands and hands the project to the agent.**
  The old output listed seven commands across two terminals — which is both the
  first thing a newcomer sees and a contradiction: every new project ships an AI
  toolkit in `.claude/`, and the tool that installed it was still telling people to
  type `docker compose up -d` by hand. Now `create` says to open the project and run
  `claude`, then ask for it in plain words. The manual sequence has not gone
  anywhere — it lives in the project's `README.md`, for people without an agent at
  hand and for anyone who wants to see what actually happens.
- The toolkit gained the skill that makes this real: **`dartway-run`** knows the
  order that matters (seeding before migrations fails; a started container is not yet
  a database accepting connections), the ports (API 8080, dev database 8090, test
  9090), where the one-time sign-in code is printed, and how to read the failures
  people actually hit — Docker not running, port 8090 taken by another DartWay
  project, a schema that drifted, a model changed without `serverpod generate`, a
  `serverpod_cli` that no longer matches the project's pin.

## 0.1.1

- `create`: the printed next steps now actually run in order — `dart pub get`
  before the server starts, `--role maintenance` so migrations apply and exit
  (leaving the terminal free to seed), and a mention of the VS Code F5 flow.
  The sign-in hint points at the seeded user.

## 0.1.0

First public release — the DartWay command-line tool.

**`dartway create`** — a new project from the DartWay skeleton: server, generated client and Flutter
app, plus the AI toolkit in `.claude/`. What you get is a skeleton, not somebody's product: phone
auth with one-time codes, a `UserProfile` with roles, navigation with zone guards, an admin panel,
a UI kit as source you own — and zero domain models, because the domain is the part you write.

**`dartway check`** — the conventions, enforced: errors fail the run, warnings and infos are
advisory. File length is a soft signal (over 120 lines an info, over 200 a warning) rather than a
hard rule, because a limit you cannot honestly meet is a limit people learn to ignore.

**`dartway stats`** — code size per feature: what actually grew this week.

**`dartway setup-ai`** — installs or updates the AI toolkit in an existing project, overwriting only
the files it manages.
