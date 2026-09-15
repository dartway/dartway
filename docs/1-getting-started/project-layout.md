# What does `dartway create` give you?

```bash
dartway create my_app
```

Three Dart packages side by side, the files that deploy and review them, an agent toolkit, and a git
repository with an initial commit. The source is `template/` in the DartWay monorepo — a skeleton
with sign-in, profiles, roles, an admin panel and a UI kit, and no domain models.

```
my_app/
  my_app_shared/     the contract: data objects, requests, commands, channels, refusal codes
  my_app_server/     row classes, handlers, access and channel rules, migrations
  my_app_flutter/    the app: features, navigation, the UI kit
  deploy/            the deployment's configuration — dartway deploy reads it
  .claude/           the agent toolkit, installed by create and committed
  docs/dev_notes/    the project's own findings, one file per finding
  CLAUDE.md          the project's own rules for agents — yours, never overwritten
  README.md          bring-up, a feature end to end, the checks
  .vscode/           Server and Flutter launch configurations
  .github/           a Claude review on every pull request (delete it to turn review off)
```

## Why three packages

`my_app_server` imports `dart:io` and Postgres; `my_app_flutter` imports Flutter. Neither can depend
on the other. What they must agree on — every call, every object, every refusal code — lives in
`my_app_shared`, pure Dart, and **both depend on it**. There is no generated client package: the
shared package is the client contract, compiled into the app and into the server from one source.

That is also what makes a shared rule honest. `AuthIdentifier.normalize` in the skeleton's shared
package is the function the app runs on what a person typed *and* the server's
`DwAuthConfig.normalize`. Written twice, the copies drift — and since signing in with an unknown
identifier creates an account, a phone stored as `+7 999…` on one side and `7999…` on the other is a
second, empty account instead of a sign-in.

## `my_app_shared` — the contract

```
my_app_shared/
  lib/my_app_shared.dart         the library: re-exports dartway_core_shared and everything below
  lib/generated/dw_protocol.dart the protocol registry — generated
  lib/src/
    profile.dart, admin.dart,    data objects, requests and commands, grouped by area;
    settings.dart                each with its generated *.dw.dart part
    my_app_channel.dart          enum MyAppChannel with DwChannelKind — the live channels
    my_app_refusal.dart          enum MyAppRefusal with DwRefusalCodes — why the server says no
    my_app_upload.dart           enum MyAppUpload with DwUploadPurpose — what a file is for
    auth_identifier.dart         rules both sides apply identically
    registration_keys.dart       the keys a sign-up sends with its code
  test/contract_test.dart
```

**It depends on `dartway_core_shared` and nothing else.** Whatever it declares is compiled into the
server and into the app alike, so it cannot reach for Flutter, a database or IO. A rule that needs the
database is not a shared rule — it is a handler's.

The three enums are named after the project — `<Project>Channel`, `<Project>Refusal`,
`<Project>Upload` — so a project's own codes never read as the framework's.

## `my_app_server` — where the rules live

```
my_app_server/
  bin/server.dart          starts the server — configured by the environment alone
  bin/migrate.dart         apply | rollback | status | create <name> | check | rehash
  bin/seed_dev.dart        development accounts and data; refuses to run twice
  lib/my_app_server.dart   builds the DwAppServer: protocol, schema, migrations, auth,
                           handlers, channels, files
  lib/generated/
    dw_schema.dart         the schema and the db.<table> getters — generated
  lib/src/
    entities/              row classes (@DwSqlTable) with their generated *.dw.dart tables
    handlers/              one DwCallHandler per request and command, grouped by area
    migrations/            migrations.dart and one file per migration — written by
                           migrate.dart create, then yours
    auth.dart              DwAuthConfig: code delivery, the profile made with each account
    call_context.dart      what "the caller" means to this app: ctx.profile, the access rules
    channels.dart          one DwChannelRule per channel kind
    files.dart             one DwUploadRule per upload purpose
    objects.dart           rows → the data objects clients see, related data in batches
    publications.dart      what a change publishes, and to whom
    bootstrap.dart         APP_BOOTSTRAP_ADMIN: the first administrator, ensured on every start
  test/                    acceptance tests on a real server, database and storage
  docker-compose.yaml      development Postgres and MinIO
  Dockerfile               the server image the deploy builds
```

**The top of `lib/` is fixed; `lib/src/` is yours.** The checker allows exactly the package's library,
`generated/` and `src/` there, and requires `src/migrations/migrations.dart` — `bin/migrate.dart`
writes and reads migrations by that path. Everything else under `src/` is arranged as your domain
asks: the skeleton's files are one reasonable shape, not a law.

