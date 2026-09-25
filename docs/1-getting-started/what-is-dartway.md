# What is DartWay?

DartWay is a fullstack framework for building an application in one language. The server is Dart on
`dart:io` over Postgres, the app is Flutter, and between them sits a pure-Dart package both sides
compile: **the contract**. Every call the app can make, every object it can receive and every reason
the server can give for saying no is a class in that package, and nothing else crosses the wire.

It is not a starter kit you copy once. It is a set of pub packages your project depends on, plus a
skeleton project `dartway create` generates — sign-in, profiles, roles, an admin panel, a UI kit —
with no domain in it.

## The one idea: a contract, not endpoints

A feature starts as classes in the shared package. Abridged from
`example/dartway_example_shared/lib/src/news.dart`:

```dart
final class NewsPost extends DwDataObject with _$NewsPost {
  const NewsPost({
    required this.id,
    required this.title,
    required this.text,
    required this.author,
    required this.createdAt,
  });

  @override
  final int id;
  final String title;
  final String text;
  final PersonCard author;
  final DateTime createdAt;
}

final class ListNews extends DwListRequest<NewsPost> with _$ListNews {
  const ListNews();

  @override
  List<DwLiveChannel> get channels => const [
    DwLiveChannel(ExampleChannel.news),
  ];

  @override
  int Function(NewsPost a, NewsPost b) get sort =>
      (a, b) => b.createdAt.compareTo(a.createdAt);
}

final class PublishNews extends DwActionCommand<NewsPost>
    with _$PublishNews
    implements DwSelfValidating {
  const PublishNews({required this.title, required this.text});

  final String title;
  final String text;

  @override
  List<DwCallRefusal> validate() => [
    if (title.trim().isEmpty)
      DwCallRefusal(ExampleRefusal.titleRequired, field: 'title'),
  ];
}
```

`dart run dartway_cli:dartway generate` writes the `_$…` mixins — the JSON codec and value equality — and the protocol
registry both sides share. The server answers each call with one handler. Abridged from
`example/dartway_example_server/lib/src/content/content_handlers.dart`:

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

The app speaks the same classes — from
`example/dartway_example_flutter/lib/app/news/widgets/news_post_list.dart` and
`create_news_post_sheet.dart` next to it:

```dart
ref.watch(dw.request(const ListNews()))   // AsyncValue<List<NewsPost>>, live

AppButton.primary(
  l10n.publish,
  onTap: dw.action(
    (_) => dw.command(PublishNews(title: title.value, text: text.value)),
    onSuccessNotification: l10n.postPublished,
  ),
)
```

**What this buys.** The shape of every call is compiled on both sides from one declaration, so a
renamed field breaks the build of the app and of the server at once, not a request in production. A
rule that reads only the call's own fields — `validate()` — runs in the app before sending and on the
server before the handler, from the same code. Who may call is decided on the server alone, where the
client cannot skip it.

**What it costs.** Every call is a class and a handler, written on purpose. There is no generic "save
any row": a read and the command that changes the same data are separate declarations, each with its
own access rule, because they are separate decisions.

## Three kinds of DTO

Everything in the contract is one of three things:

- **A data object** (`DwDataObject`) — something the app shows. It has an `id`, and the id is how an
  update finds it on screen. It is not a table row: the server builds it from rows, and it carries
  exactly what a client may see.
- **A request** (`DwDataRequest`) — a read. Its kind states the shape of the answer:
  `DwSingleRequest` (absent is refused as not found), `DwMaybeRequest` (absent is a value),
  `DwListRequest`, `DwPageRequest` (an accumulating feed), `DwTableRequest` (numbered pages with a
  total) and `DwWindowRequest` (a window anchored anywhere that grows both ways — a chat).
- **A command** (`DwActionCommand<R>`) — a change. Its result is a data object, a primitive or
  nothing.

The kinds are sealed, and each handler factory takes only its own kind: a list handler for a single
request does not compile.

## A request is live state, keyed by its value

`dw.request(const ListNews())` is not a fetch. It is shared state for that request: every widget
watching an equal request — same class, same field values — reads one entry, asked once. The request
declares its channels, and while anyone watches it, the client listens to them. An object published
there is put into the state by rules the request itself declares: `matches`, `sort`, and the update
action it answers (`DwUpdateAction`: upsert, update, remove, refetch, ignore).

Those rules are pure functions of the object and the request's fields, and that is the point: the
client applies an update without asking the server again, so the rule must be computable from what
the client holds. A `DateTime.now()` inside `matches` gives two clients two answers.

Client state is scoped by account. Signing in as someone else releases every entry and asks again;
a "my bookings" request carries no account id at all — its channel is `DwLiveChannel.ofCaller(kind)`,
resolved to whoever is signed in.

## A command carries an idempotency key

The client sends every command with a `Dw-Idempotency-Key` and retries a network failure with the same
key. The server records the outcome under that key, in the command's own transaction, and answers a
repeat with the recorded outcome instead of running the handler again — for seven days by default.

A double tap, a dropped response, a proxy that answered `502` after the server committed: each of
these makes one booking, not two. An endpoint that is "usually called once" is how a payment is taken
twice.

## A channel is an audience

A handler publishes objects to channels (`ctx.publish`), and they leave only after the transaction
commits — a change that rolled back is never seen. They come back in the command's own response,
grouped by channel, and go over the live socket to everyone else subscribed.

Who may subscribe is declared once per channel kind on the server (`DwChannelRule.single`, `.keyed`,
`.ofCaller`) and checked at subscription. Every subscription requires a signed-in account, and a kind
with no rule refuses everyone. The client applies an object only to requests that declare the channel
it arrived on: the channel is the one fact that says whose data an object is. An admin's screen and a
member's screen can both receive a `UserProfile`; only the channel tells them apart.

