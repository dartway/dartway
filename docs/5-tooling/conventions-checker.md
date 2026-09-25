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

1. **the declared top level** of the Flutter package and the server package (`invalidTopLevelLayout`);
2. **localization wiring** (`l10nNotWired`);
3. **generated code**: `dart run dartway_generator --project <root> --check` in the server package
   (`generatedCodeStale`);
4. **migrations**: `dart run bin/migrate.dart check` in the server package (`migrationsDrift`);
5. **framework locks** across the project's `pubspec.lock` files (`frameworkRefsDiverged`);
   and **framework overrides** that the framework has caught up with (`frameworkOverrideOutlived`);
6. **the `local` environment**: a declared secret it has no value for (`localSecretMissing`), and the
   development containers' credentials against what the server is told to reach them by
   (`devComposeDrifted`);
7. **the Flutter package**: the UI kit, the feature tree of every zone, and the content of every file
   in the zones and `shared/` — the other sixteen checks.

`--dir <folder>` (relative to the Flutter package) narrows the run to that folder of step 7 and skips
steps 1–6 and the UI kit pass: each of those judges a whole package or the whole project, and has
nothing to say about one folder. `--type <check>` runs one check by name; `--level
info|warning|error` runs the checks of one severity.

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

Fifteen errors, ten warnings, one info — `DwCheckType` and its `severity` in
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
| `invalidTopLevelLayout` | error | A folder or file the declared top level does not name, a fixed name that is missing, or a top-level name nested inside a zone; in the server's `lib/src/`, a file, a layer folder (`handlers/`, `rows/`, `domain/`, …) or a feature folder without its `<feature>_feature.dart` |
| `generatedCodeStale` | error | A generated file that `dart run dartway_cli:dartway generate` would write differently, or whose source is gone |
| `routeNameDuplicated` | error | Two navigation zones declare a route of the same name — names are global in `DwAppRouter`, which otherwise refuses to build on the first frame |
| `contractNameInvalid` | error | A DTO in the shared package named against the naming law: one word (`Dw` is not a word), a read not named `Get…`/`List…`, a command named like a read. Judged by the framework base a class extends directly |
| `migrationsDrift` | error | Migrations that do not produce the declared schema, edited after sealing, unregistered, or with a down that does not undo its up |
| `uiKitContainsText` | warning | A text constant in the kit; texts belong to features and l10n |
| `uiKitConstStyle` | warning | A `static const` colour or text style in the kit outside `ui_kit/theme/` — a token that will not follow a second theme |
| `fileTooLong` | warning | Over 350 lines |
| `featureSpecMissing` | warning | A feature widget that declares no `DwFeatureSpec` |
| `forbiddenAssetPath` | warning | A raw `assets/...` path outside `ui_kit/` |
| `unusedFeatureFile` | warning | A file in `widgets/`/`logic/` that its own feature never mentions |
| `frameworkRefsDiverged` | warning | The project's `dartway_*` git dependencies are locked to more than one commit |
| `frameworkOverrideOutlived` | warning | A `dependency_overrides` version pin on a `dartway_*` package that a resolved framework package already allows — the override outlived the framework's own raise (D-032) |
| `localSecretMissing` | warning | A secret under the hoisted `requires.secrets` of `deploy/config.yaml` with no value for `local`, in either half |
| `devComposeDrifted` | warning | The server package's `docker-compose.yaml` creates the development containers with credentials or a port that `deploy/config.yaml > local` does not name |
| `fileLong` | info | Over 200 lines |

"Raw styles" means `Color(`, `TextStyle(`, `BorderRadius.`/`BorderRadius(`, `Theme.of(`,
`context.theme`, `context.textTheme`, `context.colorScheme`. The long spelling is on the list on
purpose: `Theme.of(context).textTheme.bodySmall` reads as ordinary Flutter and means exactly what
`context.textTheme` means — a screen deciding how it looks.

## The declared top level

`packages/dartway_cli/lib/src/checker/dw_layout.dart` declares the top level of both packages as a
closed list:

| Package | May hold | Must hold |
|---|---|---|
| `<project>_flutter/lib` | zones `admin/ app/ auth/ common/` · layers `core/ l10n/ shared/ ui_kit/` · `main.dart` · `<project>_app.dart` | `main.dart`, `<project>_app.dart` |
| `<project>_server/lib` | `<project>_server.dart` · `generated/` · `src/` | `<project>_server.dart`, `src/`, and `src/migrations/migrations.dart` |

Dot entries and the folders `generated/`, `gen/`, `l10n/`, `zarchive/`, `zarchiv/` and `.dart_tool/`
are passed over. Inside `src/` the server is the project's to arrange, except `migrations/`, which
`bin/migrate.dart` writes and reads by that path.

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
are read for the cleanliness and kit rules, but no spec is expected, because a building block has no
product behaviour to describe. `ui_kit/` has its own pass. `core/` is skipped entirely — a known gap,
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

**`localSecretMissing` and `devComposeDrifted`** judge the environment this machine starts a server
with (D-078). Both are warnings: a key the server only reaches on a path nobody runs locally is a
legitimate thing to leave unset, and a project that points `local` at a database of its own is not
drifting. What they end is the silent case — a developer who does not know a key exists because the
only place it was written down was a deployment's configuration, and two files stating the same
password with nothing making them agree. `dartway secret list --env local` is the same answer on
demand.

## Why `notAFeature` and `featureSpecMissing` are one rule

They read one rule from both ends, and neither works alone. A zone holds features: a folder in one
whose entry point declares no widget is not a feature at all (`notAFeature`, an error), and one that
does declare a widget owes a passport (`featureSpecMissing`). While only the second existed, a
provider-only folder passed *because* it was not a widget — a real project accumulated ten of them,
every one graded A.

Where they go instead: state that several features watch is wiring, so `lib/core/`; a helper with no
story of its own is a building block, so `lib/shared/`.

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
other. The finding names where the file should go instead — `lib/shared/`, `lib/core/`, or
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
