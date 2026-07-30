# Changelog

## 0.1.2

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
