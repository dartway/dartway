# Changelog

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
