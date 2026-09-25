# How does a change happen exactly once?

A change is a command: a DTO extending `DwActionCommand<R>` whose fields are its input and whose `R`
is what the server answers. The app sends it with `dw.command(...)` (or inside `dw.action`, see
[../3-flutter/actions-and-refusal-texts.md](../3-flutter/actions-and-refusal-texts.md)); the server
runs exactly one handler for it, `DwCallHandler.command`.

## The result

The result is **one value, untagged**:

| `R` | Answers |
|---|---|
| a data object or other DTO class of the protocol | its JSON |
| `int`, `double`, `num`, `String`, `bool` | the JSON primitive |
| `void` | nothing |
| a nullable `R` | may be `null` |

Any other `R` — a `List`, a `Map`, `Object`, an enum — is refused by `dart run dartway_cli:dartway generate`, naming the
command: it would compile and fail when the first result is encoded.

**A collection is wrapped in a DTO (D-006).** The client decodes the result from the command's type
argument, and a generic `List<T>` cannot be decoded from an erased type; a server handler returning
one fails. Nothing names the result's type on the wire — it is the command's `R`, known to both
sides.

Usually a command answers the object it changed and publishes it too: the response brings the
caller's own screens up to date, the publication everyone else's
([channels-and-realtime.md](channels-and-realtime.md)).

## The input never carries what the server decides

The owner, timestamps, status, storage keys — a handler derives those from its context, never from a
field the client filled in. `BookSession` carries the session id; who books is `ctx.profile`, and
the booking's status and time are set by the handler
(`example/dartway_example_server/lib/src/club/booking_handlers.dart`). A command with an
`accountId` field is a command any signed-in user can send with someone else's.

## Validation runs on both sides

A command (or a request) that implements `DwSelfValidating` checks its own fields
(`example/dartway_example_shared/lib/src/news.dart`):

```dart
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
    if (text.trim().isEmpty)
      DwCallRefusal(ExampleRefusal.textRequired, field: 'text'),
  ];
}
```

The client runs `validate()` before sending — an invalid form costs no round trip — and answers the
first refusal as if the server had. The server runs it again before the handler, because a client is
never trusted to have checked. `validate()` depends on the fields only: whether a session start is in
the past depends on the clock, so `ScheduleSession` leaves that to the handler. Who may send the
command is not validation either; that is the access rule
([access-and-roles.md](access-and-roles.md)).

## Idempotency: one key per call

The network loses answers. A booking whose response never arrived, sent again, must not book twice.

Every command goes out with a `Dw-Idempotency-Key` header: 128 random bits the client generates for
one `command()` call and keeps across every retry of it — the body is encoded once, so every attempt
is byte-identical. The client retries network failures, and a gateway's `502`/`503`/`504` without a
DartWay body, with backoff until its call timeout; any DartWay answer is final and never retried. The
header is required on a command and forbidden on a request; either mistake is a malformed call (400).

The server stores the outcome per key and caller:

- **ok and refused outcomes are stored**, and a repeat of the key is answered with the stored one
  instead of running again. A refused intent answers the same on retry (D-013). That covers a
  refusal from validation, from the access check and from the handler. A 401 is not an outcome
  and is not stored.
- **A failure is not stored.** A failure must be retryable: the next send runs the handler again.
- **Outcomes are kept 7 days** (`DwServerSettings.commandOutcomeRetention`), removed hourly by the
  framework's cleanup job.
- A key reused for **another command class** is refused `dw.conflict` with
  `params: {idempotencyKey: reused}` and runs neither: one key, two intents is a client bug.
- Keys are scoped to the account (anonymous callers share one scope), and at most 128 characters.

**A replay carries no updates.** The stored success is answered with `"replayed": true`. The first
execution's publications went out when it ran — possibly while the caller's answer was being lost —
and nothing says they reached this client. So a client receiving a replay reads every watched request
again instead of trusting what it shows; entries nobody watches are released. It is rare: it takes a
lost response.

**A call that mints a token stores no successful outcome (D-043).** The outcome table must never hold
a bearer token in plain text for 7 days. A command whose context issued a session key
(`DwAccountService.issueKey`, and the framework's own sign-in) skips the success record
automatically; its refusals are still stored. A retried send runs again and issues a second key; the
first, whose token nobody received, is listed and revocable
([../4-server/auth-identity.md](../4-server/auth-identity.md)).

## Transactional by default

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
    await ctx.publishAdminCounters();
    return post;
  },
),
```

(`example/dartway_example_server/lib/src/content/content_handlers.dart`)

By default the access check, the handler and the idempotency record run in **one database
transaction**. Two sends of one key racing each other queue on the key's lock, and the second finds
the first one's outcome. A serialization conflict is retried up to three attempts. A refusal rolls
the transaction back — nothing the handler wrote survives — and then stores the refusal. Publications,
revocations and enqueued jobs take effect only after commit
([channels-and-realtime.md](channels-and-realtime.md)).

`transactional: false` is for a handler that calls an external service: holding a transaction open
across an HTTP call to a payment provider or a mail gateway holds a connection and its locks for as
long as that service takes. Such a handler opens `ctx.transaction` around the writes that belong
together. It gives up the atomic record: its outcome is stored after it returns, two sends of one key
racing each other both run, and a failure after a write it committed leaves that write in place while
the next send runs the handler again. The framework's code sign-in (`DwVerifyCode`) runs so, because
a wrong code must commit its spent attempt even though the answer is a refusal.

## What the caller gets

`dw.command` answers a `DwCallResult<R>` — ok, refused, not authenticated or failed — never a thrown
refusal: see [refusals-and-statuses.md](refusals-and-statuses.md). Handlers are written in
[../4-server/handlers-and-context.md](../4-server/handlers-and-context.md).
