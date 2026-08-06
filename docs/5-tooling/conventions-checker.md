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
| `invalidFeatureStructure` | error | A feature folder with more than one root file |
| `forbiddenFeatureImport` | error | Reaching into another feature's `widgets/` or `logic/` |
| `featureSpecMissing` | warning | A feature widget that declares no `DwFeatureSpec` |
| `unusedFeatureFile` | warning | A file in `widgets/`/`logic/` that its own feature never mentions |
| `barrelFile` | error | A file that only re-exports |
| `widgetSizesItself` | error | `Expanded` or `SizedBox.expand` returned straight from `build` |
| `assetPathMissing` | error | An `assets/...` string that names no file |
| `forbiddenAssetPath` | warning | A raw `assets/...` path outside `ui_kit/` |
| `fileLong` | info | Over 200 lines |
| `fileTooLong` | warning | Over 350 lines |

"Raw styles" means `Color(`, `TextStyle(`, `BorderRadius`, `Theme.of(context)`, `context.theme`,
`context.textTheme`, `context.colorScheme`. The long spelling is in the list on purpose: the rule
used to catch `context.textTheme` but not `Theme.of(context).textTheme.bodySmall`, which reads as
ordinary Flutter and means exactly the same thing — a screen deciding how it looks.

"More than one root file" is a structural claim, not a style one. A feature has exactly one public
file; behaviour a sibling also needs belongs in a feature of its own. A widget with no story of its
own is not a feature at all — it is a building block, it lives in `lib/shared/`, and the checker
never asks it for a spec.
`featureSpecMissing` is checked only when the entry point is a widget — a feature whose entry
point is an extension or a plain function has nothing to hang a spec on. The spec matters because
error reports, Studio and the agent all read it: without one the feature exists in the code and
says nothing about itself.

**`unusedFeatureFile`** (warning) is the one check the analyzer structurally cannot replace. A public
class is always "possibly used from somewhere else" — unless the somewhere else is a finite place,
which Law 3 makes it: nobody outside a feature may import its `widgets/`/`logic/`, so a file in there
that its own feature never mentions is unreachable. It compiles, it survives refactors, and it is
found in one folder-deep pass.

Two things it does *not* get wrong, because both cost real false positives before they were fixed: a
type is not how it is called (an extension is reached by member name, a notifier through its provider
variable, so every public name a file declares counts), and dead code keeps dead code alive (a
handler nobody calls still calls its own settings, so the sweep repeats until a pass buries nobody).
What it cannot see: a reference made through a string, and a file whose own halves only reference
each other.

Filter with `--type <name>` or `--level error|warning|info`, or narrow the run to a single folder
with `--dir lib/app/booking`. Note that `--dir` skips the `ui_kit/` pass — the kit is checked as a
whole or not at all.

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
