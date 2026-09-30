---
name: dartway-update
description: >-
  Moving the project onto a newer DartWay: update the CLI, run `dartway update` (installs .claude/,
  reports the packages behind and the migration notes owed), make the edits the notes ask for, then
  move the core family together and each satellite on its own, regenerate, prove it with the gates
  and a run, and report whether the protocol version moved. Also the old shapes a project may still
  carry and how to recognise them. Use when the framework has released, when `dartway update` says
  the project is behind, or when a fix the project waits for has landed.
---

# DartWay — updating the project (`dartway-update`)

The update is: what moved, what the project owes because of it, and proof the result works. Raising a
caret is the last step, not the task; the update is its own branch and PR, never folded into a feature.

1. **A branch from a clean tree**: `git status`, then `git switch -c chore/dartway-update __BASE_BRANCH__`.
2. **Update the CLI**: `dart pub global activate dartway_cli` — an old CLI installs an old toolkit.
3. **`dartway update`** — takes the framework from the recorded channel (`--channel`, `--local-repo`),
   installs `.claude/`, and reports the `dartway_*` packages behind (resolved version, the channel's,
   the directories holding it) and the migration notes that still apply, oldest first. It changes
   nothing but `.claude/`. Nothing behind and no notes: commit `.claude/` and stop. An unreadable note
   is a framework defect — file it, read it by hand.
4. **Each note, in the order given**: first `grep` whether the project uses what changed — not applying
   is a normal outcome. A note keyed to `dartway_cli` is the only way a skeleton change reaches an
   existing project.
5. **Make the edits**, one note at a time, in the project's own conventions. Where a note and the
   project disagree, stop and ask. A wrong or missing note goes to `__NOTES_TRACKER__`.
6. **Move the packages.** The core family — `dartway_core_shared`, `dartway_core_server`,
   `dartway_core_flutter`, `dartway_client` (dev, Flutter) and `dartway_generator` (dev, server) — to
   **one** version, every caret in every package, in one change; the app and the server speak the wire of
   the family they resolve. Under `0.x` a minor is a major: `^0.20.0` excludes `0.21.0`, and lowering a
   caret is never the fix. From git: `dart pub upgrade` of all the `dartway_*` packages together in each
   directory (`frameworkRefsDiverged` warns on packages locked to different commits). Satellites
   (`dartway_router`, `dartway_lints`, `dartway_shared_preferences`, `dartway_cli`, …) move each to its
   own version; a `dependency_overrides` taken early goes once the family admits that version
   (`frameworkOverrideOutlived`). The `dartway_lints` plugin must be enabled in the Flutter package's
   `analysis_options.yaml` — `dartway update` wires it (`lintsPluginMissing`).
7. **Regenerate and prove**: `dart run dartway_cli:dartway generate` even when no DTO changed (the
   generator moved), then every gate in `dartway-finish` (A.2), then run the app (`dartway-run`): a
   changed default or wiring step shows only there. The framework's own migrations apply at server start.
   **Say whether `dwProtocolVersion` moved** between the resolved `dartway_core_shared` before and after:
   installed apps then get `426`, and the server and the new builds must ship together.
8. **Commit** `.claude/` with the rest: `chore(deps): move to dartway <version>, applying <n> migrations`,
   the body naming the notes applied and found not to apply.
9. **Report**: the toolkit's channel and commit; what moved from what to what; notes applied, not
   applicable, and **left undone with why**; the protocol version; the gates, and what was red before.

## Old shapes — a project that grew under an older wording of a law

Legacy moves as you touch it, never as a sweep, and a gap left is said out loud. Each entry: how to
tell, the target, what to do with what accumulated. An entry goes once no project carries the shape.

- **Blocks in zones, widgets in `lib/shared/`.** *Tell:* a `common/`, `shared/` or `widgets/` folder
  inside a zone; `featureSpecMissing` on folders whose spec would restate the class name; widgets in
  `lib/shared/`. *Target:* a zone holds features; a visual block in `lib/ui_kit/` with a doc comment; a
  zone's shell in `lib/core/router/`. An empty spec is deleted with the move.
- **Commands and specs in `widgets/`.** *Tell:* `grep -rn 'dw\.command' lib | grep -v /logic/`,
  `grep -rln DwFeatureSpec lib | grep '/widgets/'`. *Target:* `dartway-data-layer` §4, one spec per
  feature on its entry file. Move as you touch the feature.
- **State and queries in zones.** *Tell:* `notAFeature`. *Target:* state several features watch in
  `lib/core/`, helpers in `lib/shared/` or `lib/ui_kit/`. A provider tests override keeps its name, it
  changes address.
- **An unlocalized app.** *Tell:* `l10nNotWired`, or no `context.l10n` among widgets full of strings.
  *Target:* `dartway-ui-kit`, "Localization". **The wiring in one commit, the strings screen by screen**;
  fix widget tests in the shared harness; the first `.arb` in the language the strings already are.
