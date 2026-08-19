# Why a checker when you already have the analyzer?

`dartway check` looks at the things the analyzer and the lints cannot see. The analyzer reads a
file; the checker reads the **project**: which folder is a feature, who imports whose internals,
whether a screen styles itself, whether an asset path leads anywhere. All of that compiles. Some
of it fails at runtime, some of it never fails and just rots.

Three examples of what nothing else catches:

- a file spelling out `assets/icons/lock.png` when no such file exists — the code compiles and the
  screen renders a blank where the image was;
- one feature importing another's `widgets/` — perfectly valid Dart, and the boundary is gone;
- `Theme.of(context).textTheme.bodySmall` in a screen — ordinary Flutter, and the reason your app
  has two greys.

The checker is not a second analyzer. It exists because DartWay's structural conventions are the
part of the framework that a compiler has no opinion about.

## Where a rule belongs: the deciding question

DartWay enforces its conventions in three places, and picking the wrong one is how a rule ends up
disliked and switched off. The question is not "how important is this" — it is **whether the answer
is decidable without understanding what the code means**.

| The answer is… | Where the rule goes | Example |
|---|---|---|
| decidable from the shape of an expression | `dartway_lints` (a `custom_lint` rule, live in the IDE) | is this a raw `Color` outside `ui_kit/`? |
| decidable from the shape of the project | `dartway check` | does this folder in a zone declare a widget? is `data/` in the declared layout? |
| **only decidable by reading the meaning** | `/dartway-checkup` | is this string something a *user* reads, or is it an identifier, a key, a date pattern? |

The third row is the one worth defending. `'Issues'`, `'issues/board'` and `'dd.MM'` are the same
shape and different things, so a mechanical rule about hardcoded text can only guess — and a guessing
rule grows an exception list with every complaint until somebody turns it off. That is not
hypothetical: `uiKitContainsText` carries nine hand-grown exceptions today — the ninth being the
`fontFamily` / `fontFamilyFallback` argument positions, where the string is a typeface the platform's
font matcher reads and nobody else does, with nowhere to be moved to since the kit is exactly where
fonts belong — and it survives only because its scope is narrow enough for the guess to be safe (a
kit file has no content to speak of). Widened to features, the same rule would be noise.

That last exception is positional rather than per line, and deliberately so: the literal in the
`fontFamily` argument is stepped over and the reading continues, so a real label sharing the line is
still found. An exemption that swallows the whole line is how a rule stops firing without anyone
noticing.

A rule that needs understanding is not a weaker rule. It is a rule for a reader.

## Three commands, and none of them implies the others

A DartWay project has three separate gates, and each has to be run by name:

```bash
flutter analyze            # the analyzer and the lint set
dart run custom_lint       # DartWay's own rules
dartway check              # the structural conventions
```

**`flutter analyze` does not execute `custom_lint` plugins.** This trips everyone once: `dartway_lints`
is declared in `pubspec.yaml`, `custom_lint` is listed under `analyzer: plugins:`, the IDE underlines
violations — and a CI running only `flutter analyze` reports a clean build while enforcing none of it.
A real project shipped that way for months; the code turned out to be clean, but nothing had been
guarding it.

**A project's CI runs all three, plus its tests.** Not because CI is a virtue, but because these are
the checks the project has already declared: a rule configured and not executed is worse than a rule
absent, since it reads as covered. Two consequences worth stating outright:

- **if a package has a `test/` folder, CI runs it.** A suite excluded from CI stops compiling, and
  nobody learns that from the exclusion comment. One project's server tests — including the suite
  proving one tenant cannot read another's data — had never run; the first CI run that saw them
  found a test that only passed on the author's operating system;
- **"it does not compile against the new API" is a red CI, not a note in a workflow file.**

## What the report looks like

The report is organised **per feature**, not as a flat list of lines. A large project should read
as a list of features to fix, not as a wall to scroll past.

```
📁 Features (grade · files · findings)

app/
  ✅ profile                          A  4 files
  🟠 booking                          C  9 files · 2 errors, 1 warning
    ✅ slot_card                      A  2 files
  learning/ — group
    🟡 lesson                         B  6 files · 1 warning
```

The tree is built from the folders themselves — nothing is declared. A folder with exactly one
root `.dart` file is a **feature**, and that file is its whole public surface; a folder with no
root `.dart` file is a **group** that only groups features and encapsulates nothing. `widgets/`
and `logic/` are a feature's internals, not children.

