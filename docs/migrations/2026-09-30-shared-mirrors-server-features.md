---
title: "The shared package mirrors the server's features, and file length holds in the server and shared packages"
affects:
  dartway_cli: "0.23.0"
---

## Who is affected

Every project whose shared package's `lib/src/` holds anything but `<feature>.dart` or a flat
`<feature>/` folder, `<feature>` a feature folder of the server's `lib/src/`, and the files named after
the package. `dart run dartway_cli:dartway check` reports each as `invalidSharedLayout`, an error.
Long files in the server and the shared package are now reported too — `fileLong` over 200 lines
(info), `fileTooLong` over 350 (warning) — which fails nothing but tells you where to split. The rule
is in [project layout](../1-getting-started/project-layout.md), under `my_app_shared`.

## What to change

Run `dart run dartway_cli:dartway check --type invalidSharedLayout`; each finding names the file and,
for a near miss, the feature it belongs to. Moving a DTO between files changes nothing on the wire —
its class name is its wire name — but its `part '….dw.dart'` goes with it: rename the `part` line in
every file you move or merge, delete the old `.dw.dart` parts, and run
`dart run dartway_cli:dartway generate`. Then fix the imports the moves break (`dart analyze`), and
the `export` lines of `lib/<project>_shared.dart`.

- **A file named after no server feature** (`notifications.dart` with no `notifications/` on the
  server, `assignees.dart`, `quiz_answers.dart`): merge what it declares into the file of the feature
  whose handlers answer it — a DTO goes where its handler is, a rule both sides apply goes with the
  feature that owns it (sign-in rules and the sign-up keys: the feature that creates the profile).
- **A near miss of a feature's name** (`course.dart` for `courses/`, `issue_process.dart` for
  `issues/`): rename it, `src/courses.dart`, or make it a part, `src/issues/issues_process.dart`.
- **A file or folder per concept** (`profile/notification_settings.dart`,
  `plan/training_catalog.dart`, `chat_enums.dart`): `<feature>_<part>.dart` inside the feature's
  folder — `src/notifications/notifications_settings.dart`, `src/plan/plan_training_catalog.dart`,
  `src/chat/chat_enums.dart`. The folder is flat; a part never names a layer (`_models`, `_utils`).
- **A feature as a file and a folder at once** (`src/profile.dart` beside `src/profile/`): the file
  moves into the folder as `src/profile/profile.dart`.
- **The protocol file** (`app_protocol.dart`, `<project>_wire_protocol.dart`): `<project>_protocol.dart`;
  the variable it declares keeps its name. The channel, refusal and upload enums were already
  `<project>_channel.dart`, `_refusal.dart`, `_upload.dart` (D-108); a push category enum is
  `<project>_push_category.dart`.
- **Anything else in `lib/`** beside the library, `generated/` and `src/`: into `src/`.

**Splitting a long file** — the recipe, by DTO group. A group is a data object with the requests that
read it and the commands that change it; each group becomes one part. For a shared file
`src/issues.dart` of 2400 lines:

1. `mkdir src/issues` and `git mv src/issues.dart src/issues/issues.dart` — its
   `part 'issues.dw.dart';` stays, since the part is written beside it — and delete
   `src/issues.dw.dart`.
2. For each group — comments, labels, the process state — create `src/issues/issues_<group>.dart`
   with the same imports and `part 'issues_<group>.dw.dart';`, and move the group's classes into it.
   What the moved classes refer to across groups is imported by `package:` path.
3. `export` every new file from `lib/<project>_shared.dart`, run
   `dart run dartway_cli:dartway generate`, then `dart analyze` in all three packages.

On the server the same split is `<feature>_<part>_<kind>.dart`: `issues_handlers.dart` of 1900 lines
becomes `issues_handlers.dart` plus `issues_comments_handlers.dart`, `issues_labels_handlers.dart`, …,
each exporting its own `<DwCallHandler>[…]` list, which `<feature>_feature.dart` joins
(`handlers: [...issuesHandlers, ...issuesCommentsHandlers]`). A private helper both halves call
becomes a named extension in the feature's `logic/`.

**A seed catalogue** that trips the length check: move its rows into `<feature>_<part>_rows.dart`
holding nothing but `const` lists of `New<Entity>Row(…)` drafts — no class, function, closure or
`final` beside them — and the check passes it over as data.

## How to check

`dart run dartway_cli:dartway check` in the Flutter package reports no `invalidSharedLayout`, and
`dart run dartway_cli:dartway generate --check` reports nothing stale.
