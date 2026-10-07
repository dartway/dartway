# Why a checker when you already have the analyzer?

`dart run dartway_cli:dartway check` looks at the things the analyzer and the lints cannot see. The analyzer reads a
file; the checker reads the **project**: which folder is a feature, who imports whose internals,
whether a screen styles itself, whether an asset path leads anywhere, whether the generated code
still matches its sources and the migrations still produce the schema. All of that compiles. Some
of it fails at runtime, some of it never fails and just rots.

Three examples of what nothing else catches:

- a file spelling out `assets/icons/lock.png` when no such file exists — the code compiles and the
  screen renders a blank where the image was;
- one feature importing another's `widgets/` — perfectly valid Dart, and the boundary is gone;
- a data object with a field its generated codec does not know — it compiles, starts and travels
  without that field.

The checker is not a second analyzer. It exists because DartWay's structural conventions are the
part of the framework a compiler has no opinion about. The code is
`packages/dartway_cli/lib/src/checker/` and `packages/dartway_cli/lib/src/commands/check_command.dart`.

## Where a rule belongs: the deciding question

DartWay enforces its conventions in three places, and picking the wrong one is how a rule ends up
disliked and switched off. The question is not "how important is this" — it is **whether the answer
is decidable without understanding what the code means**.

| The answer is… | Where the rule goes | Example |
|---|---|---|
| decidable from the shape of an expression | `dartway_lints` (an analyzer plugin, live in the IDE and in `dart analyze`) | is this a raw `Color` outside `ui_kit/`? |
| decidable from the shape of the project | `dart run dartway_cli:dartway check` | does this folder in a zone declare a widget? is `data/` in the declared layout? |
| **only decidable by reading the meaning** | `/dartway-checkup` | is this string something a *user* reads, or an identifier, a key, a date pattern? |

The third row is the one worth defending. `'Issues'`, `'issues/board'` and `'dd.MM'` are the same
shape and different things, so a mechanical rule about hardcoded text can only guess — and a guessing
rule grows an exception list with every complaint until somebody turns it off. `uiKitContainsText`
carries such a list (paths, interpolations, date patterns, typeface names in the `fontFamily` and
`fontFamilyFallback` positions) and survives only because its scope is narrow enough for the guess to
be safe: a kit file has no content to speak of. Widened to features, the same rule would be noise.

The typeface exemption is positional rather than per line, deliberately: the literal in that argument
is stepped over and the reading continues, so a real label sharing the line is still found. An
exemption that swallows the whole line is how a rule stops firing without anyone noticing.

A rule that needs understanding is not a weaker rule. It is a rule for a reader.

## Two commands, and neither implies the other

```bash
cd <project>_flutter
dart analyze --fatal-infos                      # the analyzer, the lint set and DartWay's own rules
dart run dartway_cli:dartway check              # the structural conventions
```

**`flutter analyze` does not run analyzer plugins.** The skeleton enables `dartway_lints` under
`plugins:` in its `analysis_options.yaml`, the IDE underlines violations, `dart analyze` reports them
— and a CI running only `flutter analyze` reports a clean build while enforcing none of them.
`dart analyze --fatal-infos` fails where `flutter analyze` does, and on the plugin's warnings too.

The skeleton ships no CI workflow of its own. **A project that adds one runs both, plus its
tests** — not because CI is a virtue, but because these are the checks the project has already
declared, and a rule configured and not executed reads as covered. If a package has a `test/` folder,
CI runs it: a suite excluded from CI stops compiling, and nobody learns that from the exclusion.

## What `dartway check` runs

From the project root or from inside the `*_flutter` package, in this order:

1. **the declared top level** of the Flutter package and the server package (`invalidTopLevelLayout`),
   the server's features (`invalidServerFeatureFile`, `misplacedServerCode`), the shared package
   mirroring them (`invalidSharedLayout`), and file length in the server and the shared package
   (`fileLong`, `fileTooLong`), and how the server's features import and write one another
   (`featureImportCycle`, `coreImportsFeature`, `featureImportOutsideSurface`, `foreignRowWrite`);
2. **localization wiring** (`l10nNotWired`);
3. **analysis options**: the server and the shared package raise `unnecessary_non_null_assertion` to
   an error (`redundantBangAllowed`);
4. **generated code**: `dart run dartway_generator --project <root> --check` in the server package
   (`generatedCodeStale`, `projectContractVersion`);
5. **the environment and outbound HTTP** in the server package: `Platform.environment` outside
   `lib/src/core/environment.dart`, and in `bin/` anything but `DwLocalEnvironment.overlay(Platform.environment)`
   or a map read by a variable's name (`forbiddenEnvironmentRead`); an `HttpClient(` or a
   `package:http` import in `lib/` (`forbiddenHttpClient`);
6. **the data lifecycle** of the server, shared and Flutter packages (`migrationChangesData`,
   `workAfterServerStart`, `settingsKeyValueTable`, `fieldPatchMatched`), and **migrations**:
   `dart run bin/migrate.dart check` in the server package (`migrationsDrift`);
7. **framework locks** across the project's `pubspec.lock` files (`frameworkRefsDiverged`);
   and **framework overrides** that the framework has caught up with (`frameworkOverrideOutlived`);
8. **the `local` environment**: a declared secret it has no value for (`localSecretMissing`), and the
   development containers' credentials against what the server is told to reach them by
   (`devComposeDrifted`);
9. **the Flutter package**: the UI kit, the feature tree of every zone, and the content of every file
   in the zones and `shared/`;
10. **state and commands** over every file of the Flutter package's `lib/` but generated code
   (`forbiddenStateHolder`, `forbiddenCommandCall`), and the classes a `dw:allow-stateful` marker
   passes over, listed after the tally;
