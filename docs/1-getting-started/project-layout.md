# What does `dartway create` give you?

```bash
dartway create my_app
```

Three Dart packages side by side, an agent toolkit, and a git repository with an initial commit.
The source is `template/` in the DartWay monorepo — a skeleton with auth, roles, navigation, an
admin panel and a UI kit, and zero domain models.

```
my_app/
  my_app_server/     Serverpod backend — models, CRUD configs, business logic
  my_app_client/     generated protocol + API client — never edited by hand
  my_app_flutter/    the app — features, UI kit, navigation
  docs/              the project's own architecture notes
  .claude/           the agent toolkit (installed, then committed)
  .vscode/           Server / Seed dev data / Flutter (web) launch configs
  .github/           a Claude PR-review workflow (delete it to turn review off)
```

## Why three packages

`server` and `flutter` cannot depend on each other — one imports `dart:io` and Serverpod, the other
imports Flutter. `client` is the package both halves *can* see, which is why the protocol lives
there and why it is generated rather than written.

A project may add a fourth, `my_app_shared`: pure Dart for code that has to behave **identically**
on both sides — format validation, shared enums, computation over fields with no IO. The skeleton
ships none, because until such code exists the package is a folder with a pubspec in it. The CLI
recognises it by the `*_shared` directory suffix if you add it.

## `my_app_server` — where the rules live

```
my_app_server/
  bin/main.dart          the server entry point
  bin/seed_dev.dart      dev-only seed: one user per role
  config/                development / staging / production / test + passwords.yaml
  migrations/            generated schema migrations
  lib/src/
    models/              your *.spy.yaml model definitions
    generated/           serverpod generate output — do not edit
    crud/                one DwCrudConfig per model — the feature's whole behaviour
    dartway/             DwCore.init and the session role helpers
    endpoints/           hand-written Serverpod endpoints, for the things CRUD is not
    web/                 server-rendered pages, if you want any
  test/                  DartWay's auth and password integration suites, against a real DB
```

**Models are YAML, not Dart.** `lib/src/models/note/note.spy.yaml` declares a class, its table and
its fields; `serverpod generate` turns it into Dart in `lib/src/generated/` **and** in the client
package. You edit the YAML; you never edit the generated Dart.

**A config per model is the API.** `lib/src/crud/` holds one `DwCrudConfig<T>` per exposed model,
and a model with no config in `DwCore.init(crudConfigurations: [...])` is not reachable at all. The
skeleton ships two of them — `user_profile_crud_config.dart` and `app_setting_crud_config.dart` —
which are worth reading before writing your first: between them they show an admin-only access
filter, a role guard on writes, validation, and a public realtime broadcast.

**`lib/src/dartway/`** is the wiring: `dartway_core.dart` builds `DwCore.init<UserProfile>` with the
CRUD list, the auth config and the verification-code sender; `dartway_session_extension.dart` holds
the role helpers (`session.isAdmin`, `adminOnlyAccessFilter`) that the configs read. Both are yours
to extend — a new role helper goes here, not into each config.

**`lib/src/endpoints/` still exists**, and that is deliberate. CRUD covers data; a report, an import
or a payment callback is an ordinary Serverpod endpoint you write yourself.

## `my_app_client` — generated, and that is the point

`serverpod generate`, run in the server package, writes this package: the model classes, the
`Client` the app connects with, and the serialisation. **Nothing here is edited by hand** — the next
generate would erase it, silently and without breaking the build.

If you find yourself wanting to add a method here, the answer is elsewhere: a rule belongs in a CRUD
config on the server, an extension over a model belongs in the Flutter package.

## `my_app_flutter` — where the app is

```
my_app_flutter/lib/
  main.dart              development parameters only (backend URL, version label)
  my_app_app.dart        all the wiring: DwAppRunner, MaterialApp.router, the root subscription
  app/                   the features — app/home/, app/profile/, app/admin/...
  auth/                  the sign-in flow
  shared/                building blocks features draw with, e.g. widgets/app_scaffold.dart
  core/                  app-wide infrastructure: router/, dw_core.dart, app_settings/, dev/
  ui_kit/                your design system, as source
  l10n/                  ARB files and their generated output
  studio/                the DartWay Studio bridge binding — inert unless embedded
```