**A row is not a data object.** `UserProfileRow` is a table; `UserProfile` is what a client receives.
The server builds one from the other in `objects.dart` — the profile's phone and e-mail come from
the framework's identities, its photo URL from the file store — so a column added for the server's
own use never reaches a client by accident.

**Accounts are the framework's, profiles are yours.** The framework keeps accounts, sign-in identifiers
and session keys in its own tables; `UserProfileRow` references the account and is created in the
same transaction, by `onAccountCreated` in `auth.dart`. A signed-in account without a profile cannot
exist, and nothing about who a person is to your app lives in the framework.

## `my_app_flutter` — where the app is

**The top level of `lib/` is a closed list: two files, four zones, four layers.** Nothing else may sit
there, and each name means one thing.

```
my_app_flutter/lib/
  main.dart              development parameters only: the server address, the version
  my_app_app.dart        the wiring: the core, DwAppRunner, MaterialApp.router

  ZONES — features
  app/                   the app itself — app/home/, app/profile/, ...
  admin/                 the admin panel
  auth/                  the sign-in flow
  common/                features more than one zone draws on (create it when that happens)

  LAYERS — everything that is not a feature
  core/                  app-wide wiring: dw_core.dart, router/, refusal_text.dart,
                         update_required_page.dart, profile/, app_settings/, dev/
  shared/                building blocks: widgets and helpers with no story of their own
  ui_kit/                your design system, as source
  l10n/                  ARB files and their generated output
```

`core/dw_core.dart` declares the ambient core — `late DwFlutterCore dw;` — and the function that builds
it. It is not `final` because a widget test builds its own core against an in-memory server
(`DwFakeServer`) and disposes it in `tearDown`. `core/refusal_text.dart` is the catalogue that turns
every refusal code into the user's language; an exhaustive switch, so a code added to the shared enum
does not compile here until it has a text.

**There is no `data/` and no `domain/`.** The data layer is `dw.request` and `dw.command` over the
shared contract, so a `data/` folder is either empty or a second way to do the same thing. The rules
live in the shared package, where both sides apply them, and in the server's handlers; what is left on
the Flutter side — extensions on data objects, formatting, predicates — is a helper, and helpers live
in `shared/`.

**A zone is not a folder you invent.** The four are the kinds of thing an app is made of, not a list of
sections: a fifth navigation zone does not earn a top-level folder — it is a group inside `app/`. The
admin panel cannot live at `app/admin/` either: a top-level name nested in a zone reads as an ordinary
group, and the checker reports it.

The [conventions checker](../5-tooling/conventions-checker.md) enforces the list rather than describing
it: an undeclared folder, a stray file at the root of `lib/`, a missing `my_app_app.dart` and a
top-level name inside a zone are all errors.

### A feature is a folder with one public file

```
lib/app/profile/profile_page/
  profile_page.dart        the entry point — the feature's whole public surface
  widgets/                 its own widgets
  logic/                   its own providers and helpers
```

The shape is inferred, not declared: a folder with a root `.dart` file is a **feature**, a folder
without one is a **group** that nests features. Only `widgets/` and `logic/` count as a feature's
internals; any other subfolder is read as a nested feature.

A feature has exactly one root file, and no feature imports another feature's `widgets/` or `logic/`.
Behaviour two features share is one more feature; a widget with no story of its own is a building
block in `lib/shared/`. The entry point declares what it is in a `DwFeatureSpec` beside its code —
see [features and specs](../3-flutter/features-and-specs.md).

### Why the kit is source in your app, not a dependency

`lib/ui_kit/` is a design system — `AppText`, `AppButton`, `AppCard`, a theme, formatters — and it is
**yours**, copied in, not imported. The framework ships no design on purpose: a design system is the
one thing every serious app ends up owning, and shipping one as a dependency starts an argument about
the corner radius of a button. Change any of it without waiting for a release.

Inside, files are grouped by how often you reach for them — `1_essentials/`, `2_frequent/`,
`3_special/` — plus `theme/`, `layout/`, `utils/` and `assets/`. The kit is one library: every file is
a `part of` `ui_kit.dart`, and the rest of the app imports that file and nothing deeper.

The boundary is enforced by `dartway_lints` through `custom_lint`: raw `Color(...)`, `TextStyle(...)`,
`BorderRadius` and direct theme access **outside** `ui_kit/` are flagged, because a style that leaks
into a feature is a style nobody can change centrally. The same package limits a relative import to
two levels up (`deep_relative_import`): past that the path names nothing, and a `package:` import says
where it goes. See [the UI kit](../3-flutter/ui-kit.md).

### `web/index.html` is part of the app

It sits outside `lib/`, which makes it easy to read as scaffolding, and it is not: the skeleton's shell
carries a scroll lock. Without it, focusing a text field on iOS scrolls the document — and with it the
Flutter canvas — off the screen. Nothing fails and nothing is logged, and neither the iOS simulator
nor a desktop browser reproduces it; a real phone does. Anything that regenerates the shell drops the
block silently, so `grep -q 'focusin' web/index.html` is worth running before you hand a web build to
someone.

