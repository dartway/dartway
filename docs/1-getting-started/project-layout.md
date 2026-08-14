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
  .claude/           the agent toolkit (installed, then committed)
  .vscode/           Server / Flutter (web) launch configs
  .github/           a Claude PR-review workflow (delete it to turn review off)
```

**A new project gets no `docs/` folder, deliberately.** What a screen does belongs in its
[`DwFeatureSpec`](../3-flutter/features-and-specs.md), the server-side rules in doc comments above
the CRUD config, a cross-cutting registry — analytics events, settings keys, roles — in code under
`lib/core/`, where the compiler knows the list and a typo is an error. A document sitting apart from
the code goes stale without anything failing: nothing compiles it, no checker sees it, and the next
reader — increasingly an agent — believes it.

A project may still keep the documents it genuinely needs there, and one kind is known to the
framework because it keeps being reinvented: **`docs/adr/` — the decisions and what they ruled out**.
An ADR exists for the one thing that cannot live beside code — the *rejected* alternatives, which
have no file to sit next to. The rules for writing one (and for never editing it) are in the agent
toolkit's `CLAUDE.md`; `dartway-plan` reads the folder before proposing an approach.

## Why three packages

`server` and `flutter` cannot depend on each other — one imports `dart:io` and Serverpod, the other
imports Flutter. `client` is the package both halves *can* see, which is why the protocol lives
there and why it is generated rather than written.

A project may add a fourth, `my_app_shared`: pure Dart for code that has to behave **identically**
on both sides — format validation, shared enums, computation over fields with no IO. The skeleton
ships none, because until such code exists the package is a folder with a pubspec in it. The CLI
recognises it by the `*_shared` directory suffix if you add it.

## `my_app_server` — where the rules live

`lib/src/` here is a closed list too, for the same reason and enforced by the same check.

```
my_app_server/
  bin/main.dart          the server entry point
  config/                development / staging / production / test + passwords.yaml
  migrations/            generated schema migrations
  lib/server.dart        the package's public surface
  lib/src/
    models/              your *.spy.yaml model definitions
    generated/           serverpod generate output — do not edit
    crud/                one DwCrudConfig per model — the feature's whole behaviour
    dartway/             DwCore.init and the session role helpers
    domain/              pure rules over models — no Session, no IO, no DB
    app/                 session-aware workflows — bootstrap_admin.dart lives here
    endpoints/           hand-written Serverpod endpoints, for the things CRUD is not — absent
                         until you need one
    web/                 server-rendered pages, if you want any
  test/                  DartWay's auth and password integration suites, against a real DB
```

`domain/` and `app/` are the one boundary worth holding on the server — pure rules against
session-aware side effects. `domain/` ships empty, because until such code exists the folder is
nothing; `app/` ships with the one workflow every project needs before it has a domain at all —
`bootstrap_admin.dart`, which brings the identifier declared in `bootstrapAdminIdentifier` to the
state "the profile exists and it is an admin" on every boot. The admin role is granted by an admin,
so the first one is declared per environment; that is also the answer for staging and production,
where the alternative is an `UPDATE` typed by hand that nobody can read back or repeat. Both folders
are declared, so creating one is not an invention; anything *else* under `lib/src/` is.

`endpoints/` is not there at all, and that is the point rather than an omission: the skeleton
reaches its whole surface — auth, profiles, roles, settings, an admin panel — through CRUD configs,
without one hand-written endpoint, and `serverpod generate` is perfectly happy with no endpoints to
generate. Create the folder for the things CRUD genuinely is not — uploads, webhooks, a third
party's callback — and treat it as the last resort it is.

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

**The top level of `lib/` is a closed list: two files, four zones, four layers.** Nothing else may sit
there, and each of these means one thing and is spelled one way.

```
my_app_flutter/lib/
  main.dart              development parameters only (backend URL, version label)
  my_app_app.dart        all the wiring: DwAppRunner, MaterialApp.router, the root subscription

  ZONES — features, each with a DwFeatureSpec
  app/                   the app itself — app/home/, app/profile/, ...
  admin/                 the admin panel
  auth/                  the sign-in flow
  common/                features more than one zone draws on (create it when that happens)

  LAYERS — everything that is not a feature
  core/                  app-wide wiring: router/, dw_core.dart, app_settings/, studio/, dev/
  shared/                building blocks: widgets and helpers with no story of their own
  ui_kit/                your design system, as source
  l10n/                  ARB files and their generated output