## A refusal is a code, not a sentence

When a rule says no, the server answers with a code — a value of the project's enum
(`with DwRefusalCodes`) or of the framework's (`DwCoreRefusal`, `DwAuthRefusal`, `DwUploadRefusal`) —
with an optional field and parameters. It never answers with text.

The text is the app's: `DwFlutterConfig.refusalText` turns a code into the user's language, and `dw.action`
shows it with no further code. A server that writes messages writes them in one language for one
screen, and an app that receives a sentence cannot react to "no spots left" differently from "the
session has started".

## HTTP per call, a socket for updates only

A call is `POST /dw/<WireName>` with the DTO's own JSON as the body. The live socket, `GET /dw/live`,
carries subscriptions and updates and nothing else. `GET /health` answers liveness and database
reachability.

Calls are plain HTTP because everything between an app and a server already understands HTTP: a
proxy, a load balancer, a retry, a log line, `curl`. Only what cannot be asked for — somebody else's
change — needs a connection that stays open. So a call works while the socket is down; what stops is
the data on screen following the server, and `dw.liveStatus` says so.

## Honest statuses

Every answer is one of five bodies — ok, refused, unauthenticated, failed, incompatible — and the HTTP
status follows from the body: `200`; `422` for a refusal, with `403`, `404`, `409` and `429` for the
framework's forbidden, not-found, conflict and too-many-requests; `401`; `500` for a failure and `400`
for a malformed call; `426` when this build of the app is too old for this server. A failure carries
an incident id and no detail. A refusal never raises an alert; a server failure does.

`426` is how an old app learns it has to update: the Flutter core shows `DwFlutterConfig.updateRequiredScreen`
instead of failing to decode an answer it does not understand.

## The framework knows no domain

The framework owns **accounts and identities**: that someone signed in, with which phone or e-mail,
under which session key. It does not know who they are to your project. A profile, a role, a
membership are your rows in your tables, created in the account's own transaction by your
`DwAuthConfig.onAccountCreated`.

That is the wall a batteries-included kit hits from the other side: a framework that owns the user
model owns your domain, and the first field it lacks becomes a fork you carry through every upgrade.

## Rules held by types and checks, not by memory

- A request or command with no handler stops the server from starting. So does a handler for a call
  the protocol does not register, or two handlers for one call.
- Every handler declares its access rule — `DwAccessRule.anonymous`, `.signedIn` or `.check` — and
  the parameter is required.
- The server applies its migrations as it starts and exits non-zero when one fails, or when a table
  or column the schema declares is missing.
- `dart run dartway_cli:dartway generate --check` fails on generated code that no longer matches its sources, and the
  project's `bin/migrate.dart check` on migrations that do not produce the schema the row classes
  declare.
- `dart run dartway_cli:dartway check` grades the project against its conventions: the layout, features, the UI kit,
  generated code, migrations.
- A change to what travels on the wire is a protocol version change, held by a golden test in the
  framework.

A rule that lives only in a document holds until the first person — or agent — who did not read it.

Two more principles run underneath all of this. **Engineering perfection**: no redundant operation,
no redundant update, no byte on the wire the receiver did not ask for — a design that sends or
computes more than necessary because it is simpler to write that way is not the default here.
**One source per fact**: a derived artefact is generated from its one source, never kept in sync by
a test that compares two copies — the generated protocol registry and schema (above) are exactly
this, not a convenience.

## What DartWay deliberately does not give you

- **A design system.** There is no framework button, text widget or theme. `dartway create` puts a UI
  kit **into** your app as source you own — `AppText`, `AppButton` and the rest in `lib/ui_kit/`.
  What the framework keeps is the mechanism: [actions and refusal texts](../3-flutter/actions-and-refusal-texts.md)
  and the [data layer](../3-flutter/data-layer.md).
- **A choice of state management.** The Flutter core is Riverpod-native: requests are providers, and
  their state is an `AsyncValue` whose errors are typed.
- **A choice of backend.** The client talks to a DartWay server. It is not a generic REST client.
- **Domain models.** The skeleton has sign-in, profiles, roles and an admin panel, and no model of
  anybody's business.
- **An offline store.** Request state lives in memory while it is watched; what is on screen is what
  the server last answered.

## Who it is for

It fits an app whose substance is data belonging to users, with rules about who sees and changes
what, and screens that should follow changes live: bookings, catalogues, chats, orders, admin panels,
internal tools. It fits a small team or a solo developer who would otherwise spend the first month on
sign-in, roles and an admin panel. It fits a project meant to be maintained by agents as well as
people, because the conventions are checked by tooling.

It is a poor fit when:

- you already have a backend you are not replacing;
- the app has to work fully offline;
- your product is mostly computation, media or third-party orchestration rather than data;
- your team does not want to work in Riverpod.

## Where to go next

- [Quick start](quick-start.md) — a running app, then the checks.
- [Project layout](project-layout.md) — the three packages and what lives where.
- [Data objects and generation](../2-core/data-objects-and-generation.md) — the contract in full.
- [Requests and updates](../2-core/requests-and-updates.md) — the request kinds and update actions.
- [Commands and idempotency](../2-core/commands-and-idempotency.md) — what a key guarantees.
- [Channels and realtime](../2-core/channels-and-realtime.md) — publishing and subscription rules.
- [Refusals and statuses](../2-core/refusals-and-statuses.md) — codes, texts and HTTP statuses.
- [Access and roles](../2-core/access-and-roles.md) — who may call and who may listen.
- `example/` — a complete application on DartWay: a fitness club with a schedule, bookings with
  capacity rules, a staff-only chat, news, sign-in by code, roles and an admin panel. A reference to
  read, not a project to inherit.
