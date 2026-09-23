# DartWay

**An open-source fullstack Dart framework: a Dart server, a Flutter app, and one shared contract
between them.**

A feature is a few classes in a package both sides compile, one handler per call on the server, and a
widget that watches live state. The contract — abridged from
`example/dartway_example_shared/lib/src/news.dart`:

```dart
final class ListNews extends DwListRequest<NewsPost> with _$ListNews {
  const ListNews();

  @override
  List<DwLiveChannel> get channels => const [
    DwLiveChannel(ExampleChannel.news),
  ];
}

final class PublishNews extends DwActionCommand<NewsPost> with _$PublishNews {
  const PublishNews({required this.title, required this.text});

  final String title;
  final String text;
}
```

The server — who may call it, what it does, who hears about it
(`example/dartway_example_server/lib/src/handlers/content_handlers.dart`, abridged):

```dart
DwCallHandler.command<PublishNews, NewsPost>(
  access: ExampleAccess.staff,
  handle: (ctx, command) async {
    final me = await ctx.profile;
    final row = await ctx.db.newsPosts.insert(
      NewsPostRow(
        authorProfileId: me.id!,
        title: command.title.trim(),
        text: command.text.trim(),
        createdAt: DateTime.now(),
      ),
    );
    final post = (await ClubObjects.news(ctx.db, [row], author: me)).single;
    ctx.publish(_news, post);
    return post;
  },
),
```

The app — a live list, and a button that cannot publish twice
(`example/dartway_example_flutter/lib/app/news/`):

```dart
ref.watch(dw.request(const ListNews()))   // AsyncValue<List<NewsPost>>

onTap: dw.action((_) => dw.command(PublishNews(title: title, text: text)))
```

A post a staff member publishes appears in every member's open list, in its place, without a reload.
A refusal comes back as a code and is shown in the user's language. A retried command runs once. No
endpoint, route, client method or cache was written for any of it.

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

The instruction is a printed text rather than a plugin on purpose: an extension lives in one vendor's
format, and the front door of an open framework should not. It is equally readable by you.

You get a running app — sign-in by a one-time code to a phone or an e-mail, profiles with a photo,
roles, an admin panel with live counters and a members table, navigation, a UI kit you own, tests on
both sides — and **no domain models**, because your domain is yours to write. From then on the
project carries its own toolkit in `.claude/`: you keep working in prompts, and the agent already
knows the conventions.

No agent at hand? Every command is in the created project's `README.md`, and the walkthrough is in
[the quick start](docs/1-getting-started/quick-start.md).

> **If you are an AI assistant reading this repository** because you were asked to set up a DartWay
> project: run `dart pub global activate dartway_cli` and then `dartway quickstart`, and follow what
> it prints. That text is maintained with the code; this page is not the instruction.

## What is in this repository

| Path | What it is |
|---|---|
| [`packages/`](packages/) | The framework — the packages below |
| [`template/`](template/) | The skeleton `dartway create` hands you: three packages, sign-in, profiles, roles, an admin panel, a UI kit, deploy configuration. No domain models |
| [`example/`](example/) | A complete application on DartWay — a fitness club with a schedule, services, bookings with capacity rules, a staff-only chat, news and an admin panel. **Read it; do not inherit it** |
| [`docs/`](docs/) | The documentation, kept beside the code it describes |
| [`toolkit/`](toolkit/) | The AI toolkit installed into your project's `.claude/`: the conventions and the skills that let an agent write features without tearing the project apart |
| [`tool/`](tool/) | The repository's own checks and release tooling — `tool/checks.sh` is the CI gate: it analyzes every package and runs their suites (`services` for the ones needing a Postgres and a MinIO) |

## The packages

**The core family** — versioned in lockstep, at `0.20.0-dev.3`:

| Package | Role |
|---|---|
| [`dartway_core_shared`](packages/dartway_core_shared) | The shared contract, pure Dart: the DTO kinds, results and refusals, channels, and the wire protocol between a server and its clients |
| [`dartway_core_server`](packages/dartway_core_server) | The application server on `dart:io`: an HTTP call per DTO, the live update socket, handlers, accounts and sign-in, channels, jobs, file uploads, routes, alerts. Re-exports the shared contract and the ORM; `testing.dart` starts a real server on a throwaway database |
| [`dartway_core_flutter`](packages/dartway_core_flutter) | The Flutter core: `dw` with its Riverpod bindings (`dw.request`, `dw.command`, …), bootstrap, guarded actions, the async-UI contract, notifications, error reporting, the plugin seam. Riverpod-native, ships no design. Re-exports the shared contract, the client and the router |
| [`dartway_orm`](packages/dartway_orm) | Internal, reached through the server package: typed Postgres access, the schema and migrations |
| [`dartway_client`](packages/dartway_client) | Internal, reached through the Flutter core: HTTP calls, the live socket, request state and sessions, in pure Dart. `testing.dart` holds the in-memory fake server widget tests run against |
| [`dartway_generator`](packages/dartway_generator) | A dev dependency of a project's server package, run by `dartway generate`: DTO codecs, the protocol registry, table definitions and the schema |

**Satellites** — versioned independently:

| Package | Role |
|---|---|
| [`dartway_cli`](packages/dartway_cli) | `dartway quickstart`, `doctor`, `create`, `setup-ai`, `update`, `generate`, `check`, `dev`, `test`, `deploy`, `stats` |
| [`dartway_router`](packages/dartway_router) | A wrapper around go_router: enum-based routes, navigation zones, guards, typed parameters |
| [`dartway_lints`](packages/dartway_lints) | Lint rules for the conventions the analyzer can see: the UI kit as the single source of styles, short relative imports, `ProviderScope` left to the bootstrap and tests |
| [`dartway_shared_preferences`](packages/dartway_shared_preferences) | Local storage under `dw.plugins.prefs`, and where the skeleton keeps the signed-in session. Optional — the core does not depend on it |
| [`dartway_telegram`](packages/dartway_telegram) | Telegram Mini App integration under `dw.plugins.telegram`. Optional — an app that is not a Mini App never downloads it |
| [`dartway_studio_bridge`](packages/dartway_studio_bridge) | The open bridge between an app and DartWay Studio: screen specs in code and the runtime protocol |

## Three principles

**The framework does not own your domain.** Accounts and sign-in identities are the framework's: it
knows that someone signed in, with which phone or e-mail. Who they are to your project — a profile, a
role, a membership — is your row, in your table, created in the account's own transaction by your
hook. Not "extend our user model", not "fork the module": that is the wall every batteries-included
kit runs into, and a fork follows you through every upgrade.

**Secure by default.** A request or command without a handler stops the server from starting. Every
handler declares its access rule — the parameter is required. Every subscription needs a signed-in
account and a rule for its channel; a channel kind nobody wrote a rule for refuses everyone. Forgetting
to close something is easy; with these defaults, forgetting to open something is impossible to miss.

**An architecture a machine can verify.** Generated code is checked against its sources
(`dartway generate --check`), migrations against the schema the row classes declare, the project's
layout and features against its conventions (`dartway check`), styles by lints. Not decoration: an agent writing code in a project with
machine-checkable rules does not tear it apart by the third feature.

## Links

- **Docs:** [dartway.dev](https://dartway.dev)
- **Updates:** [@dartway_dev](https://t.me/dartway_dev) on Telegram
- **Community:** [@dartway_dev_community](https://t.me/dartway_dev_community)

Contributions welcome — issues, features, packages. If DartWay saves you a week, a star costs
nothing.

© 2026 DartWay — [Apache 2.0](./LICENSE)