```

`main.dart` holds nothing but the concrete environment (the backend URL differs on an Android
device, which is the one line most people edit first). Everything structural is in the app file.

**A zone is not a feature and not a folder you invent.** The four are the kinds of thing an app is
made of, not a list of sections: a fifth navigation zone in the router does *not* earn a folder of
its own — it is a group inside `app/`, like any other group. The zones are also the only places
asked for a `DwFeatureSpec`, which is why the admin panel has to be one and cannot live at
`app/admin/`: nested in a zone it reads as an ordinary group, and the whole panel disappears from
every question the checker asks about zones.

`core/studio/` is the [DartWay Studio](../6-studio/studio-bridge.md) bridge binding — the host that talks to
Studio when the app runs inside its preview frame, plus the screen passports Studio renders beside
it. It is wiring like the router, inert outside an iframe, and a project that never opens Studio can
delete the folder.

**There is no `data/` and no `domain/`.** The data layer is `dw.repo`, so a `data/` folder in a
DartWay app is either empty or a second way to do the same thing; and the rules of a DartWay app
live in CRUD configs on the server, so what is left on the Flutter side — extensions on models,
formatting, predicates — is a helper, and helpers live in `shared/`. Both folders were conventional
once, both stayed empty in every skeleton, and a name that exists only in a document is how a layout
drifts.

The [conventions checker](../5-tooling/conventions-checker.md) enforces this list rather than
describing it: an undeclared folder, a stray file at the root of `lib/`, a missing `my_app_app.dart`
and a top-level name nested inside a zone are all errors.

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

A feature lives in a zone, and only there. The zone it belongs to is the one that owns the
behaviour, not the one that happens to show it first: a screen the admin panel and the app both
open belongs in `common/`, and a widget both draw with is not a feature at all — it is a block in
`shared/`.

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

The same lint package draws one more line, this time about imports: a relative import may walk at
most two levels up (`deep_relative_import`). One or two `../` read as "the feature next door";
past that the path names nothing, and the destination — `core/`, `shared/`,
`ui_kit/`, another zone — is spelled out with a `package:` import instead. The limit doubles as a
structure signal: a sibling four levels away is not a sibling.

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
inside it — is stripped, so the framework dependencies resolve from pub.dev like any other. The
toolkit lands in `.claude/`, with a default `settings.json` if the project has none, and
`dartway_notes.md` at the root.

Worth knowing if you ever put such a block back — inside the monorepo, or in your own project while
debugging a framework package. An override does more than redirect one dependency: **for the package
it names, pub stops checking constraints altogether.** Not "prefers the override" — the caret is
never evaluated, so a line that no published version could satisfy resolves in silence for as long
as the block is there. That is the same property [plugins](../3-flutter/plugins.md) warns against
using as a way to consume the framework, seen from its other side: the override is not only global
to the resolution, it also hides whether the constraints underneath it still say anything true. The
first tree to find out is one without the block — a new project, or CI.

So after adding a framework package to a project, resolve it once for real: run
`dart pub upgrade <the dartway packages>` in each package that gained one, and check that they came
out on a single commit. `dartway check` reports it when they did not — see
[the conventions checker](../5-tooling/conventions-checker.md).

## Where to go next

- [Quick start](quick-start.md) — bring it up, then add a model of your own.
- [Models](../2-core/models.md) — what goes in a `.spy.yaml` and what generation produces.
- [CRUD configs](../2-core/crud-configs.md) — the file in `lib/src/crud/`, in full.
- [How the app reads and writes data](../3-flutter/data-layer.md) — `dw.repo` in full.
- [The UI kit](../3-flutter/ui-kit.md) — what belongs in it and what does not.
- [The conventions checker](../5-tooling/conventions-checker.md) — the rules above, as a command.