The grade of a feature comes only from what belongs to it:

| Grade | Meaning |
|---|---|
| ✅ A | No errors, no warnings (infos are allowed) |
| 🟡 B | No errors, some warnings |
| 🟠 C | One or two errors |
| 🔴 D | Three or more errors |

Then findings by feature (the first six of each), then a count per check, then the total number of
errors. **Only errors fail the run.** Warnings and infos print and pass — a check that blocks a
commit over a 210-line file is a check people disable.

## The checks

| Check | Level | What it means |
|---|---|---|
| `forbiddenUiUsage` | error | Raw styles outside `ui_kit/` — the screen is styling itself |
| `forbiddenUiKitImport` | error | Importing inside `ui_kit/` instead of the `ui_kit.dart` barrel |
| `uiKitPartMissing` | error | A kit file without `part of '../ui_kit.dart'` |
| `uiKitContainsText` | warning | A text constant in the kit; texts belong to features and l10n |
| `invalidTopLevelLayout` | error | A folder or file the declared top level does not name, or a fixed name that is missing |
| `frameworkRefsDiverged` | warning | The project's `dartway_*` git dependencies are locked to more than one commit |
| `invalidFeatureStructure` | error | A feature folder with more than one root file |
| `forbiddenFeatureImport` | error | Reaching into another feature's `widgets/` or `logic/` |
| `featureSpecMissing` | warning | A feature widget that declares no `DwFeatureSpec` |
| `notAFeature` | error | A folder in a zone whose entry point declares no widget |
| `unusedFeatureFile` | warning | A file in `widgets/`/`logic/` that its own feature never mentions |
| `barrelFile` | error | A file that only re-exports |
| `widgetSizesItself` | error | `Expanded` or `SizedBox.expand` returned straight from `build` |
| `assetPathMissing` | error | An `assets/...` string that names no file |
| `forbiddenAssetPath` | warning | A raw `assets/...` path outside `ui_kit/` |
| `fileLong` | info | Over 200 lines |
| `fileTooLong` | warning | Over 350 lines |
| `generatedCodeUnformatted` | warning | The server's `lib/src/generated/` or the client's `lib/src/protocol/` differs from `dart format` |

"Raw styles" means `Color(`, `TextStyle(`, `BorderRadius`, `Theme.of(context)`, `context.theme`,
`context.textTheme`, `context.colorScheme`. The long spelling is in the list on purpose: the rule
used to catch `context.textTheme` but not `Theme.of(context).textTheme.bodySmall`, which reads as
ordinary Flutter and means exactly the same thing — a screen deciding how it looks.

"More than one root file" is a structural claim, not a style one. A feature has exactly one public
file; behaviour a sibling also needs belongs in a feature of its own. A widget with no story of its
own is not a feature at all — it is a building block, it lives in `lib/shared/`, and the checker
never asks it for a spec.
**`notAFeature` and `featureSpecMissing` are one rule read from both ends**, and neither works
alone. A zone holds features: a folder in one whose entry point declares no widget is not a feature
at all (`notAFeature`), and one that does declare a widget owes a passport (`featureSpecMissing`).
While only the second existed, a provider-only folder passed *because* it was not a widget — a real
project accumulated ten of them, every one graded A.

Where they go instead: state that several features watch is wiring, so `lib/core/`; a helper with no
story of its own is a building block, so `lib/shared/`.

The widget test asks whether a **public class extends anything named `*Widget`**, not whether it
matches a list of base classes. The list used to be
`(Stateless|Stateful|Consumer|HookConsumer|Hook)Widget` and silently missed `ConsumerStatefulWidget`
— what every form and dialog extends, which is to say the features with the most behaviour to
describe. A list of remembered names goes stale in silence; a shape does not.

The spec matters because error reports, Studio and the agent all read it: without one the feature
exists in the code and says nothing about itself.

**`unusedFeatureFile`** (warning) is the one check the analyzer structurally cannot replace. A public
class is always "possibly used from somewhere else" — unless the somewhere else is a finite place,
which Law 3 makes it: nobody outside a feature may import its `widgets/`/`logic/`, so a file in there
that its own feature never mentions is unreachable. It compiles, it survives refactors, and it is
found in one folder-deep pass.

