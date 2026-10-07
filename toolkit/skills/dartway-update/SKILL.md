---
name: dartway-update
description: >-
  Plan an exact DartWay target without project edits, preflight analyzer plugin resolution,
  apply migration notes, move dependencies, and verify the project before recording each note
  as applied or not applicable. Toolkit provenance and dependency locks never complete notes.
  Use when the framework has released, the project is behind, or a needed framework fix landed.
---

# DartWay — updating the project (`dartway-update`)

The update is: what moved, what the project owes because of it, and proof the result works. Raising a
caret is the last step, not the task; the update is its own branch and PR, never folded into a feature.

1. **A branch from a clean tree**: `git status`, then `git switch -c chore/dartway-update __BASE_BRANCH__`.
2. **Update the CLI**: `dart pub global activate dartway_cli` — an old CLI installs an old toolkit.
3. **Plan first:** `dartway update --plan` takes the recorded channel (or explicit `--channel` /
   `--local-repo`) and prints its exact commit, package gaps and unconfirmed migration notes,
   oldest first, with their instructions. It writes **no project files**, including migration state.
   Only committed source files are read; local uncommitted framework edits are excluded.
   Keep the target SHA and all selected options for the rest of the update. Repeat planning with
   `--plan --target <sha>` to stay on that target when the channel moves.
4. **Preflight the plugin:** the plan asks pub to resolve the proposed `dartway_lints` dependency,
   including analyzer constraints, before configuration can be edited. Existing git/path choices
   stay choices; hosted pins may be raised only when they resolve. An unpublished development
   version or unreachable source is an explicit failure. Choose a published target or a resolvable
   path/git source in the project's own `analysis_options.yaml`; `--framework-path <checkout>`
   supplies a path for a missing plugin. Do not write an unresolvable hosted pin to get past this step.
5. **Install the target:** `dartway update --target <sha>` with the same source and installer options.
   It rechecks resolution, installs the selected Codex/Claude integrations, preserves owner rules
   and recorded installer choices, and applies only the planned plugin edit. It completes **no notes**.
6. **Read and make each note's edits**, in order and in the project's conventions. Search for what
   changed before deciding applicability. An absent `.dartway/migrations.json` means **unknown
   baseline**, even if locks already resolve the target or the toolkit was installed today. Review
   every unconfirmed note; older notes may already be satisfied or not apply, but neither is inferred.
   A wrong/unreadable note is a framework defect for `__NOTES_TRACKER__`; unresolved work stays pending.
7. **Move the packages.** The core family — `dartway_core_shared`, `dartway_core_server`,
   `dartway_core_flutter`, `dartway_orm`, `dartway_client` (dev, Flutter) and `dartway_generator`
   (dev, server) — to **one** version, all carets together. Under `0.x`, `^0.20.0` excludes `0.21.0`.
   For git, pin the exact target and upgrade the `dartway_*` packages together in each directory
   (`frameworkRefsDiverged`). Satellites move each to its own version. Remove an early override
   once the family admits that satellite (`frameworkOverrideOutlived`). Resolve all three packages.
8. **Regenerate and verify:** run the generator even if no DTO changed, every gate in
   `dartway-finish` (A.2), and the app (`dartway-run`). Say whether `dwProtocolVersion` moved:
   installed apps then get `426`, so the server and new builds must ship together.
9. **Record only verified dispositions:**

   ```bash
   dartway update --target <sha> --complete docs/migrations/<note>.md --verified --verification "Checks run and actual results"
   dartway update --target <sha> --not-applicable docs/migrations/<note>.md --verified --verification "What was inspected and why this project is unaffected"
   ```

   Keep the same source options. These commands only write `.dartway/migrations.json`; no toolkit
   install or dependency edit occurs. Repeat a disposition flag for a verified batch; the evidence
   must cover every selected note. Records retain each note's path and existing package-version
   metadata. There is no bulk "migrated to target" shortcut. Partial completion leaves the rest
   unconfirmed, and repeat planning or installing cannot erase it.
10. **Commit and report:** commit the ledger, selected toolkit integrations, root connection blocks
    and plugin configuration with the project's edits. Name applied, not-applicable and outstanding
    notes with reasons; target SHA and toolkit source; packages before/after; protocol version;
    checks and actual outcomes; the regression that was red before the fix. A large migration is
    reviewed in verifiable batches; a dependency bump is never evidence that review is complete.

## Old shapes — a project that grew under an older wording of a law

Legacy moves as you touch it, never as a sweep, and a gap left is said out loud. Each entry: how to
tell, the target, what to do with what accumulated. An entry goes once no project carries the shape.

- **Blocks in zones, widgets in `lib/shared/`.** *Tell:* a `common/`, `shared/` or `widgets/` folder
  inside a zone; `featureSpecMissing` on folders whose spec would restate the class name; widgets in
  `lib/shared/`. *Target:* a zone holds features; a visual block in `lib/ui_kit/` with a doc comment; a
  zone's shell in `lib/core/router/`. An empty spec is deleted with the move.
- **Commands and specs in `widgets/`.** *Tell:* `grep -rn 'dw\.command' lib | grep -v /logic/`,
  `grep -rln DwFeatureSpec lib | grep '/widgets/'`. *Target:* commands per `dartway-data-layer` §4, the
  spec on the entry file per `dartway-feature-scaffold`, "The feature spec". Move as you touch the feature.
- **State and queries in zones.** *Tell:* `notAFeature`. *Target:* state several features watch in
  `lib/core/`, helpers in `lib/shared/` or `lib/ui_kit/`. A provider tests override keeps its name, it
  changes address.
- **An unlocalized app.** *Tell:* `l10nNotWired`, or no `context.l10n` among widgets full of strings.
  *Target:* `dartway-ui-kit`, "Localization". **The wiring in one commit, the strings screen by screen**;
  fix widget tests in the shared harness; the first `.arb` in the language the strings already are.
