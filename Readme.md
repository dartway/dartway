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
ref.watchModelList<Booking>().dwBuildListAsync(
      loadingItemsCount: 4,
      childBuilder: (bookings) => ListView(children: [...]),
    );
```

Serverpod gives you a backend. **DartWay removes the need to write one.**

## Start

```bash
dart pub global activate dartway_cli
dartway create my_app

cd my_app/my_app_server
docker compose up -d                       # Postgres
dart bin/main.dart --apply-migrations      # schema
dart bin/seed_dev.dart --mode development  # one user per role

# in another terminal
cd ../my_app_flutter
flutter run
```

You get a running app: passwordless phone auth, roles, navigation, an admin panel and a UI kit you
own — and **no domain models**, because your domain is yours to write. Sign in with `79990000003`;
the one-time code is printed by the server.

Full walkthrough: [dartway.dev/docs/quick-start](https://dartway.dev/docs/quick-start).

## What is in this repository

| Path | What it is |
|---|---|
| [`packages/`](packages/) | The framework — nine packages (see below) |
| [`template/`](template/) | The skeleton `dartway create` hands you. No domain models |
| [`example/`](example/) | A complete application built on DartWay — a fitness club with a schedule, bookings, a staff-only chat, news and an admin panel. **Read it; do not inherit it** |
| [`docs/`](docs/) | Documentation source |
| [`toolkit/`](toolkit/) | The AI toolkit installed into your project: skills and conventions that let an agent write features without tearing the project apart |

## The packages

**The core** — versioned in lockstep:

| Package | Role |
|---|---|
| [`dartway_serverpod_core_server`](packages/dartway_serverpod_core/dartway_serverpod_core_server) | A Serverpod module: generic model-driven CRUD with realtime subscriptions, declarative access and validation configs, phone auth, cloud storage, alerts |
| [`dartway_serverpod_core_flutter`](packages/dartway_serverpod_core/dartway_serverpod_core_flutter) | The typed realtime data layer: `watchModelList`, sessions, connection-aware error handling |
| [`dartway_serverpod_core_client`](packages/dartway_serverpod_core/dartway_serverpod_core_client) | The generated protocol client |
| [`dartway_serverpod_core_shared`](packages/dartway_serverpod_core/dartway_serverpod_core_shared) | The pure-Dart layer shared by both sides |

**Everything else** — independent:

| Package | Role |
|---|---|
| [`dartway_flutter`](packages/dartway_flutter) | The app skeleton: bootstrap, guarded actions, the async-UI contract, notifications, error reporting. Ships no design system |
| [`dartway_cli`](packages/dartway_cli) | `dartway create` / `setup-ai` / `check` / `stats` |
| [`dartway_lints`](packages/dartway_lints) | The conventions, enforced by machine |
| [`dartway_telegram`](packages/dartway_telegram) | Telegram Mini App integration. Optional — an app that is not a Mini App never downloads it |
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
