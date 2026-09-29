---
title: "A server feature is a closed set of files, held by dartway check"
affects:
  dartway_cli: "0.14.0"
---

## Who is affected

Every project whose server feature folders hold anything beyond `<feature>_<kind>.dart`, or keep a
handler, a row class, a job, a publication or a row → data object mapping in a file of another
kind. `dartway check` now reports both as errors: `invalidServerFeatureFile` (what files and folders
a feature has) and `misplacedServerCode` (what each file declares). The rule is in
[project layout](../1-getting-started/project-layout.md), under `my_app_server`.

## What to change

Run `dart run dartway_cli:dartway check --type invalidServerFeatureFile`, then
`--type misplacedServerCode`; each finding names the file and the shape it may take. The usual moves:

- **A layer subfolder in a feature** (`chat/rows/`, `chat/handlers/`, `chat/domain/`): row classes
  into `chat_rows.dart` — or `chat_<part>_rows.dart` when one file is too much — handlers into
  `chat_handlers.dart` / `chat_<part>_handlers.dart`, and everything in `domain/` into
  `chat/logic/`. Subfolders inside `logic/` are fine; a layer name (`domain`, `services`, `models`,
  `utils`, `helpers`, …) is not, at any depth. Moving a row class changes nothing in the database —
  the table is named by `@DwSqlTable` — but rename its `part '….dw.dart'` to the new file and run
  `dart run dartway_cli:dartway generate`.
- **Any other subfolder** (`chat/worker/`, `orders/refunds/`): into `logic/`, or, when it is a
  part of a kind, into `<feature>_<part>_<kind>.dart` beside the others.
- **A free-named file at the top of a feature** (`billing/stripe_client.dart`, `billing/billing_send.dart`):
  into `billing/logic/` when it is none of the kinds, or into the kind file it is —
  `billing_job_kinds.dart` is `billing_jobs.dart`.
- **A prefix that is not the folder's** (`courses/course_handlers.dart`): `courses_handlers.dart`.
  The prefix is the folder's name, letter for letter.
- **Mappers and publications in `core/`** (`core/objects.dart`, `core/publish.dart`): each function
  to the `_objects.dart` / `_publications.dart` of the feature that owns the row it maps or the
  change it publishes. `core/` keeps its wiring only.
- **A helper that publishes** in a handlers, jobs or `logic/` file (`_publishX(ctx, row)`): into
  `<feature>_publications.dart`, and the handler calls it. A handler or a sign-in hook that calls
  `ctx.publish` inline is not a publication and stays.
- **A row → data object helper** outside `_objects.dart` (`_toObject(row)` in a handlers file, a
  `toObject()` on a row class): into `<feature>_objects.dart`.
- **A `DwJobKind`, `DwQueuedJob` or `DwRecurringJob`** declared in a flow or handlers file: into
  `<feature>_jobs.dart`.

Update the imports the moves break and run `dart analyze`.

## How to check

`dart run dartway_cli:dartway check` in the Flutter package reports no `invalidServerFeatureFile`
and no `misplacedServerCode`.