`main.dart` holds nothing but the concrete environment (the backend URL differs on an Android
device, which is the one line most people edit first). Everything structural is in the app file.

### A feature is a folder with one public file

```
lib/app/bookings/
  bookings_page.dart       the entry point — the feature's whole public surface
  widgets/                 its own widgets
  logic/                   its own providers, filters, mappers
```

The shape is inferred, not declared: a folder with a root `.dart` file is a **feature**, a folder
without one is just a **group** that nests features. Only `widgets/` and `logic/` count as a
feature's internals — any other subfolder is read as a nested feature.

Two rules follow, and the [conventions checker](../5-tooling/conventions-checker.md) enforces both:
a feature has exactly one root file, and no feature may import another feature's `widgets/` or
`logic/`. Behaviour two features share is one more feature; a widget with no story of its own is a
building block and lives in `lib/shared/`, where no spec is expected of it. The entry point also
declares what it is, in a `DwFeatureSpec` next to its own code rather than in a document that drifts
— see [features and specs](../3-flutter/features-and-specs.md).

Two further areas are conventional but not generated: `lib/domain/` for logic that spans features
(extensions on models), and `lib/data/` if a project ever needs data plumbing of its own. The
skeleton has neither, because `dw.repo` is the data layer and cross-feature logic does not exist on
day one.

### Why the kit is source in your app, not a dependency

`lib/ui_kit/` is a real design system — `AppText`, `AppButton`, `AppCard`, a theme, formatters — and
it is **yours**, copied in, not imported. The framework ships no design on purpose: a design system
is the one thing every serious app ends up owning, and shipping it as a dependency only starts an
argument about the corner radius of a button. Change any of it without asking anyone, and without
waiting for a release.

Inside, files are grouped by how often you reach for them — `1_essentials/`, `2_frequent/`,
`3_special/` — plus `theme/`, `layout/`, `utils/` and `assets/`. The kit is one library: every file
is a `part of '../ui_kit.dart'`, and the rest of the app imports the `ui_kit.dart` barrel and
nothing deeper.

The boundary is enforced rather than remembered: raw `Color(...)`, `TextStyle(...)`, `BorderRadius`
and direct `Theme.of(context)` access **outside** `ui_kit/` are a lint (`dartway_lints`, wired into
`custom_lint`). A style that leaks into a feature is a style nobody can change centrally later.

## `.claude/` — generated, and committed

The agent toolkit is installed into `.claude/` by `create` (and refreshed by `dartway setup-ai`):
the project's `CLAUDE.md`, the `dartway-*` skills, and a couple of commands. It is a
generated-but-committed artifact, like the Serverpod protocol — regenerate it to pick up framework
changes, but commit the result so the repository is self-contained. See
[the agent toolkit](../5-tooling/agent-toolkit.md).

## What `create` changes on the way in

Copying is not all it does. Every occurrence of `dartway_starter` becomes your project name and
`DartwayStarter` becomes its PascalCase form, in file names and in file contents alike. Each
package's `dependency_overrides` block — which points at the monorepo checkout and only makes sense
inside it — is stripped, and any git dependency is retargeted from `ref: master` to `ref: stable`,
so a standalone project follows the verified channel rather than the development trunk.

## Where to go next

- [Quick start](quick-start.md) — bring it up, then add a model of your own.
- [Models](../2-core/models.md) — what goes in a `.spy.yaml` and what generation produces.
- [CRUD configs](../2-core/crud-configs.md) — the file in `lib/src/crud/`, in full.
- [How the app reads and writes data](../3-flutter/data-layer.md) — `dw.repo` in full.
- [The UI kit](../3-flutter/ui-kit.md) — what belongs in it and what does not.
- [The conventions checker](../5-tooling/conventions-checker.md) — the rules above, as a command.
