---
title: "Server features import each other without cycles, through a surface, write only their own rows, and core/ imports none"
affects:
  dartway_cli: "0.24.0"
---

## Who is affected

Every project whose server features import one another's handlers, jobs, routes or `logic/`,
import each other both ways, write each other's tables, or whose `lib/src/core/` imports a feature —
the skeleton's own `core/call_context.dart` (it reads the profile row) and `core/auth.dart` (it
creates one) did. `dart run dartway_cli:dartway check` now reports four errors, in a section of
their own:

- `coreImportsFeature` — a file of `core/` importing a feature, or the package's library;
- `featureImportCycle` — features importing each other in a cycle, by any `import`, `export` or
  `part`; one finding per knot, with a shortest cycle and the import behind each step;
- `featureImportOutsideSurface` — a feature importing another's file that is not its `_rows`,
  `_access`, `_objects`, `_publications` or `_changes` (or a `<part>` of them), or importing the
  package's library;
- `foreignRowWrite` — `db.<table>.insert`, `update`, `delete`, `upsert` and their siblings on a
  table whose row class another feature declares, from a feature or from `core/`.

`changes` joins the closed file set: `<feature>_changes.dart` (or `<feature>_<part>_changes.dart`)
holds how another feature writes this one's rows. The rule is in
[project layout](../1-getting-started/project-layout.md), under `my_app_server`. Run the
closed-file-set migration (`2026-09-29-server-feature-closed-file-set.md`) first: until a file has
its kind's name, importing it reads as outside the surface.

Measured on the projects on the framework (read-only, on their trees of 2026-09-30, before the
closed-file-set renames): Studio — one knot of 9 features, 25 `core/` imports, 149 imports outside
the surface, 67 foreign writes (36 automation → issues, 12 github → issues); U90 — one knot of 7,
11, 128, 79 (20 coach → plan, 17 profile → plan, 11 profile → chat); Molodey — one knot of 4, 10,
5 (all five are the `course_*` names the renames fix), 17.

## What is mechanical, and what is design

**Mechanical** — a move with one right answer, done in the project's own migration branch:

- what `core/` holds that needs a feature (steps 1–3);
- a foreign write (step 4): each call site's write moves, unchanged, into a function of the owner's
  `_changes` — one function per call site — and the caller calls it;
- a row class declared in one feature and written only by another (step 6): the class moves;
- an import of a mapping, a publication or a rule sitting in the owner's handlers or `logic/`
  (step 5): the declaration moves to its kind's file.

**Design work, for the project's own queue** — a decision about where a concept lives, which no
recipe makes: merging those per-call-site functions into one function per invariant (two writers
cancelling the same booking each their own way become one `cancel`), because which of the two
behaviours is right is a question about the product; Studio's knot of nine features (automation, issues and github each reach into the
others' logic, and automation writes `issues` rows), and U90's `coach` ↔ `plan` (coach runs plan's
calculators and writes its activity rows; plan declares the coach's message rows). The findings
name every edge; which feature owns what is the project's call, taken issue by issue.

Run the checks in this order: `--type coreImportsFeature`, `featureImportOutsideSurface`,
`foreignRowWrite`, then `featureImportCycle`. The first three are the mechanical moves, and each of
them changes the import lines the next reports; the cycles left after them are the design work.

## What to change

**1. Who the caller is moves to the profile feature, under its name.** `core/call_context.dart`
becomes `<profile feature>/<profile feature>_access.dart`; its classes take the feature's name, as
every feature's do (`App*` is `core/`'s prefix): `AppCallContext` → `ProfileCallContext`, `AppAccess`
→ `ProfileAccess`. Every `import '…/src/core/call_context.dart'` becomes an import of that file.
**The profile imports no other feature**: every feature asks who the caller is, so the profile is
the sink of the graph — a profile that imports, say, the chat is in a cycle with it. A profile
rule another feature holds (a push audience read from a marketing consent column) moves to the
profile's `_access`.

**2. The sign-in hooks and the first administrator move to a feature at the top.**
`core/auth.dart` becomes `account/logic/auth.dart` of a new feature, `AppAuth` → `AccountAuth`; the
`DwFirstAdministrator` step moves from `DwAppServer(startup: …)` into the feature, and its `grant`
— a write of the profile — becomes a profile change (step 4). `core/bootstrap.dart` goes:

    // lib/src/account/account_feature.dart
    DwServerFeature accountFeature({required String? adminIdentifier}) =>
        DwServerFeature(
          'account',
          startup: [
            DwFirstAdministrator(
              grant: ProfileChanges.grantAdmin,
              identifier: adminIdentifier,
            ),
          ],
        );

    // lib/<project>_server.dart
    -   features: [profileFeature, adminFeature],
    -   startup: [DwFirstAdministrator(grant: AppBootstrap.grantAdmin, identifier: adminIdentifier)],
    +   features: [profileFeature, adminFeature, accountFeature(adminIdentifier: adminIdentifier)],

