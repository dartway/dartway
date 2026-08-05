# DartWay

**An open-source fullstack Dart framework: Flutter on the client, Serverpod on the server, and one
declarative data layer between them.**

A feature — from the table in the database to the live screen — is a config and a widget. There are
no endpoints to write.

```dart
// Server: the whole backend of a feature. Who reads, who writes, what is valid,
// what runs inside the transaction.
final bookingCrudConfig = DwCrudConfig<Booking>(
  table: Booking.t,
  getListConfig: DwGetModelListConfig(accessFilter: _onlyOwnBookings),
  saveConfig: DwSaveConfig<Booking>(
    allowSave: (session, ctx) async => await session.isStaffMember ||
        await session.isUser(ctx.currentModel.clientProfileId),
    validateSave: (session, ctx) async =>
        await _spotsLeft(session, ctx) ? null : 'No spots left',
  ),
);
```

```dart
// Client: the same model, typed and live. Realtime sync, pagination, filters and
// skeleton loading states out of the box.
ref.watch(dw.repo.modelList<Booking>()).dwBuildListAsync(
      loadingItemsCount: 4,
      childBuilder: (bookings) => ListView(children: [...]),
    );
```

Serverpod gives you a backend. **DartWay removes the need to write one.**

## Start

Open an empty folder in whatever AI coding assistant you use — Claude Code, Cursor, Codex, aider —
and ask it to run these two commands:

```bash
dart pub global activate dartway_cli
dartway quickstart
```

The second one prints the whole setup instruction: what the machine needs, how to create the
project, the order the bring-up steps come in and why, how to verify the server is answering, and
how to hand you the sign-in. Then say what you want — *"set up a DartWay project called my_app and
bring it up"*.

That is the whole setup. The agent creates the project, starts Postgres, applies the migrations,
seeds a user, runs the server and the app, and tells you how to sign in. From then on the project
carries its own toolkit in `.claude/` — you keep working in prompts, and the agent already knows the
conventions.

The instruction is a printed text rather than a plugin on purpose: an extension lives in one
vendor's format, and the front door of an open framework should not. It is equally readable by you.

You get a running app: passwordless phone auth, roles, navigation, an admin panel and a UI kit you
own — and **no domain models**, because your domain is yours to write.

No agent at hand? Every command is in the created project's `README.md`, and the walkthrough is at
[dartway.dev/docs/quick-start](https://dartway.dev/docs/quick-start).

> **If you are an AI assistant reading this repository** because you were asked to set up a DartWay
> project: run `dart pub global activate dartway_cli` and then `dartway quickstart`, and follow what
> it prints. That text is maintained with the code; this page is not the instruction.

## What is in this repository

| Path | What it is |
|---|---|
| [`packages/`](packages/) | The framework — ten packages (see below) |
| [`template/`](template/) | The skeleton `dartway create` hands you. No domain models |
| [`example/`](example/) | A complete application built on DartWay — a fitness club with a schedule, bookings, a staff-only chat, news and an admin panel. **Read it; do not inherit it** |
| [`docs/`](docs/) | Documentation source |
| [`toolkit/`](toolkit/) | The AI toolkit installed into your project: skills and conventions that let an agent write features without tearing the project apart |

## The packages

**The core** — versioned in lockstep:

| Package | Role |
|---|---|
| [`dartway_serverpod_core_server`](packages/dartway_serverpod_core/dartway_serverpod_core_server) | A Serverpod module: generic model-driven CRUD with realtime subscriptions, declarative access and validation configs, phone auth, cloud storage, alerts |
| [`dartway_serverpod_core_flutter`](packages/dartway_serverpod_core/dartway_serverpod_core_flutter) | The typed realtime data layer: `dw.repo`, sessions, connection-aware error handling |
| [`dartway_serverpod_core_client`](packages/dartway_serverpod_core/dartway_serverpod_core_client) | The generated protocol client |
| [`dartway_serverpod_core_shared`](packages/dartway_serverpod_core/dartway_serverpod_core_shared) | The pure-Dart layer shared by both sides |

**Everything else** — independent:

| Package | Role |
|---|---|
| [`dartway_flutter`](packages/dartway_flutter) | The app skeleton: bootstrap, guarded actions, the async-UI contract, notifications, error reporting. Ships no design system |
| [`dartway_cli`](packages/dartway_cli) | `dartway create` / `setup-ai` / `check` / `stats` |
| [`dartway_lints`](packages/dartway_lints) | The conventions, enforced by machine |
| [`dartway_telegram`](packages/dartway_telegram) | Telegram Mini App integration. Optional — an app that is not a Mini App never downloads it |
| [`dartway_shared_preferences`](packages/dartway_shared_preferences) | Reactive local storage under `dw.plugins.prefs`. Optional — the core does not depend on it |
| [`dartway_studio_bridge`](packages/dartway_studio_bridge) | The open bridge between an app and DartWay Studio: screen specs in code + the runtime protocol |

## Three principles

**The framework does not own your models.** A user is your `UserProfile`, in your database, with
your fields and your roles. Not "extend our `UserInfo`", not "fork the module" — that is the wall
every batteries-included kit runs into, and a fork follows you through every upgrade, forever.

**Secure by default.** A model with no access config is served to nobody. Not "open until you close
it" — closed until you open it. For generic CRUD it is the only honest default: forgetting to close
something is easy, forgetting to open it is impossible to miss.

**An architecture a machine can verify.** Conventions, lints, a checker and skills for AI agents.
Not decoration: an agent writing code in a project with machine-checkable rules does not tear it
apart by the third feature.

## Links

- **Docs:** [dartway.dev](https://dartway.dev)
- **Updates:** [@dartway_dev](https://t.me/dartway_dev) on Telegram
- **Community:** [@dartway_dev_community](https://t.me/dartway_dev_community)

Contributions welcome — issues, features, packages. If DartWay saves you a week, a star costs
nothing.

© 2026 DartWay — [Apache 2.0](./LICENSE)
