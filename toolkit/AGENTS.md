# DartWay — agent index

Contract: `__SHARED_PKG__`; server: `__SERVER_PKG__`; app: `__FLUTTER_PKG__`.
Project rules live in root `AGENTS.md`; root `CLAUDE.md` imports it. The installer never merges
owner texts; `instructionsDuplicated` warns about separate root Claude prose.

`.agents/DARTWAY.md`, `dartway-*` skills and command wrappers are managed. Customize under a
new skill name. Project descriptions use __PROJECT_LANGUAGE__; public APIs, logs, errors and
framework issues use English.

## Laws

1. Cross-stack calls use the shared contract's DTOs; external callers use `DwHttpRoute`.
2. Rows stay on the server; map to reader-specific data objects in batch.
3. Features are end to end and expose one entry point.
4. Every handler, channel and upload has an explicit access rule; refusals are codes.
5. Names have two words after `Dw`: `<Entity>Row`, noun data objects, `Get…`/`List…`
   reads, verb + object commands, `<Package>Refusal`/`Channel`/`Upload`.
   Variables name their value and match its type; distinguish profile from account.
6. Generated codecs, registries and schema are never hand-edited; migrations are reviewed.
7. Finish with checks and descriptions next to the code (`dartway-finish`).

## Law and default

The seven laws and checker errors are mandatory; project conventions may override defaults with
a reason. The law list is therefore derived from `DwCheckType.severity`: forty-four errors,
thirteen warnings and one info. Check messages name the correction; open the owner skill for how.

| Rule | Checks that fail | Skill |
|---|---|---|
| Feature boundaries and entry points | `invalidFeatureStructure`, `notAFeature`, `forbiddenFeatureImport`, `barrelFile` | `dartway-feature-scaffold` |
| Package layout | `invalidTopLevelLayout` | `dartway-feature-scaffold`, `dartway-server` |
| Hooks and Notifier state | `forbiddenStateHolder` | `dartway-feature-scaffold` |
| Kit owns styles, spacing, sizing and assets | `uiKitPartMissing`, `forbiddenUiUsage`, `forbiddenUiKitImport`, `rawSpacing`, `widgetSizesItself`, `assetPathMissing` | `dartway-ui-kit` |
| The app is localized | `l10nNotWired` | `dartway-ui-kit` |
| Framework read widgets | `forbiddenRequestRead` | `dartway-data-layer` |
| The one spinner is the kit's | `forbiddenProgressIndicator` | `dartway-ui-kit` |
| `dw.command` runs in the feature's `logic/`, inside `dw.action` | `forbiddenCommandCall` | `dartway-data-layer` |
| Routes, dialogs, ids and router lifetime | `forbiddenNavigationCall`, `sentinelId`, `routeNameDuplicated`, `routerDisposedByApp` | `dartway-navigation` |
| Server feature boundaries and row ownership | `invalidServerFeatureFile`, `misplacedServerCode`, `featureImportCycle`, `featureImportOutsideSurface`, `foreignRowWrite`, `coreImportsFeature` | `dartway-server` |
| Server clock, environment and outbound HTTP | `forbiddenDateTimeNow`, `forbiddenEnvironmentRead`, `forbiddenHttpClient` | `dartway-server` |
| Startup steps, typed settings, row ids | `workAfterServerStart`, `settingsKeyValueTable`, `redundantBangAllowed` | `dartway-server` |
| Shared layout, DTO names and patch helpers | `invalidSharedLayout`, `contractNameInvalid`, `fieldPatchMatched` | `dartway-contract` |
| Generated code and installed-client compatibility | `generatedCodeStale`, `projectContractVersion` | `dartway-contract` |
| Lifecycle status changes use guarded state transitions | `stateWrittenDirectly` | `dartway-server` |
| Schema and data migrations | `migrationsDrift`, `migrationChangesData` | `dartway-migrations` |
| Test layout and harness | `testLayout`, `testHarnessBypassed` | `dartway-testing` |
| `lib/` imports by `package:` only (`check --fix` rewrites) | `relativeImport` | — |
| The framework's lint plugin is on | `lintsPluginMissing` | `dartway-update` |

Not held by any check: naming beyond DTO class names, "done", and a `DwHttpRoute` the app calls. `migrationsDrift` needs a database — `DW_DATABASE_*`, or `deploy/config.yaml > local` — and says when it did not run.
The expand/contract rule across production releases is also held by review alone (`dartway-migrations`).

## Open only what the task needs

Start with the issue and the affected code. Open `dartway-requirements` when requirements need
analysis; `dartway-plan` when choosing an approach. An agreed implementation task proceeds directly
to its layer skill. Load other skills when their step is reached, never the whole toolkit first.

Skills live once in `.agents/skills/`; `.claude/skills` is a relative symlink. Claude commands remain wrappers.

| When | Open |
|---|---|
| Analyze unclear requirements; choose an approach | `dartway-requirements`, then `dartway-plan` |
| Add a feature or change its folders/state | `dartway-feature-scaffold` |
| Change DTOs or run generation | `dartway-contract` |
| Change handlers, rows, jobs, environment or external services | `dartway-server` |
| Change access, identities or roles | `dartway-access` |
| Change live updates | `dartway-realtime` |
| Change rows or migrations | `dartway-migrations` |
| Work with uploads | `dartway-uploads` |
| Change screen reads, commands or refusal text | `dartway-data-layer` |
| Change routes or guards | `dartway-navigation` |
| Change styles, kit or localization | `dartway-ui-kit` |
| Select or write tests | `dartway-testing` §4 (six risk classes); §5 for a bugfix |
| Describe behaviour or record a finding | `dartway-documentation` |
| Finish the task, before commit or PR | `dartway-finish` |
| Run locally or deploy | `dartway-run` |
| Fix phone keyboard, focus or viewport behaviour | `dartway-on-device` |
| Update framework, dependencies or old shapes | `dartway-update` |
| Work on push, analytics or media | `dartway-push-delivery`, `dartway-analytics`, `dartway-media`, respectively |
| Report a framework gap or workaround | `dartway-framework-notes` before filing |
| Commit or audit the whole project | `dartway-commit` (`/commit`), `dartway-checkup` (`/dartway-checkup`) |

Commands `generate`, `check`, `test`, `dev`, `deploy`, `stats` use the pinned CLI:
`dart run dartway_cli:dartway <command>` from `__FLUTTER_PKG__`.
PRs target `__BASE_BRANCH__`; integration uses `dart run dartway_cli:dartway sync`.

## Interaction

Read `interactive` in `.agents/dartway-toolkit.json` (absent means `true`). With `false`,
**every managed step requiring a human answer or confirmation instead puts its proposed text,
question or action in the final report and stops that step**. Continue independent authorized work;
never treat silence as approval. This covers requirements questions and option selection,
framework issue/comment publication, finish suggestions, real keys and local setup questions,
and migration/backfill or destructive decisions. Each affected skill identifies its stopping point.