Nothing imports `account/`; it imports the features an account's life touches, and writes none of
their rows — the profile it creates is `ProfileChanges.create`, the bookings a deletion cancels a
`_changes` function of the bookings. Keep the library's `export … show AccountAuth`. A project that
already has a sign-in feature (`sign_in/`) moves the hooks there instead, as long as no other
feature imports it. Tests follow: `test/src/core/auth_test.dart` →
`test/src/account/account_acceptance_test.dart`. The shared package mirrors the new feature (`invalidSharedLayout`): the
rules both sides apply to signing in — the identifier's one form, the sign-up keys (the skeleton's
`AuthIdentifier`, `RegistrationKeys`) — move from `src/profile.dart` to `src/account.dart`, exported
by the library.

**3. What `core/` wires from features is handed in by the library.** Each upload rule goes to the
`_access.dart` of the feature that owns the purpose, beside its read answer (`null` for a file of
another purpose); `core/files.dart` keeps the bucket defaults, and the server's library lists them:

    // lib/<project>_server.dart, in the server class
    static List<DwUploadRule> get uploadRules => [
      ProfileAccess.avatarUpload,
      ChatAttachments.rule,
    ];

    static Future<bool> canReadFile(DwCallContext ctx, DwFileRecord file) async =>
        await ChatAttachments.canRead(ctx, file) ?? file.accountId == ctx.accountId;

    // in build(…)
    -   files: storage == null ? null : AppFiles.storage(storage),
    +   files: storage == null
    +       ? null
    +       : DwFileStorage(storage, rules: uploadRules, canRead: canReadFile),

The same for any other `core/` wiring that asks a feature — a push module's eligibility becomes a
required parameter (`AppPush.module(eligibility: ProfileAccess.pushEligibility)`), a service registry
constructing a feature's client moves to that feature. No file under `lib/src/` imports the
package's library.

**4. A write into another feature's table becomes a call of its `_changes`.** For each
`foreignRowWrite`, the owner gets `<owner>/<owner>_changes.dart` with one function per change, which
writes, keeps the invariant the row has, and publishes through the owner's `_publications`:

    // admin/admin_handlers.dart
    -   final updated = await ctx.db.userProfiles.update(row.copyWith(role: command.role));
    -   final profile = ProfilePublications.profile(ctx, updated);
    +   final profile = await ProfileChanges.changeRole(ctx, row, command.role);

The move itself is one function per call site. When two features wrote the same change (a member
cancelling a booking, and an account's deletion cancelling every booking it held), merging them
into the one function the invariant needs is the design step after it — the example did it
(`BookingsChanges.cancel`), and the two callers now behave the same way.

The example's `BookSession` now takes the spot first (`ScheduleChanges.takeSpot` locks the session,
refuses a missing or full one), then checks whether the session started and whether the member
already holds a spot: a full session that already started is refused as full, where it was refused
as started before. Reading
another feature's table stays free: import its `_rows` and query.

**5. An import outside the surface.** What the importing feature uses decides where it goes:

- **a rule** — whose row it is, who is a member, whether the caller may — moves to the owner's
  `_access.dart`, as one function (a context extension for a membership, a function returning a
  `DwAccessRule` for a rule many calls share). A membership defined in two features becomes the one
  in the owning feature; the other imports it;
- **a write** moves to the owner's `_changes.dart` (step 4);
- **a mapping or a publication** that sits in the owner's handlers or `logic/` moves to its
  `_objects.dart` or `_publications.dart`;
- **a helper only the importer uses** moves into the importer;
- **logic both need** — a calculator, a client of an outside service, the rules of a domain two
  features share — becomes a feature of its own that both import;
- **a job another feature enqueues** is that other feature's work: the job kind moves to the
  feature that starts it, or, when several do, to a feature of its own.

**6. A cycle.** The finding prints the knot and its shortest cycle; break each step whose import is
not needed in that direction:

- **the shared rule moves to the owning feature's `_access`** — two features each asking "is this
  member blocked" import each other until the question has one home;
- **a row class moves to the feature that owns its invariants** — a message row declared in `plan/`
  while `coach/` writes it makes `plan` import `coach` for the logic and `coach` import `plan` for
  the row. The table keeps its name (`@DwSqlTable`); move the class and its `part '….dw.dart'`, then
  run `dart run dartway_cli:dartway generate`;
- **what both need goes to a feature both import**, below the two;
- **two features that cannot be told apart** — every step of the cycle is a rule, a row or a change
  of the other — are one feature: merge the folders.

## How to check

`dart run dartway_cli:dartway check` reports no `coreImportsFeature`, `featureImportCycle`,
`featureImportOutsideSurface` or `foreignRowWrite`, and `dart analyze` is clean in the server
package.