11. **reads, loading, dialogs and routes** over every file of the Flutter package's `lib/` but
   generated code (`forbiddenRequestRead`, `forbiddenProgressIndicator`, `forbiddenNavigationCall`,
   `sentinelId`);
12. **one way to write the ordinary things**, in all three packages: imports in `lib/`
   (`relativeImport`), doc comments in the project's language (`docCommentLanguage`), tests that
   mirror `lib/` and use the harness (`testLayout`, `testHarnessBypassed`), spacing through the kit's
   tokens (`rawSpacing`), and the `dartway_lints` plugin enabled (`lintsPluginMissing`).

`--dir <folder>` (relative to the Flutter package) narrows the run to that folder of steps 9–12 and
skips steps 1–8, the UI kit pass, and the parts of step 12 that judge tests, the other packages and
the plugin: each of those judges a whole package or the whole project, and has nothing to say about
one folder. `--type <check>` runs one check by name; `--level info|warning|error` runs the checks of
one severity. `--fix` first applies the mechanical fixes, then checks: every relative import in `lib/`
of the three packages becomes its `package:` form and the import block is sorted (generated files are
left to their generator), and an acceptance test lying at the root of `test/` moves to the mirror of
the `lib/src/<feature>/` it is named after, its import of the harness rewritten. `--type` and `--dir`
narrow the fixes as they narrow the checks; `--dir` leaves the tests.

**Exit codes.** `1` when any error-severity finding is reported (a Flutter package with no `lib/`
counts as one), `0` otherwise — warnings and infos print and pass. An unknown `--type` is a usage
error, `64`. Run outside a DartWay project, the command says so and exits `1`.

**A check that could not run says so, and does not pass or fail.** When the generator does not run to
a verdict — an unresolved package, a declaration it refuses — `dart run dartway_cli:dartway check` prints its first lines
under "Not checked". When `DW_DATABASE_HOST` is not set, the migrations are not replayed and the run
says what to set. A finding invented from a probe that could not run is how a check earns a
reputation for lying; a silent pass is worse.

## Error is law

**Only errors fail the run**, and that set carries a second meaning outside this command. The harness
installed by `dartway setup-ai` draws its law/default line on it: the checks that fail are the
framework's **law**, which a project does not override; everything else is a **default** a project
may replace with its own rule. A warning is a warning precisely because the check cannot tell one
legitimate state from another, and that is not something a project can be forbidden to decide. So
moving a check across the boundary in `dw_check_type.dart` moves it in or out of the law, and
`packages/dartway_cli/test/toolkit_law_list_test.dart` holds the published law list to the checker's
error set. See [The agent toolkit](agent-toolkit.md).

## The checks

Forty-three errors, twelve warnings, one info — `DwCheckType` and its `severity` in
`packages/dartway_cli/lib/src/checker/dw_check_type.dart`.