## Generated files, and who writes them

| File | Written by | From |
|---|---|---|
| `*_shared/lib/src/**/*.dw.dart` | `dartway generate` | data objects, requests, commands: codecs and equality |
| `*_shared/lib/generated/dw_protocol.dart` | `dartway generate` | every DTO of the contract: the protocol registry |
| `*_server/lib/src/entities/*.dw.dart` | `dartway generate` | row classes: the typed table definitions |
| `*_server/lib/generated/dw_schema.dart` | `dartway generate` | row classes: the schema and the `db.<table>` getters |
| `*_server/lib/src/migrations/m<timestamp>_<name>.dart` | `dart run bin/migrate.dart create <name>` | the difference between the schema and the migrations — a draft you review, then yours |
| `*_flutter/lib/l10n/gen/` | Flutter's `gen-l10n` | the ARB files |

**Generated files are never edited by hand, and they are committed.** The next generation would erase
an edit silently, and `dartway generate --check` — part of `dartway check` — fails on any generated
file that no longer matches its sources, or whose source is gone. The codecs are the wire: a field a
stale part does not know compiles, starts, and travels without that field.

A migration is the exception: drafted once, then owned. `create` seals it with a checksum of its
source; an edit made while reviewing an unapplied draft is re-sealed with `migrate.dart rehash`, and
`migrate.dart check` fails on a file that no longer matches its seal — an applied migration edited in
place is a database that no longer agrees with its history.

## `deploy/`

The deployment is configuration, not scripts: `deploy/config.yaml` (from `config.yaml.example`)
describes the environment — the machine, the `api` and `app` hosts, an optional site, storage,
required secrets — and `dartway deploy setup`, `check` and `run` do the rest. The server's `Dockerfile`
and the Flutter package's `Dockerfile` and `nginx.conf` are the images it builds. `deploy/README.md`
explains the stack; [deploy](../5-tooling/deploy.md) explains the command.

## `.claude/`, `CLAUDE.md` and `docs/dev_notes/`

Three kinds of file, and the difference is who may change them:

- **`.claude/`** is installed by `create` and refreshed by `dartway update` (or `dartway setup-ai`):
  the toolkit's constitution `.claude/CLAUDE.md`, the `dartway-*` skills, the `/commit` and
  `/dartway-checkup` commands, and `settings.json`. The managed files are overwritten on every update —
  commit the result, so the history says which skills the code was written with. Skills and commands
  of your own, under other names, are never touched; `settings.json` is merged, keeping what you added.
  See [the agent toolkit](../5-tooling/agent-toolkit.md).
- **`CLAUDE.md` at the root** is the project's own rules for agents: a DartWay default the project
  replaces, conventions the framework says nothing about, with the reason beside each. `create` writes
  it once, nearly empty; `setup-ai` and `update` never touch it.
- **`docs/dev_notes/`** holds the project's findings, one tracked file per finding. The toolkit seeds its
  form; the notes are the project's.

A new project gets no other `docs/`, deliberately. What a screen does belongs in its `DwFeatureSpec`,
a server rule in the doc comment of the handler that holds it, a cross-cutting list — settings keys,
roles — in code, where the compiler knows the list and a typo is an error. A document apart from the
code goes stale without anything failing.

## What `create` changes on the way in

Copying is not all it does. Every occurrence of `dartway_starter` becomes your project name, in file
names and contents, with its PascalCase, camelCase and dashed forms (the dashed one names the storage
buckets). The renamed code is formatted once, so the first commit is already the formatter's. Each
package's `dependency_overrides` block — which points at the monorepo checkout and means nothing
outside it — is stripped, so the framework resolves from pub.dev; with `--framework-path` it is
replaced by overrides onto that checkout instead.

Worth knowing if you ever add such a block yourself: **for the package an override names, pub stops
checking constraints altogether.** A caret no published version could satisfy resolves in silence for
as long as the block is there, and the first tree to find out is one without it — a new project, or CI.

## Where to go next

- [Quick start](quick-start.md) — bring it up, sign in, run the checks.
- [Data objects and generation](../2-core/data-objects-and-generation.md) — what goes in the shared
  package and what generation produces.
- [Handlers and context](../4-server/handlers-and-context.md) — the files in `handlers/`.
- [Database](../4-server/database.md) and [migrations](../4-server/migrations.md) — rows, queries and
  the migration CLI.
- [Flutter core](../3-flutter/flutter-core.md) — what `core/dw_core.dart` builds.
- [The conventions checker](../5-tooling/conventions-checker.md) — the rules above, as a command.
