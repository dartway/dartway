# What is DartWay?

DartWay is a fullstack framework for building an application in one language.
[Serverpod](https://serverpod.dev) runs the server, Flutter runs the client, and DartWay is the
layer over both that removes the work
you would otherwise redo on every screen: the endpoint, the client call, the repository, the cache,
the loading state, the "who is allowed to see this" check written twice.

It is not a starter kit you copy once. It is a set of pub packages your project depends on, plus a
skeleton project the CLI generates for you.

## The one idea: models and configs, not endpoints

In a normal Serverpod app you write an endpoint per operation, a client call per endpoint, and a
repository to hold the result. In a DartWay app you declare a model and configure who may do what
with it. The transport is already there.

The server side of a whole feature is one file:

```dart
// abridged from example/dartway_example_server/lib/src/crud/news_post_crud_config.dart
final newsPostCrudConfig = DwCrudConfig<NewsPost>(
  table: NewsPost.t,
  getListConfig: DwGetModelListConfig(
    accessFilter: (session) async => null,
    include: NewsPost.include(authorProfile: UserProfile.include()),
    defaultOrderByList: [Order(column: NewsPost.t.createdAt, orderDescending: true)],
  ),
  saveConfig: DwSaveConfig<NewsPost>(
    allowSave: (session, ctx) async =>
        await session.isStaffMember &&
        session.isUser(ctx.currentModel.authorProfileId),
    validateSave: (session, ctx) async =>
        ctx.currentModel.title.trim().isEmpty ? 'Title is required' : null,
    broadcastTo: (session, ctx) => [DwCoreConst.publicUpdatesChannel],
  ),
  deleteConfig: DwDeleteConfig<NewsPost>(
    allowDelete: (session, model) => session.isStaffMember,
    broadcastTo: (session, model) => [DwCoreConst.publicUpdatesChannel],
  ),
);
```

Register it once in the app's `DwCore.init(crudConfigurations: [...])`, and `NewsPost` is served:
get one, get a list, filter, order, paginate, save, delete. The client side is the other half of the
same idea — one object, `dw.repo`, with no repository, service or API client written by you:

```dart
// reads are Riverpod providers, consumed natively
ref.watch(dw.repo.modelList<NewsPost>())        // AsyncValue<List<NewsPost>>
ref.watch(dw.repo.model<ClubSession>(id: 42))   // AsyncValue<ClubSession>

// writes are plain methods
await dw.repo.saveModel(post);
await dw.repo.deleteModel(post);
```

**What this buys.** The rule that governs a piece of data lives in exactly one place, on the server,
where the client cannot forget it. Adding a field is a schema change and nothing else — no endpoint,
no DTO, no client method, no repository, no mock. And because access is declared per model rather
than per handler, "who can read this" is a property of the data, not a thing scattered across
however many endpoints happen to return it.

**What it costs.** Your interaction has to be shaped like rows. Something that is genuinely a
procedure — a report, an import, a payment callback — is still a plain Serverpod endpoint you write
by hand, and DartWay stays out of the way (`dw.repo.processApiResponse` folds its result back into
the open watchers). If most of your app is procedures rather than data, this framework is buying you
little.

## Secure by default

A model with no entry in `crudConfigurations` is not reachable at all. You grant access; you never
forget to take it away. The same applies inside a config: a `getListConfig` with no `saveConfig`
is readable and not writable, and there is no way to get a default-open behaviour by omission.

`accessFilter` returning `null` means "no filter" — everyone signed in reads everything. That is an
explicit sentence someone wrote, not a gap.

## Realtime is a decision, not a default

A save returns the updated rows to whoever saved them. For anyone *else* to see the change, the
config says so — `broadcastTo`, as in the example above. Nothing is written on the Flutter side:
every model arriving on a subscribed channel is routed by type into the `dw.repo.modelList<T>()` a
screen already watches.

This is a per-model decision on purpose, because a channel is an audience and the framework cannot
check it: broadcasting a row nobody else may read hands it to everybody. See
[realtime](../2-core/realtime.md).

## What DartWay deliberately does not give you

- **A design system.** There is no `DwButton`, no `DwText`, no theme. A design system is the one
  thing every serious app ends up owning, and shipping it as a dependency only starts an argument
  about the corner radius of your button. `dartway create` scaffolds a UI kit **into** your app as
  source you own — `AppText`, `AppButton` and friends in your `lib/ui_kit/`. What the framework
  keeps is the mechanism: the [action guard](../3-flutter/actions.md) and the
  [async-UI contract](../3-flutter/data-layer.md).
- **A choice of state management.** DartWay is Riverpod-native, and that is not swappable. The data
  layer exposes providers and `AsyncValue` is the type the whole async contract is built on.
- **A choice of backend.** The client's data layer talks to a DartWay CRUD server. It is not a
  generic REST client.
- **Domain models.** The generated project has auth, roles, navigation, an admin panel and a UI kit,
  and zero models of anybody's business. The domain is the part you write.

## Who it is for

It fits an app whose substance is data belonging to users, with rules about who sees and changes
what: bookings, catalogues, chats, orders, admin panels, internal tools. It fits a small team or a
solo developer who would otherwise spend the first month rebuilding auth, roles and an admin panel.
It fits a project that intends to be maintained — the conventions are checked by tooling, not by
memory (see the [conventions checker](../5-tooling/conventions-checker.md)).

It is a poor fit when:

- you already have a backend you are not replacing;
- your product is mostly computation, media or third-party orchestration rather than rows;
- you need a component library out of the box and have no intention of owning a kit;
- your team does not want to work in Riverpod.

## What is in the box

| Package | What it does |
|---|---|
| `dartway_serverpod_core_*` | The CRUD engine: configs, access, filters, realtime, auth, uploads |
| `dartway_flutter` | The app skeleton: bootstrap, actions, async-UI, notifications, error reports |
| `dartway_lints` | The conventions that can be enforced by the analyzer |
| `dartway_cli` | `dartway quickstart`, `doctor`, `create`, `setup-ai`, `check`, `stats`, `deploy` |
| `dartway_studio_bridge` | The protocol an app opens to [Studio](../6-studio/studio-bridge.md) |

Optional plugins live outside the core and are reached as `dw.plugins.<name>` — local storage
(`dartway_shared_preferences`), Telegram (`dartway_telegram`), push (`dartway_push`). An app that
needs none of them never downloads them.

## Where to go next

- [Quick start](quick-start.md) — a running fullstack app, then your first feature.
- [What `dartway create` gives you](project-layout.md) — the packages and folders, and why.
- [Why configure CRUD instead of writing endpoints](../2-core/crud-configs.md) — the idea in full.
- [Who is allowed to read and write what](../2-core/access-and-roles.md) — the three places
  authorisation lives, and the fact that there is no fourth.
- [How the app reads and writes data](../3-flutter/data-layer.md) — `dw.repo` in full.
- [`example/`](https://github.com/dartway/dartway/tree/master/example) — a complete application
  built exactly this way: a fitness club with a schedule, bookings with capacity rules, a staff-only
  chat, news, OTP auth, roles and an admin panel. A reference to read, not a project to inherit.