| Check | Level | What it means |
|---|---|---|
| `uiKitPartMissing` | error | A kit file without `part of '../ui_kit.dart'` (generated files exempt) |
| `l10nNotWired` | error | The app has no localization wiring: `flutter_localizations`, `generate: true`, `l10n.yaml`, a `.arb` in `lib/l10n`. Names the missing pieces |
| `forbiddenUiUsage` | error | Raw styles outside `ui_kit/` — the screen is styling itself |
| `forbiddenUiKitImport` | error | Importing a file inside `ui_kit/` instead of the `ui_kit.dart` barrel |
| `invalidFeatureStructure` | error | A feature folder with more than one root file |
| `forbiddenFeatureImport` | error | Reaching into another feature's `widgets/` or `logic/` |
| `notAFeature` | error | A folder in a zone whose entry point declares no widget |
| `assetPathMissing` | error | An `assets/...` string that names no file |
| `barrelFile` | error | A file that only re-exports |
| `widgetSizesItself` | error | `Expanded` or `SizedBox.expand` returned straight from `build` |
| `invalidTopLevelLayout` | error | A folder or file the declared top level does not name, a fixed name that is missing, or a top-level name nested inside a zone; in the server's `lib/src/`, a file, a layer-named folder (the list is in [project layout](../1-getting-started/project-layout.md)) or a feature folder without its `<feature>_feature.dart` |
| `invalidServerFeatureFile` | error | Inside a server feature, a file that is not `<feature>_<kind>.dart` / `<feature>_<part>_<kind>.dart` (kind: `feature`, `rows`, `handlers`, `objects`, `publications`, `jobs`, `access`, `routes`, `changes`), a subfolder other than `logic/`, a folder or a kind-suffixed file inside `logic/`, or a layer-named folder at any depth of `lib/src/`. The rule: [project layout](../1-getting-started/project-layout.md) |
| `misplacedServerCode` | error | Server code in a file of the wrong kind: handlers outside `*_handlers.dart`, row classes outside `*_rows.dart`, jobs outside `*_jobs.dart`, a `DwHttpRoute` outside `*_routes.dart`, a `DwServerFeature` outside `<feature>_feature.dart`, a function that publishes outside `*_publications.dart`, a row → data object mapping outside `*_objects.dart` — and any of them in `core/` |
| `featureImportCycle` | error | Server features importing one another in a cycle, by any import — within the surface or not. One finding per knot of features: a shortest cycle, the import behind each step, and the other features of the knot |
| `coreImportsFeature` | error | A file of the server's `lib/src/core/` importing a feature. Every feature imports `core/`, so what `core/` needs from a feature belongs to the feature — who the caller is in `profile/profile_access.dart`, the sign-in hooks in a feature above the ones they touch |
| `featureImportOutsideSurface` | error | A server feature importing another's file outside its surface: only `<feature>_rows`, `_access`, `_objects`, `_publications`, `_changes` (and their `<part>` files) may be imported — never `_feature`, `_handlers`, `_jobs`, `_routes` or `logic/`; nor may any file under `lib/src/` import the package's library. `import`, `export` and `part` count. `lib/<project>_server.dart`, `migrations/`, `bin/` and `test/` are not judged |
| `foreignRowWrite` | error | `<handle>.<table>.insert`/`tryInsert`/`insertAll`/`update`/`updateWhere`/`updateWhereReturning`/`upsert`/`upsertAll`/`delete`/`deleteWhere` of a table whose row class another feature declares (the generated schema names the row class of each `db.<table>`), through any handle — `ctx.db`, a transaction's `tx`, a helper's `db` — from a feature or from `core/`: the owner's `_changes` is the way in. A repository held in a variable is not seen |
| `generatedCodeStale` | error | A generated file that `dart run dartway_cli:dartway generate` would write differently, or whose source is gone |
| `projectContractVersion` | error | Generated project contract is incompatible at the same breaking line, or cannot be verified against its fixed committed Git baseline. `--contract-base <revision>` supplies a trusted baseline; see the wire/version guidance |
| `routeNameDuplicated` | error | Two navigation zones declare a route of the same name — names are global in `DwAppRouter`, which otherwise refuses to build on the first frame |
| `contractNameInvalid` | error | A DTO in the shared package named against the naming law: one word (`Dw` is not a word), a read not named `Get…`/`List…`, a command named like a read. Judged by the framework base a class extends directly |
| `forbiddenDateTimeNow` | error | `DateTime.now` or `DateTime.timestamp` (called or torn off, interpolations included), or `package:clock`'s `clock.now()` where it is imported (prefixed or not), anywhere in the server's `lib/` — the factory file included — the time there is `ctx.now`, the server's clock, which tests set and the job queue runs by. Comments and strings are passed over; `bin/` and `test/` are not judged |
| `migrationsDrift` | error | Migrations that do not produce the declared schema, edited after sealing, unregistered, or with a down that does not undo its up |
| `redundantBangAllowed` | error | The server or the shared package's `analysis_options.yaml` (or a local file it includes) does not set `analyzer: errors: unnecessary_non_null_assertion: error` — a stored row's id is `int`, and `row.id!` hides the `!` that guards a real null (D-113) |
| `migrationChangesData` | error | An `INSERT`, `UPDATE` or `DELETE` in a migration (`lib/src/migrations/m*.dart`) that is not an argument of `m.backfill(…)` — content is a seed step. Reads the SQL strings: adjacent literals as one string, `--` comments dropped, an interpolated table name still a table; only the dollar-quoted body of a function or procedure being defined passes. Migrations up to `deploy/config.yaml` > `migrations` > `dataChecksAfter` are not judged — and moving that key forward exempts whatever it passes, which no check can see: the agent's skills make a diff that moves it a stop for the human. A write into a `dw_*` table is refused even through `backfill`; `m.carrySettings` is the one way ([Migrations](../4-server/migrations.md#a-migration-changes-the-schema)) |
| `workAfterServerStart` | error | `bin/server.dart` awaiting anything, or reaching `.db`, `.accounts` or `runInContext`, after the server's `start()` — the variable a `DwAppServer(…)` or `…Server.build(…)` was assigned to — in the same function; awaiting `stop()`/`close()` or a `ProcessSignal` passes ([Startup steps and seeds](../4-server/app-server.md#startup-steps-and-seeds)) |
| `settingsKeyValueTable` | error | A row class whose own body has a unique `String key` beside a `String value`: settings are a data object read through `ctx.settings` ([Settings](../4-server/database.md#settings)) |
| `fieldPatchMatched` | error | `DwSetField`, `DwClearField` or `DwKeepField` named in the code of the server, shared or Flutter package (`lib/`, `bin/`, `test/`; generated files exempt) — read a patch through its helpers ([Clearing a field](../2-core/data-objects-and-generation.md#clearing-a-field-dwfieldpatch)) |
| `forbiddenStateHolder` | error | A `StatefulWidget` (its `State`, `setState`, a `StatefulBuilder`), a `ChangeNotifier` or a `ValueNotifier` held as state, anywhere in the app's `lib/` but generated code — local state is hooks, shared state a `Notifier`. A class marked `// dw:allow-stateful <reason>` is passed over and listed |
| `forbiddenCommandCall` | error | `dw.command` outside a feature's `logic/` and `core/`, or inside a `try` that catches; a widget running `<Feature>Commands` outside `dw.action`, or reading a result (`DwCallOk`, `DwCallRefused`, `DwCallFailed`, `valueOrThrow`) outside `logic/` and `core/` |
| `routerDisposedByApp` | error | `<x>.router.dispose`, called or torn off (`ref.onDispose(router.router.dispose)`), anywhere in the app's `lib/` but generated code — `DwAppRouter` disposes itself with the provider that built it, and a second dispose fails in debug. Read from text: a `GoRouter` field named `router` on any object counts too |
| `forbiddenRequestRead` | error | The `AsyncValue` of `ref.watch/read(dw.request/pages/table/window(…))` taken apart outside `logic/` and widget-free files of `core/` — a member (`.value`, `.when(`, `.hasError`, …), a `switch` or `case` over it, a `.select` of the read, the values of a `ref.listen` over it. A screen shows a read through `DwReadBuilder`, `DwPagedListView` or `DwWindowListView`; its chrome through a `logic/` provider answering a plain value |
| `forbiddenProgressIndicator` | error | `CircularProgressIndicator`, `LinearProgressIndicator`, `RefreshProgressIndicator` or `CupertinoActivityIndicator` outside `ui_kit/` |
| `forbiddenNavigationCall` | error | `showDialog`, `showModalBottomSheet`, `showCupertino…` and their siblings, `Navigator.push…` or a page route (`MaterialPageRoute`, …) outside `ui_kit/` and `core/router/`; `Navigator.pop`, `GoRouter.of(…).pop` or `context.pop` anywhere |
| `sentinelId` | error | A route parameter set to `0` or `-1` — `…Params.<name>.set(0)` |
| `relativeImport` | error | A relative `import`/`export` in `lib/` of the Flutter, server or shared package — `lib/` imports by `package:` only. Generated files are passed over; `--fix` rewrites the rest |
| `testLayout` | error | A test that mirrors no `lib/` path (`test/<path>_test.dart` for `lib/<path>.dart`, `test/<path>/<folder>/<folder>[_<scenario>]_acceptance_test.dart` for `lib/<path>/<folder>/`), a helper outside `test/support/`, or a test inside it; `--fix` moves a root-level acceptance test to `test/src/<feature>/` |
| `testHarnessBypassed` | error | Outside `test/support/`: a `ProviderScope` or a `DwFakeServer` built by a widget test, a `DwTestServer.start` or a `DwAppServer` by a server test |
| `rawSpacing` | error | Outside `ui_kit/`: a number instead of an `AppSpace` step in a spacer `SizedBox`, a `Gap`, an `EdgeInsets.*`, or a `spacing:`/`runSpacing:`/`mainAxisSpacing:`/`crossAxisSpacing:` — conditionals included. Zero passes; a `SizedBox` with a `child:` or both dimensions, and `SizedBox.square`, are sizes, not spacing |
| `lintsPluginMissing` | error | The Flutter package's `analysis_options.yaml` does not enable the `dartway_lints` plugin; `dartway update --target <sha>` adds it after resolution preflight; plan first with `--plan` |
| `invalidSharedLayout` | error | The shared package's `lib/src/` holding anything but `<feature>.dart` or a flat `<feature>/` of `<feature>_<part>.dart` parts only — `<feature>` a feature folder of the server's `lib/src/`, a part never exactly a layer name, no `<feature>/<feature>.dart` — and the package-named `_channel`, `_refusal`, `_upload`, `_protocol`, `_push_category.dart`; a feature both as a file and a folder; in `lib/`, anything but the library (directives only), `generated/` (generated files only) and `src/`; a file with a generated suffix (`.dw.dart`, `.g.dart`, `.freezed.dart`) and no generated header. The finding names the owner of a near miss (`issue_process.dart` → `src/issues/issues_process.dart`) |
| `uiKitContainsText` | warning | A text constant in the kit; texts belong to features and l10n |
| `uiKitConstStyle` | warning | A `static const` colour or text style in the kit outside `ui_kit/theme/` — a token that will not follow a second theme |
| `fileTooLong` | warning | Over 350 lines, in the Flutter package's zones and layers but `ui_kit/`, and in the server's and the shared package's `lib/` — generated code, migrations and seed data passed over |
| `featureSpecMissing` | warning | A feature widget that declares no `DwFeatureSpec` |
| `forbiddenAssetPath` | warning | A raw `assets/...` path outside `ui_kit/` |
| `unusedFeatureFile` | warning | A file in `widgets/`/`logic/` that its own feature never mentions |
| `frameworkRefsDiverged` | warning | The project's `dartway_*` git dependencies are locked to more than one commit |
| `frameworkOverrideOutlived` | warning | A `dependency_overrides` version pin on a `dartway_*` package that a resolved framework package already allows — the override outlived the framework's own raise (D-032) |
| `forbiddenEnvironmentRead` | error | `Platform.environment` in the server's `lib/` outside `lib/src/core/environment.dart`, where `AppEnvironment` reads every variable at start; in `bin/`, `Platform.environment` outside `DwLocalEnvironment.overlay(…)` or a map read by a variable's name (`env['PORT']`) |
| `forbiddenHttpClient` | error | `HttpClient(` or an import of `package:http/…` in the server's `lib/` — an outbound request is `ctx.http` |
| `localSecretMissing` | warning | A secret under the hoisted `requires.secrets` of `deploy/config.yaml` with no value for `local`, in either half |
| `docCommentLanguage` | warning | A doc comment in `lib/` written in a script other than the language `dartway setup-ai --language` recorded — a heuristic on Cyrillic against Latin letters, so it warns and never fails. A comment the skeleton wrote (the same text in the template the project came from) is not judged, nor a generated file |
| `devComposeDrifted` | warning | The server package's `docker-compose.yaml` creates the development containers with credentials or a port that `deploy/config.yaml > local` does not name |
| `inlineOwnershipCheck` | warning | A handler in a `*_handlers.dart` under any rule but a resource rule (`signedIn`, a role check) that compares a row's owner field with the caller and refuses `notFound`/`forbidden` (or answers `null` from a `single`), in its body or a helper of the file it calls — the check `DwAccessRule.resource` makes once |
| `fileLong` | info | Over 200 lines, where `fileTooLong` looks |

"Raw styles" means `Color(`, `TextStyle(`, `BorderRadius.`/`BorderRadius(`, `Theme.of(`,
`context.theme`, `context.textTheme`, `context.colorScheme`. The long spelling is on the list on
purpose: `Theme.of(context).textTheme.bodySmall` reads as ordinary Flutter and means exactly what
`context.textTheme` means — a screen deciding how it looks.

## Reads, loading, dialogs and routes: one way each

A screen shows a read through **`DwReadBuilder`** — loading as a skeleton or the app's loading view,
a branch per refusal code (`onRefused`), the app's failed view with a retry, data — or, for a feed
read page by page, **`DwPagedListView`**, and for a chat, `DwWindowListView`. What
`forbiddenRequestRead` refuses is the `AsyncValue` of a read taken apart by hand in a widget: a
member of `ref.watch(dw.request(…))`, chained or through the name it is bound to — with or without
`final`, typed or not, the same name in every block it is bound in (`.value`, `.when(`, `.hasError`,
`.section(` of a project's own extension) — a `switch` or a `case` over it (`AsyncError(…)`), the
values a `ref.listen` over it hands its callback, and a `.select` of the read. `logic/` is passed
over, and so is a file of `core/` that declares no widget: a controller or a provider may watch a
read to derive its own state — a plain value with a fallback for the chrome, an `AsyncValue` for
`DwReadBuilder.derived` — and the widget watches that. A widget in `core/` is judged like any other.

Loading is the kit's: `forbiddenProgressIndicator` refuses Flutter's progress indicators outside
`ui_kit/`. A dialog or a sheet is opened through the kit and a screen is a route of a zone:
`forbiddenNavigationCall` refuses the raw `show…` functions, `Navigator.push…` and the page routes
outside `ui_kit/` and `core/router/`. A page goes back with `goNamed(<parent>)` or the `AppBar`'s
leading button, and `Navigator.of(context).pop(…)` closes a dialog or a sheet with the builder's own
context; `Navigator.pop(context)`, `GoRouter.of(context).pop()` and `context.pop()` are findings
everywhere, while `Navigator.of(context).pop` on a page is not told apart from one in a dialog and
is left to reading. `sentinelId` refuses a route parameter set to `0` or `-1`
(`AdminParams.courseId.set(0)` — the parameter enums are `…Params`, which is what tells them from
`DwFieldPatch.set(0)`): a new thing is a route of its own, "none" is `null`.

All four read the source with comments and strings blanked, so they see what a text can show. Left
out on purpose: a read reached through a provider of the project's own (`myProfileProvider` over
`dw.request`) or handed to a function before it is taken apart; a closure parameter named like the
read is not the read; an id in a command's constructor (`SaveCourse(id: 0)`) reads the same as the
stand-in data a skeleton is drawn from, and an id compared with `0` in a page reads the same as a
count, so both are prose, not checks; and a one-shot "focus" notifier standing in for a route
parameter has no shape a text can tell.

## The declared top level

`packages/dartway_cli/lib/src/checker/dw_layout.dart` declares the top level of both packages as a
closed list:

| Package | May hold | Must hold |
|---|---|---|
| `<project>_flutter/lib` | zones `admin/ app/ auth/ common/` · layers `core/ l10n/ shared/ ui_kit/` · `main.dart` · `<project>_app.dart` | `main.dart`, `<project>_app.dart` |
| `<project>_server/lib` | `<project>_server.dart` · `generated/` · `src/` | `<project>_server.dart`, `src/`, and `src/migrations/migrations.dart` |

Dot entries and the folders `generated/`, `gen/`, `l10n/` and `.dart_tool/` are passed over. Inside
the server's `src/`, `migrations/` is a fixed name (`bin/migrate.dart` writes and reads it by that
path), every other folder but `core/` is a feature, and a feature's own files are a closed set held by
`dw_server_features.dart` (`invalidServerFeatureFile`, `misplacedServerCode`). How the features import
and write one another is `dw_feature_imports.dart`: from the `import`/`export`/`part` directives of
every file under `src/`, `package:` or relative, it builds the graph of features and fails a cycle
(`featureImportCycle`), a file of `core/` importing a feature (`coreImportsFeature`), an import of
another feature's file outside its surface or of the package's library (`featureImportOutsideSurface`);
from the generated schema and the row classes it knows which feature owns each `db.<table>`, and
fails a write into it from anywhere else (`foreignRowWrite`).

The shared package's top level is `dw_shared_layout.dart`'s (`invalidSharedLayout`): `lib/` holds
`<project>_shared.dart` (directives only), `generated/` (Dart files with a generator header and the reserved `dw_contract.json` descriptor) and
`src/`, and `src/` mirrors the server — a file or a flat folder of parts per feature folder of the
server's `lib/src/`, read from the server package in the same run, plus the files named after the
package. There is no shared `core/`. Without a server package the names are not matched, and the
run says so.

A zone name or a layer name one level down — `app/admin/` — is an error too, and it is the reason the
check exists at all: a folder inside a zone is an ordinary group to every other rule, so a misplaced
admin panel compiles, runs and looks deliberate. There is deliberately no `data/` (the data layer is
`dw.request` and `dw.command` over the shared contract) and no `domain/` (the rules live in the shared
package, where both sides apply them, and in the server's handlers). What each folder is for is
[Project layout](../1-getting-started/project-layout.md).

## The feature tree, and the grade

`packages/dartway_cli/lib/src/checker/dw_feature_tree.dart` builds the tree of each zone from the
folders themselves — nothing is declared:

- a folder with a root `.dart` file is a **feature**, and that one file is its whole public surface;
- a folder with no root `.dart` file is a **group**: it only groups features and encapsulates nothing,
  so feature rules do not apply to it;
- `widgets/` and `logic/` are a feature's internals, not children. Any other subfolder is a nested
  feature or group, judged on its own.

Generated files (`.g.dart`, `.gen.dart`, `.freezed.dart`) are nobody's code and are left out.

Scope is two scopes rather than one. The **feature-shaped** areas are the four zones, which must be
built of features and are asked for a `DwFeatureSpec`. The **checked** areas add `shared/`: its files
are read for the cleanliness and kit rules, but no spec is expected, because a helper has no product
behaviour to describe. `ui_kit/` has its own pass. `core/` is skipped entirely — a known gap,
left open as a decision rather than an oversight.

The report is organised **per feature**, so a large project reads as a list of features to fix rather
than a wall to scroll past:

```
📁 Features (grade · files · findings)

app/
  ✅ profile                          A  4 files
  🟠 invoices                         C  9 files · 2 errors, 1 warning
    ✅ invoice_card                   A  2 files
  billing/ — group
    🟡 payment                        B  6 files · 1 warning
```

| Grade | Meaning |
|---|---|
| ✅ A | No errors, no warnings (infos allowed) |
| 🟡 B | No errors, some warnings |
| 🟠 C | One or two errors |
| 🔴 D | Three or more errors |

Then the findings by feature (the first six of each), a count per check, and one verdict line counted
over every pass.

## Generated code and migrations: what the server owes its sources

**`generatedCodeStale`** runs the generator the server package resolved in check mode. The codecs are
the wire, so this has no second reading: a request missing from the registry is refused as unknown by
a server that has its handler, and a field missing from a codec simply does not travel. The fix it
prints is `dart run dartway_cli:dartway generate`, and generated files are never edited by hand. See
[Data objects and generation](../2-core/data-objects-and-generation.md).

**`migrationsDrift`** runs the project's `bin/migrate.dart check`, which replays the migrations on
throwaway databases next to the one `DW_DATABASE_*` — or `deploy/config.yaml > local`, which the
check reads the same way the entry points do — names — so it needs a Postgres where databases can
be created; the development one will do. It fails on migrations that do not produce the schema the
row classes declare, a migration edited after its checksum was sealed or left unregistered, and a down
that does not undo its up. The fixes it prints: a schema change the migrations miss is
`dart run bin/migrate.dart create <name>`; an edited migration applied nowhere yet is
`dart run bin/migrate.dart rehash <id>`. An error, because a schema the migrations do not produce is a
server that refuses to start in the next environment. See [Migrations](../4-server/migrations.md).

**`forbiddenEnvironmentRead` and `forbiddenHttpClient`** hold one way to each of two things a server
reaches outside itself. The environment is read in `lib/src/core/environment.dart`, into a typed
`AppEnvironment` at start: a variable read anywhere else is read on first use — a missing one surfaces
hours after a deploy that looked fine — and past the local overlay, so `deploy/config.yaml > local`
never reaches it. An entry point in `bin/` hands the environment in and reads nothing itself:
`Platform.environment` there only as the argument of `DwLocalEnvironment.overlay(…)`, and no map
read by a variable's name — `bin/server.dart` reads through `AppEnvironment.read`. An outbound request is
`ctx.http`, bounded by a timeout, logged and answered by the test server's fake; a client of a project's
own has none of that unless it is written again, with a test seam of its own threaded through the
server's factory; a client a command-line entry point uses with no server behind it lives in `bin/`,
which this check does not judge. **Known limits:** another client package (`dio`, or `package:http`
reached through a package that re-exports it), `WebSocket.connect`, a conditional import naming
`package:http`, and an environment read through a helper in `bin/` that does not subscript a literal
name are not seen. See [The app server](../4-server/app-server.md#configuration-comes-from-the-environment)
and [Handlers and the call context](../4-server/handlers-and-context.md#outbound-http).

**`localSecretMissing` and `devComposeDrifted`** judge the environment this machine starts a server
with (D-078). Both are warnings: a key the server only reaches on a path nobody runs locally is a
legitimate thing to leave unset, and a project that points `local` at a database of its own is not
drifting. What they end is the silent case — a developer who does not know a key exists because the
only place it was written down was a deployment's configuration, and two files stating the same
password with nothing making them agree. `dartway secret list --env local` is the same answer on
demand.

**`inlineOwnershipCheck`** looks for "is this row mine" written by hand after any rule that is not a
resource rule — `DwAccessRule.signedIn`, a role check — the check `DwAccessRule.resource` makes once, before the handler, with the row handed over as
`ctx.accessed<R>()` (D-090). It reads `*_handlers.dart` files of the server's `lib/`: an `if` whose
condition compares a row's field named for an owner (`…ProfileId`, `authorId`, `ownerId`,
`senderId`, `accountId`, …) with the caller (`me`, `profile`, `ctx.accountId`, …) with `!=`, and
whose branch refuses `notFound` or `forbidden` — or answers `null` from a `single` handler, which the
framework refuses `notFound`. A helper counts when such a handler of the same file calls it. A rule
is a resource rule when it is `DwAccessRule.resource` itself or a project rule (`ProfileAccess.ownTask(…)`)
whose declaration in the server's `lib/` builds one. A warning, because it reads the shape of the code
rather than its meaning; it stays quiet on a list filtered by the caller in its `where` (the
canonical "my rows"), on handlers under a resource rule, and on a membership read from a table of its
own. The one pattern per shape is in
[Access and roles](../2-core/access-and-roles.md#whose-row-is-it-one-rule-per-shape).

## State and commands: one way each, and one visible way out

A widget's own state — a controller, a focus node, an animation, a timer, a subscription, a toggle —
is held by hooks (`HookWidget`/`HookConsumerWidget`: `useTextEditingController`, `useFocusNode`,
`useAnimationController`, `useEffect` returning its cleanup, `useState`); what `didUpdateWidget` did
is a `useEffect` keyed on the prop. State two widgets share, or a flow with logic, is a Riverpod
`Notifier` named `<Thing>Controller` in the feature's `logic/`. `forbiddenStateHolder` reads every
file of `lib/`, `core/` and `ui_kit/` included — a kit field is where a `StatefulWidget` hides best.

**The way out is written on the class and counted.** A third-party API that needs a `State`
subclass or a `Listenable` of its own (a map SDK that calls into a `State`) takes one comment on the
line above the class, doc comments and annotations allowed between. The skeleton and the example
have none — the router follows a provider, not a `Listenable`:

```dart
// dw:allow-stateful the map SDK calls into a State subclass
class VenueMapView extends StatefulWidget { … }
```

The class — and, for a widget, its `State` — is passed over, and every run prints it under
`🔓 Allowed by dw:allow-stateful` with the reason. A marker with no reason, or on no class, is a
finding itself. The exception stays in sight rather than spreading.

**`forbiddenCommandCall`** holds the command canon: `dw.command` sent from a feature's `logic/`
(`<feature>_commands.dart`, or a flow's controller) — or from `core/`, the app-wide wiring no button
starts (a push token, a bootstrap step) — never inside a `try` that catches; a widget
runs `<Feature>Commands.x(…)` only inside `dw.action(…)` and reads no result. A value the widget
needs is unwrapped in `logic/` (`valueOrThrow`) and arrives in `followUpIfMountedAction`; a refusal
becomes words only through `DwFlutterConfig.refusalText`, the app's catalogue in `lib/core/`. That
last rule is **stated, not held**: nothing tells a sentence built from a refusal code in a
controller from any other string, and a guess would flag the wrong ones.

Both are read from the source with comments and strings blanked, so they see what a text can show:
a flow controller's method run outside `dw.action` is not caught (its name says nothing), nor a
state holder reached through a subclass of the project's own, nor a `Notifier` not named
`<Thing>Controller`, nor a command sent under another spelling than `dw.command` or
`<Feature>Commands.x(…)` — a plugin's method (`dw.plugins.analytics.saveDashboard`) or
`dw.files.getLink` from a widget — nor refusal text built outside the catalogue. A `<Feature>Commands`
class holds command senders only — a pure helper on it reads as a command sent outside `dw.action`.
Only the first argument of `dw.action(…)` counts as inside it: a command in
`followUpIfMountedAction` runs after the action's refusal handling is over.

## Why `notAFeature` and `featureSpecMissing` are one rule

They read one rule from both ends, and neither works alone. A zone holds features: a folder in one
whose entry point declares no widget is not a feature at all (`notAFeature`, an error), and one that
does declare a widget owes a passport (`featureSpecMissing`). While only the second existed, a
provider-only folder passed *because* it was not a widget — a real project accumulated ten of them,
every one graded A.

Where they go instead: state that several features watch is wiring, so `lib/core/`; a helper with no
story of its own goes to `lib/shared/`, or to `lib/ui_kit/` when it draws something.

The widget test asks whether a **public class extends anything named `*Widget`**, not whether it
matches a list of base classes. A list of remembered names once missed `ConsumerStatefulWidget` —
what every form and dialog extends, which is to say the features with the most behaviour to describe.
A list goes stale in silence; a shape does not.

The spec matters because error reports, Studio and the agent all read it: without one the feature
exists in the code and says nothing about itself. See [Features and specs](../3-flutter/features-and-specs.md).

## Why `unusedFeatureFile` is possible at all

A public class is always "possibly used from somewhere else" — unless the somewhere else is a finite
place, and the feature boundary makes it one: nobody outside a feature may import its
`widgets/`/`logic/`, so a file in there that its own feature never mentions is unreachable. It
compiles, it survives refactors, and it is found in a pass one folder deep.

Four things it does *not* get wrong, because each once cost a real false positive:

- **a type is not how it is called** — an extension is reached by member name, a notifier through its
  provider variable, so every public name a file declares counts;
- **a function is a declaration too** — a file whose only public member is a top-level function is
  judged on that function's name, not on the locals inside it;
- **a conditional import is one symbol in several files** — `foo.dart` forwarding to `foo_stub.dart` /
  `foo_web.dart` answers as one unit, alive or reported together;
- **dead code keeps dead code alive** — the sweep repeats until a pass buries nothing.

What it cannot see: a reference made through a string, and a file whose halves only reference each
other. The finding names where the file should go instead — `lib/shared/` (`lib/ui_kit/` for a
widget), `lib/core/`, or
`lib/core/platform/` for a platform trio — because "dead code" is half an answer: a file its own
feature stopped using is often a file somebody else needs.

## Why `frameworkRefsDiverged` is a warning

It is the one check that reads no Dart. A project consuming DartWay by git writes `ref: master` on
every framework package, which reads as "all of it from master" and is not what the lock does: a git
dependency is pinned to a commit the moment it is *added*, and stays there until something upgrades it
by name — and a git dependency carries no version number, so nothing makes the gap visible. The check
reads the `pubspec.lock` at the project root and in each package beside it, groups the `dartway_*` git
entries by repository, and reports a repository locked to more than one commit, naming the packages,
the commits and the directories to run `dart pub upgrade` in. Hosted packages are left out: semver
already answers for them.

A warning, because the state is wrong while the code is not, and what fixes it is a command rather
than an edit.

## Why `l10nNotWired` is an error, and the only one you cannot cause

Every other rule here catches something written. This one catches something **never done**. An app
with no localization wiring has broken no convention: its widgets hold their text because there was
nowhere else to put it, the compiler is happy, and every other check is silent. It is reachable one
way — a project adopting the methodology from somewhere else, since `dartway create` ships all four
pieces. In the case that produced this rule it was around 450 strings in some 150 files, surfaced by
a person noticing one menu item in the wrong language.

Every project is localized; that is a requirement, not a report on how the project began. The finding
names **which** of the four pieces is missing, because the half-wired states produce the strangest
errors — an `.arb` with no `generate: true` generates nothing, and the failure reads as a missing key.

## Why 200 and 350

Length is the **weakest signal the checker has**, and a tight limit makes it lie. A feature's
`DwFeatureSpec` lives in the file of the feature it describes, and a good description costs twenty
lines; a rule that goes off when someone documents a feature properly teaches them to document less.
So nothing is said below 200 lines, above it is a nudge that never fails anything, and above 350 a
warning — at that size a file has usually collected more than one responsibility. Split by
responsibility, not by line count.

The same two numbers hold in the server and the shared package (`dw_package_file_size.dart`), at the
same levels — a handler file of 1900 lines is a warning, not a failed build. Three kinds of file are
passed over, because none of them collects responsibilities: generated code (`lib/generated/`,
`*.dw.dart`, `*.g.dart`, `*.freezed.dart` — each only with its generated header), the server's
migrations (drafted, then sealed), and, on the server, **seed data** — a file of directives and
top-level `const`s each initialised with a row draft (`New<Entity>Row(…)`) or a collection of nothing
but drafts, which is what a `DwSeedRows` catalogue in its own `<feature>_<part>_rows.dart` looks
like. It is recognised by what it declares, so one class, function, `final`, other constant or
helper call beside the rows and the file is measured. Tests are not measured on either side: a test file is a list of independent cases, and
one that grows splits by scenario.

## Why `SizedBox(width: double.infinity)` is not in `widgetSizesItself`

`widgetSizesItself` fires on exactly two things, and only when `build` returns them: `Expanded` and
`SizedBox.expand`. Both mean the widget decided how much room it gets; it works until someone puts it
in a bottom sheet or a scroll view, and then it throws at runtime while the analyzer stays silent.
Space is the parent's call.

`SizedBox(width: double.infinity)` was tried and taken back out: inside a bounded parent it only means
"as wide as allowed", so every hit was arguable. **A check whose findings are arguable teaches people
to skip the checker** — and then its real findings get the same shrug. The same principle runs
through the rest: a string in a kit doc comment is not a text constant, and a generated file is not
asked for a `part of` directive that the next generator run would remove.

## Why `barrelFile` is an error

A file whose whole body is `export` directives reads as convenience and acts as a hole in the feature
boundary: importers name the barrel, so reaching into another feature's internals through it looks
legitimate, and the import checks see a barrel rather than the internals behind it. One such file
laundered three features' internals until it was deleted. A single-line re-export counts too: the
same hole, smaller.

## Why asset paths are checked against the file system

DartWay projects run no asset code generator, so asset paths are written by hand — and a hand-written
path, unlike a generated constant, can name a file that does not exist. `assetPathMissing` restores
that guarantee, and `forbiddenAssetPath` keeps the paths in one place: a path spelled out in a screen
survives a renamed file only by accident and cannot be found by search. The screen should receive a
widget, not a file name.

## One way to write the ordinary things

The audit of three projects on the rewrite found each ordinary thing written three ways at once:
imports relative and `package:` in the same file, comments switching language mid-file, tests split
by kind, by feature and by scenario with their own `ProviderScope`s, and fourteen values of `Gap`.
None of it breaks a build, and an agent copies whichever shape it saw last. So step 8 holds one shape
for each.

- **`package:` only, in every package** (`relativeImport`). A file importing one library under two
  names is the smallest way a codebase stops being searchable, and a relative import was the one path
  the feature and kit import rules above could not see. Under `test/` a relative import of
  `test/support/` is the only form Dart has, and is allowed at any depth. It lives here rather than in
  `dartway_lints` because the plugin is enabled in the Flutter package only; the server and the
  shared package are held by the same check.
- **A test sits at the path of what it tests** (`testLayout`): `lib/app/home/home_page.dart` →
  `test/app/home/home_page_test.dart`; a whole folder — a server feature through its calls — is
  `test/src/chat/chat_acceptance_test.dart` for `lib/src/chat/`, and a scenario of it
  `test/src/chat/chat_attachments_acceptance_test.dart`, the `<feature>_*` naming a feature's own
  files follow. A scenario across features names the feature that owns it. The acceptance form names
  the folder rather than its `_feature.dart`, because it drives the feature's handlers, rows and
  publications together, which is a test of the folder, not of the file that registers it. Helpers are in
  `test/support/`, and the harness there is how a test starts what it needs
  (`testHarnessBypassed`).
- **Spacing is a token** (`rawSpacing`): the kit's `AppSpace` scale, a closed set named by value, so
  a project has one set of gaps rather than one per screen. A value that belongs to one component
  stays inside it, in the kit.
- **Doc comments in the project's language** (`docCommentLanguage`) is a warning: it reads scripts,
  not languages, and a guess must not fail a build. A comment the skeleton wrote is the skeleton's —
  the check compares with the template the project was created from (the checkout the toolkit was
  installed from, this CLI's own, or the `dartway create` cache, at the recorded commit when it has
  it) and judges only what the project wrote; without a checkout it judges everything and says so.
  Log and error strings are English either way.
- **The lint plugin is on** (`lintsPluginMissing`): a project created before `dartway create` wired
  `dartway_lints` never had its rules, and nothing said so — `flutter analyze` runs no plugins.

`projectContractVersion` shares one resolved generator invocation with `generatedCodeStale`,
assessing current source models in memory. It reads baseline descriptors from Git objects and
reports the fixed SHA and descriptor/bootstrap proof. Incompatible, unsupported and unverified
results block the check, including an unavailable generator. Resolve dependencies separately;
checks launch the resolved generator directly and never run pub, setup or historical SDK scripts.
See [project contract compatibility](../2-core/wire-and-versions.md#the-generated-project-contract-gate).