Four things it does *not* get wrong, because every one of them cost a real false positive before it
was fixed:

- **a type is not how it is called** — an extension is reached by member name, a notifier through its
  provider variable, so every public name a file declares counts;
- **a function is a declaration too** — the index read classes, enums and top-level variables and, for
  want of an anchor, every `final blob = …` inside a function body as well, while missing functions
  and getters themselves. A file whose only public member was a top-level function was therefore
  judged on the names of its own locals, which appear nowhere else by definition;
- **a conditional import is one symbol in several files** — `foo.dart` forwarding to `foo_stub.dart` /
  `foo_web.dart` has no file that carries the name alone: the forwarder declares nothing, and each
  half is a platform the other build never compiles. The trio answers as one unit, alive together and
  reported together;
- **dead code keeps dead code alive** — a handler nobody calls still calls its own settings, so the
  sweep repeats until a pass buries nobody.

What it cannot see: a reference made through a string, and a file whose own halves only reference
each other.

The finding names where the file should go instead — `lib/shared/` for a building block with no story
of its own, `lib/core/` for wiring several features share, `lib/core/platform/` for a platform trio.
"Dead code" is half an answer: a file its own feature stopped using is often a file somebody else
needs, and a message that names no destination leaves the author to find the intended shape by moving
the file until the rule stops firing.

**`frameworkRefsDiverged`** (warning) is the one check that reads no Dart at all. A project that
consumes DartWay by git writes `ref: master` on every framework package, which reads as "all of it
from master" and is not what the lock does: a git dependency is pinned to a commit the moment it is
*added*, and stays there until something upgrades it by name. Add the core in March and the push
module in May and the app runs two framework releases against each other — and a git dependency
carries no version number, so nothing in the project says so. The check groups the `dartway_*` git
entries of every `pubspec.lock` under the project root by repository, and reports a repository that
came out on more than one commit, naming the packages, the commits and the directories to run
`dart pub upgrade` in. Different repositories are never compared, and hosted packages are left out
because semver already answers the question for them.

