---
title: "The shared package mirrors the server's features, and file length holds in the server and shared packages"
affects:
  dartway_cli: "0.23.0"
---

## Who is affected

Every project whose shared package's `lib/src/` holds anything but `<feature>.dart` or a flat
`<feature>/` folder of `<feature>_<part>.dart` parts, `<feature>` a feature folder of the server's `lib/src/`, and the files named after
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

- **A file named after no server feature** (`assignees.dart`, `quiz_answers.dart`,
  `auth_identifier.dart`): merge what it declares into the file of the feature whose handlers answer
  it — a DTO goes where its handler is, and what exists only in the contract goes with the feature
  that owns it (sign-in rules and the sign-up keys: the feature that creates the profile). There is
  no shared `core/` to put it in.
- **A near miss of a feature's name** (`course.dart` for `courses/`, `issue_process.dart` for
  `issues/`): rename it, `src/courses.dart`, or make it a part, `src/issues/issues_process.dart`.
- **A file or folder per concept** (`plan/training_catalog.dart`, `chat_enums.dart`):
  `<feature>_<part>.dart` inside the feature's folder — `src/plan/plan_training_catalog.dart`,
  `src/chat/chat_enums.dart`. DTOs filed under the wrong feature move to the right one:
  `profile/notification_settings.dart`, when the server has a `notifications/` feature, becomes
  `src/notifications/notifications_settings.dart`. The folder is flat, and a part is never exactly a
  layer's name (`chat_models.dart`; `content_news_publications.dart` is a topic and passes).
- **A feature folder with a file of its own name** (`src/chat/chat.dart`): a folder holds parts only —
  name that file for what it holds (`src/chat/chat_channels.dart`).
- **A feature as a file and a folder at once** (`src/profile.dart` beside `src/profile/`): split the
  file into parts inside the folder.
- **The package-named files.** The protocol file (`app_protocol.dart`,
  `<project>_wire_protocol.dart`) becomes `<project>_protocol.dart`; the variable it declares keeps
  its name. A push category enum is `<project>_push_category.dart`. The channel, refusal and upload
  files and their enums take the prefix from the package's full name (D-108), so a shared package
  named `dartway_studio_shared` renames `studio_channel.dart`, `studio_refusal.dart` to
  `dartway_studio_channel.dart`, `dartway_studio_refusal.dart` **and** the enums `StudioChannel`,
  `StudioRefusal` to `DartwayStudioChannel`, `DartwayStudioRefusal` — an IDE rename of the enum
  reaches the server and the app; the codes on the wire do not change.
- **Anything else in `lib/`** beside the library, `generated/` and `src/`: into `src/`. The library
  holds `library`, `import` and `export` directives only — a declaration there moves to its feature;
  `generated/` holds only what the generator writes; a hand-written file named `*.dw.dart`, `*.g.dart`
  or `*.freezed.dart` gets the name of what it is.

**Splitting a long file** — the recipe, by DTO group. A group is a data object with the requests that
read it and the commands that change it; each group becomes one part, and every DTO lands in a part.
For a shared file `src/issues.dart` of 2400 lines:

1. `mkdir src/issues`, then for each group — the issue itself, comments, labels, the process state —
   create `src/issues/issues_<group>.dart` (`issues_core.dart` is not a group: name what it holds,
   `issues_records.dart`, `issues_comments.dart`) with the imports it needs and
   `part 'issues_<group>.dw.dart';`, and move the group's classes into it. What the moved classes
   refer to across groups is imported by `package:` path.
2. Delete `src/issues.dart` and `src/issues.dw.dart` once they are empty.
3. `export` every new file from `lib/<project>_shared.dart`, run
   `dart run dartway_cli:dartway generate`, then `dart analyze` in all three packages.

On the server the same split is `<feature>_<part>_<kind>.dart`: `issues_handlers.dart` of 1900 lines
becomes `issues_handlers.dart` plus `issues_comments_handlers.dart`, `issues_labels_handlers.dart`, …,
each exporting its own `<DwCallHandler>[…]` list, which `<feature>_feature.dart` joins
(`handlers: [...issuesHandlers, ...issuesCommentsHandlers]`). A private helper both halves call
becomes a named extension in the feature's `logic/`.

**A seed catalogue** that trips the length check: move its rows into a server
`<feature>_<part>_rows.dart` holding nothing but directives and `const`s, each a `New<Entity>Row(…)`
draft or a collection of nothing but drafts — no class, function, `final`, other constant or helper
call beside them — and the check passes it over as data.

## How to check

`dart run dartway_cli:dartway check` in the Flutter package reports no `invalidSharedLayout`, and
`dart run dartway_cli:dartway generate --check` reports nothing stale.
