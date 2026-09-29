---
title: "Seeds are startup steps, migrations change the schema, settings are one typed object, patches are read by their helpers"
affects:
  dartway_core_shared: "0.21.0-dev.9"
  dartway_core_server: "0.21.0-dev.9"
---

## Who is affected

Every project, once it runs `dart run dartway_cli:dartway check` from this version: four new errors
hold the patterns below. Nothing stops compiling; the checks are what fail.

| Check | Fails on |
|---|---|
| `migrationChangesData` | an `INSERT`, `UPDATE` or `DELETE` in `lib/src/migrations/m*.dart` outside `m.backfill(…)` |
| `workAfterServerStart` | `bin/server.dart` awaiting, or reaching `.db`, `.accounts` or `runInContext`, after `start()` |
| `settingsKeyValueTable` | a row class with a `@DwUniqueColumn()` `String key` beside a `String value` |
| `fieldPatchMatched` | `DwSetField`, `DwClearField` or `DwKeepField` named in `lib/`, `bin/` or `test/` of any package |

The server applies a new framework migration, `dw_setting`, at its next start; nothing to do for it.

## Migrations you already have

They stay as they are: an applied migration is never edited. Name the latest one in
`deploy/config.yaml`, so `migrationChangesData` judges only the migrations written from now on:

    + migrations:
    +   dataChecksAfter: <the id of your latest migration, e.g. 20260928_090917_course_modules>

From then on, a statement that carries rows across a migration's own schema change — a renamed
value, a backfilled column, rows a new constraint forbids — goes to `m.backfill`:

    await m.backfill("UPDATE issue SET stage = 'review' WHERE stage = 'validation'");

A statement kept in a variable is passed to `backfill` directly (the check judges a literal where it
is written).

## Content in a migration → a seed step

Rows the code declares — a questionnaire, a catalogue — leave the migration and become a
`DwSeedRows` on their feature:

1. Give the table a unique natural key if it has none (`slug`), by a new migration: `m.addColumn(…,
   backfill: <an SQL expression that computes it from what is there>)` so existing rows get the key
   the declaration will use for them.
2. Declare the rows beside the row class, in `<feature>_rows.dart`, as `const` rows without ids:

       const onboardingQuestions = [
         SurveyQuestionRow(slug: 'goal', position: 1, title: '…', kind: …),
         …
       ];

3. Declare the step on the feature:

       DwServerFeature('survey', …, startup: [
         DwSeedRows('onboarding questions', table: SurveyQuestionRow.tableDef,
             key: (t) => [t.slug], rows: onboardingQuestions),
       ]);

   Rows that point at another seed's rows (options of a question) are a second step after it, with
   the parent's id read in a `DwStartupStep` of your own — or keyed by the parent's slug if the table
   can hold it.
4. Leave the old migration as it is. Every database — a fresh one too, which still runs the old
   `INSERT`s — has the rows it created, and the seed, keyed by the natural key of step 1, adopts
   them by that key: from the next start on, the declaration is what they hold, everywhere. A row the old text
   unpublished rather than deleted is declared with the same column (`isPublished: false`).
   Only rows nobody edits outside the code are a seed: the next start writes the declaration back
   over an edit.

## Work after `server.start()` → startup steps

    - await server.start();
    - await CatalogSeed.ensureSeeded(server.db);
    + // in the feature: startup: [DwSeedRows('catalogue', table: …, key: …, rows: catalogue)]
    + await server.start();

An "ensure" that inserts missing rows by `tryInsert(… DwOnConflict.doNothing)` becomes `DwSeedRows`
over the same rows; from now on an edited row reaches every database too. Work that is not rows
(prompts kept until an admin edits them) is a `DwStartupStep` of the project's own, or a settings
object's default (below). Only logging stays after `start()`.

## A key/value settings table → a settings object

1. In the shared package, one data object with a default for every field and a fixed id:

       final class AppSettings extends DwDataObject with _$AppSettings {
         const AppSettings({this.signUpEnabled = true, this.paywallBypass = false});
         @override
         String get id => 'app';
         final bool signUpEnabled;
         final bool paywallBypass;
       }

   Replace `List…Settings`/`Save…Setting(key, value)` with `GetAppSettings extends
   DwSingleRequest<AppSettings>` and `SaveAppSettings` whose fields keep when absent: `null` for a
   non-nullable setting, a `DwFieldPatch` (default `keep()`) for a nullable one — applied with
   `trimmedOrCleared`/`apply`, so it can be cleared, never an `''` meaning none. Drop the key-set
   validation and its refusal.
2. On the server: `ctx.settings.read<AppSettings>()` where a row was read and a string compared
   (`row?.value == 'true'` → `settings.paywallBypass`); `ctx.settings.update<AppSettings>((s) =>
   s.copyWith(…))` in the save handler, then `ctx.publish(…, saved)`. No advisory lock, no
   `findFirst(lock:)`: two first saves at once both succeed.
3. A typed single-row table of its own (`SignInSettingRow`, read as `findFirst()` with `??`
   defaults, saved under an advisory lock) moves the same way: its fields become the object's, its
   `findFirst` a `read`, its lock and insert-or-update an `update`.
4. Carry the stored values over, in the migration that drops the old table — a project never writes
   `dw_setting` itself:

       await m.carrySettings('AppSettings', fromSql: '''
         SELECT jsonb_strip_nulls(jsonb_build_object(
           'paywallBypass',
             (SELECT lower(value) = 'true' FROM app_setting WHERE key = 'paywallBypass')))''');
       await m.dropTable('app_setting');

   The area is the class's wire name; what is carried is merged over anything already stored.
5. In the app: a `ref.watch(dw.request(const GetAppSettings()))` answers the object; a catalogue of
   keys with parsers (`AppSettingKey`) goes.

A preference per member stays a row of the member's table; replace `row ?? const New…Row(…)` with a
mapper that answers the data object's own defaults when there is no row (`row == null ? const
NotificationPrefs() : NotificationObjects.prefs(row)`), so the default lives once, in the contract.

## Hand matches of `DwFieldPatch`

| Was | Is |
|---|---|
| `switch (p) { DwSetField(:final value) when value.trim().isEmpty => null, DwSetField(:final value) => value.trim(), DwClearField() => null, _ => current }` | `p.trimmedOrCleared.apply(current)` |
| the same, answering a patch for `copyWith` | `p.trimmedOrCleared` |
| `switch (p) { DwSetField(:final value) => value, _ => null }` on insert | `p.apply(null)` |
| `if (p case DwSetField(:final value)) …` | `if (p.newValue case final value?) …` |
| `if (p case DwSetField(:final value) when value != previous)` | `if (p.newValue case final value? when value != previous)` |
| `p is DwSetField<int>` / `p is DwClearField` / `p is DwKeepField` | `p.isSet` / `p.isCleared` / `p.isKept` |
| `switch (p) { DwSetField(:final value) => DwFieldPatch.set(f(value)), DwClearField() => const DwFieldPatch.clear(), _ => const DwFieldPatch.keep() }` | `p.map(f)` |
| a test asserting `isA<DwKeepField>()` | `expect(p.isKept, isTrue)` |

## How to check

`dart run dartway_cli:dartway check` reports none of the four; `dartway test` is green, and a
second start of the server logs no `seed …: n rows written` line.