It is a warning because the state is wrong while the code is not, and because what fixes it is a
command rather than an edit. The related trap on the framework side — a `dependency_overrides` block
switching off constraint checking for the packages it names — is described in
[what `create` changes](../1-getting-started/project-layout.md#what-create-changes-on-the-way-in).

Filter with `--type <name>` or `--level error|warning|info`, or narrow the run to a single folder
with `--dir lib/app/booking`. Note that `--dir` skips the `ui_kit/` pass — the kit is checked as a
whole or not at all, and for the same reason it skips the layout, generated-format and
framework-lock passes, which judge the project rather than any one folder.

Scope, and it is two scopes rather than one. The **feature-shaped** areas are the four zones —
`app/`, `admin/`, `auth/`, `common/` — which must be built out of features and are asked for a
`DwFeatureSpec`. The **checked** areas add `shared/` and `ui_kit/`: their content is read for the
cleanliness and UI-Kit rules, but no spec is expected, because a building block has no product
behaviour to describe. Keeping the two apart is what makes `lib/shared/` safe to recommend —
before, a widget moved out of a zone left every check behind, not just the passport one. `core/`
holds infrastructure with a shape of its own and is skipped entirely. Generated files (`.g.dart`,
`.gen.dart`, `.freezed.dart`) and the folders `generated/`, `gen/`, `l10n/`, `zarchive/` are
nobody's code and are skipped everywhere.

The zone names are matched exactly, and that is the point of
[`invalidTopLevelLayout`](../1-getting-started/project-layout.md): the top level of both packages is
a closed list, so an undeclared folder, a stray file at the root of `lib/`, a missing
`my_app_app.dart` and a zone name nested inside a zone are all errors. The last one is the reason
the check exists at all — `app/admin/` is a perfectly ordinary group as far as every other rule is
concerned, which is how the admin panel spent a release outside the checks that were written for
it. The pass covers the server package too (`lib/src/`), and `--dir` skips it, the same way it
skips `ui_kit/`.

## Why `generatedCodeUnformatted` is a warning that names a command

Two programs write the generated code and they disagree about how it should look. `serverpod
generate` formats its output with the `dart_style` bundled with the Serverpod CLI; the code already
in the repository was formatted by the `dart format` of the project's SDK. Nothing reconciles them,
so the difference shows up as a generation run that rewrites files the change never went near.
Making one field nullable is two lines of schema and, without a format pass, a diff of 29 files and
about 1900 lines — on review that reads as a rewritten protocol, and the two lines that matter
cannot be found inside it.

The fix is a `dart format` over both generated trees, and it has to be the **last** of the three
steps: `create-migration` regenerates in order to diff the schema, so a pass placed between it and
`generate` is silently thrown away. That is what turns a forgotten step into a loop — generate,
format, generate, format again — and it is why the sequence is written down as a sequence in
[models.md](../2-core/models.md#the-workflow-and-where-it-usually-goes-wrong).

The check insists on both trees, including the one that came back clean. Formatting only the half
you were looking at does not avoid the diff; it defers it to whoever next runs `dart format`
honestly. One project kept its server tree formatted and left the client raw, and the next person to
format both added 33 unrelated files to an unrelated pull request.

**Warning, not error, and deliberately.** This is the one check whose verdict depends on the tool
running it: the comparison is against the `dart_style` of the SDK in use, so a red result can mean
"your SDK is newer than the one that formatted this" rather than "you skipped a step". Failing a
build on that would be the fastest way to teach a team to filter this check out — the same argument
as `SizedBox(width: double.infinity)` below, arrived at from the other direction. What earns the
check its place instead is the message: it names the files, the exact command with both paths
written out, and the Dart version it judged against, so that someone who did not write the code and
does not know why it went red can still fix it or recognise the version skew.

Like the layout pass, it judges the server and client packages, so `--dir` skips it.

## Why 200 and 350

Length is the **weakest signal the checker has**, and a tight limit makes it lie. The thresholds
started at 120 (info) and 200 (warning) and were deliberately relaxed, because the checker began
flagging files that were long for a good reason: a feature's `DwFeatureSpec` now lives in the file
of the feature it describes, and a good description costs twenty lines.

A rule that goes off when someone documents their feature properly teaches them to document less.
That is the whole argument. So nothing is said below 200 lines, above it is a nudge that never
fails anything, and above 350 a warning that says "worth restructuring" — because at that size a
file has usually collected more than one responsibility. Split by responsibility, not by line
count: a meaningful 300-line file beats a pointless chop into three.

## Why `SizedBox(width: double.infinity)` is not in `widgetSizesItself`

`widgetSizesItself` fires on exactly two things, and only when they are what `build` returns:
`Expanded` and `SizedBox.expand`. Both mean the widget has decided how much room it gets. It works
until someone drops it into a bottom sheet or a scroll view, and then it throws at runtime while
the analyzer stays silent. Space is the parent's call — let the caller wrap it.

`SizedBox(width: double.infinity)` was tried in this check and taken back out. Inside a bounded
parent it only means "as wide as allowed" — legitimate, common, and harmless. Every hit was
arguable.

**A check whose findings are arguable teaches people to skip the checker.** Once a rule has cried
wolf twice, its next finding — a real one — gets the same shrug, and so does every other rule in
the tool. Precision is not a nicety here; it is the only thing keeping the checker worth running.
The two remaining patterns are not arguable: both throw in the first parent that does not offer
unbounded space.

The same principle shows up elsewhere in the checker. A string inside a doc comment in the kit is
not flagged as a text constant — usage examples are the most useful thing a kit widget can carry,
and flagging them taught authors to write worse documentation. A `part of` directive is not
demanded from generated files — it survives exactly until the next generator run.

## Why `barrelFile` is an error

A file whose whole body is `export` directives reads as convenience and acts as a hole in the
feature boundary. Importers name the barrel, so reaching into another feature's guts through it
looks legitimate — and the import checks see a barrel, not the internals behind it. One such file
laundered three features' internals until it was deleted. A single-line re-export counts too: same
hole, smaller.

## Why asset paths are checked against the file system

DartWay projects do not run `build_runner` in the edit loop — it costs minutes per change and
punishes whoever forgets to run it with errors about code that is perfectly fine. So asset
constants are written by hand. A generated constant could not name a missing file; a hand-written
one can.

`assetPathMissing` restores that guarantee, and `forbiddenAssetPath` keeps the paths in one place:
a path spelled out in a screen survives a renamed file only by accident, and cannot be found by
search. The screen should receive a widget, not a file name.
