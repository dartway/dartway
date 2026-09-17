---
name: dartway-realtime
description: >-
  Live updates in a DartWay project: channel kinds (`<Project>Channel with DwChannelKind`), the
  channels a request declares (DwLiveChannel, keyed channels, DwLiveChannel.ofCaller for "my"
  requests), the server's DwChannelRule per kind (single / keyed / ofCaller) — who may read
  everything on a channel — publishing from commands, jobs and auth hooks after commit to every
  channel that shows the object (DwLiveChannel.forAccount for someone's "my" channel), deletions as
  DwDeletedObject.of<T>(id, ctx.protocol), ctx.revoke when access is taken away, and choosing what
  an update does to a request (DwUpdateAction, named constructors, matches, sort, positionOf; table
  pages read again). Also how to test it: two real clients on DwTestServer, or a raw live socket.
  Use when a screen must follow changes made elsewhere, when adding a channel, when a command
  changes data other people see, or when a screen stays stale or shows someone else's data.
---

# DartWay — realtime: channels, publishing, update actions

A screen follows the server by **watching a request that declares channels**. A command that changes
data **publishes** the changed objects to channels; every client watching a request on that channel
applies them — the author's own screens from the command's response, everyone else's over the live
socket. No refetch code, no subscription widgets, no update handlers in the app.

The three halves, and a missing one fails silently:

1. **the request declares its channels** — `__SHARED_PKG__` (`dartway-contract`);
2. **the server declares who may subscribe** to each channel kind — `DwChannelRule`;
3. **every command that changes the object publishes it** to every channel that shows it.

Related skills: `dartway-contract`, `dartway-server`, `dartway-access`, `dartway-data-layer`,
`dartway-testing`. In the samples `AppChannel` stands for the project's `<Project>Channel`.

## 1. A channel is an audience

Everything published to a channel reaches **every subscriber** of it. Access is checked **once, at
subscription** — nothing re-checks each object. So the rule that decides the channels:

> **a channel's audience is exactly the people allowed to read every object published to it.**

| Who may see the change | Channel | Server rule |
|---|---|---|
| every signed-in member (a catalogue, app settings, news) | `DwLiveChannel(AppChannel.news)` | `DwChannelRule.single(kind, canSubscribe: …)` |
| one group (a project's board, a chat room) | `DwLiveChannel(AppChannel.board, boardId)` | `DwChannelRule.keyed<int>(kind, parseKey: int.parse, canSubscribe: (ctx, boardId) …)` |
| one person — "my invoices", "my profile" | request: `DwLiveChannel.ofCaller(AppChannel.invoices)`; publish: `DwLiveChannel.forAccount(AppChannel.invoices, accountId)` | `DwChannelRule.ofCaller(kind)` |
| a role (managers, admins) | `DwLiveChannel(AppChannel.billing)` | `DwChannelRule.single(kind, canSubscribe: (ctx) => ctx.isManager)` |

Every subscription requires a signed-in connection. Signed out, a request with channels is fetched
and simply not live; it becomes live after sign-in.

**The anti-pattern is one broad channel for everything.** A member's invoice published to a
channel every member subscribes to is readable by every member — the request's handler would never
have shown it to them, and the channel does not care. A private object goes to its owner's
`forAccount` channel and to the channels of the roles that may see it, never to a shared one.

## 2. Declare the kind and the request's channels (shared)

```dart
enum AppChannel with DwChannelKind {
  /// One member's own invoices: a caller channel, keyed by the account.
  invoices,

  /// Everything the billing screens show. Managers only.
  billing,

  /// The events of one invoice. Key: the invoice id. Its owner and managers.
  invoiceEvents,
}
```

A request lists the channels its state absorbs:

```dart
@override
List<DwLiveChannel> get channels => const [
  DwLiveChannel.ofCaller(AppChannel.invoices),
];
```

A keyed channel built from a field is not `const`:
`List<DwLiveChannel> get channels => [DwLiveChannel(AppChannel.invoiceEvents, invoiceId)];`.

- **A "my" request carries no account id** and declares `DwLiveChannel.ofCaller(kind)`; the client
  resolves it to the signed-in account when it subscribes (`invoices:42`).
- **A request without channels hears no updates** — not even the author's own commands. A snapshot
  (a search result) is legitimately such a request.
- `channels` is a pure function of the request's fields.

## 3. Declare who may subscribe (server)

One rule per kind, in `DwAppServer(channels: [...])`:

```dart
// AppChannels — lib/src/channels.dart
static final rules = <DwChannelRule>[
  // "My" channel: a member subscribes to their own account's key only.
  DwChannelRule.ofCaller(AppChannel.invoices),
  DwChannelRule.single(
    AppChannel.billing,
    canSubscribe: (ctx) => ctx.isManager,
  ),
  DwChannelRule.keyed<int>(
    AppChannel.invoiceEvents,
    parseKey: int.parse,
    canSubscribe: (ctx, invoiceId) async {
      final invoice = await ctx.db.invoices.findById(invoiceId);
      if (invoice == null) return false;
      return invoice.ownerProfileId == (await ctx.callerProfile).id ||
          await ctx.isManager;
    },
  ),
];

/// Where [accountId]'s own invoices hear a change, whoever made it.
DwLiveChannel invoicesOf(int accountId) =>
    DwLiveChannel.forAccount(AppChannel.invoices, accountId);

const billingChannel = DwLiveChannel(AppChannel.billing);
```

- `canSubscribe` runs with the subscriber's context (`ctx.accountId` is set) and **must be as strict
  as the handlers of every request on that channel**. It is a second access point, not a courtesy:
  `dartway-access`.
- **A kind without a rule refuses every subscription** (`dw.unknownChannel`). The request still
  answers — it just never becomes live, and the client reports it to the app's error handler. The
  startup does not catch a missing rule; a test does (section 7).
- `parseKey` throws on malformed keys; the key must be canonical (`7`, not `07`).

## 4. Publish from every change

`ctx.publish(channel, object)` in a **command** (and in a job, a route, or an auth hook running in a
sign-in). Delivery happens **after the transaction commits** — nothing from a rolled-back or refused
attempt is sent. Publishing from a request handler throws: reads have no side effects.

**Publish the object to every channel that shows it.** One helper per data object that knows them
all, used by every command that changes it:

```dart
/// A changed invoice to everyone who shows it: its owner's "my invoices"
/// and the billing screens. Answers the invoice as clients see it.
Future<CustomerInvoice> publishInvoice(DwCallContext ctx, InvoiceRow row) async {
  final owner = (await ctx.db.memberProfiles.findById(row.ownerProfileId))!;
  final invoice = await InvoiceObjects.invoice(ctx, row);
  ctx
    ..publish(invoicesOf(owner.accountId), invoice)
    ..publish(billingChannel, invoice);
  return invoice;
}
```

- **Name the account, never "the caller".** To reach someone's "my" request, publish to
  `DwLiveChannel.forAccount(kind, theirAccountId)` — the owner of the row, not `ctx.accountId`. A
  manager changing a member's invoice must reach the member's screens, not the manager's own "my
  invoices". Publishing an unresolved `DwLiveChannel.ofCaller` on the server throws for exactly this
  reason.
- **Publish what changed as it now is**, mapped through the same batch function the handlers use —
  so a published object and a fetched one never differ. A derived object that changed too (a
  counter, a total) is published as well: `ctx.publish(billingChannel, await countTotals(ctx.db))`.
- **Deletions** travel as a notice, not as an object:
  `ctx.publish(channel, DwDeletedObject.of<CustomerInvoice>(invoiceId, ctx.protocol))`.
- An object that quotes or embeds a changed one (a card showing its invoice) is republished too —
  its embedded copy changed.
- **Publish everything that changed; the server sorts it.** The command's response carries the
  publications to channels whose rule allows the caller — socket or not — and subscribers hear them
  over the socket, the caller's own named connection excepted (D-053). A member's command (a sign-up, a
  booking) may publish a managers-only figure: managers hear it, the member's response never carries
  it. No "side effect" API: the boundary is the channel rule, so write every rule to be true for any
  caller, not only for the screen that subscribes.
- **A channel kind needs a rule** in `DwAppServer(channels:)` before anything is published to it:
  publishing to a kind without one throws.

Within one call, one object published twice to a channel travels once, as it ended.

### Keeping an item from some accounts — `exceptAccounts`

When an item on a shared channel must not reach certain members — a blocked author's message in a
group chat — pass `ctx.publish(channel, item, exceptAccounts: {...})`. Their connections and, if the
caller is one of them, the response do not carry it. **Never filter such an item on the client**: the
text has already reached the device. Never open a channel per member to get the same effect.

### Taking access away — `ctx.revoke`

Access is checked at subscription, so a command that removes someone's right to a channel closes it:

```dart
if (previousRole == MemberRole.manager && updated.role != MemberRole.manager) {
  ctx.revoke(billingChannel, updated.accountId);
}
```

Delivered after commit, like publications. Without it the demoted member keeps receiving everything
published to the channel until they reconnect. Signing out and revoking a session key close the
key's subscriptions by themselves.

**Every path that takes the right away needs its own `ctx.revoke`** — removing a member, deleting
the group, moving it to another owner, turning a public project private. The rule was asked once,
at subscription, and nothing asks it again; the server has no reason to notice that the answer has
changed.

**A test proves this only if it watches a channel that can be revoked.** A caller channel
(`ofCaller`) is never revoked — its key *is* the subscriber — so a test that removes someone and
then asserts their "my teams" list stays quiet passes whether or not the command revokes anything.
Watch the group's own channel instead, and prove the test can fail: delete the `ctx.revoke` and
see it go red.

### Hearing a channel without reading — `dw.listen`

When a screen only needs to *hear* publications — a "new posts" badge whose starting count comes from
a request — use `dw.listen([channels])`, a stream subscribed while listened to. **Never read a page
(or ask for one row) just to get a subscription**: that sends rows nobody shows. Missed publications
during a disconnect are not replayed — keep the exact number in a request.

## 5. What an update does to a request

When an object arrives on a channel a request declares (and is of the request's item type), the
request's `onUpdate` answers one `DwUpdateAction`:

| Action | Effect |
|---|---|
| `upsert` | replace the object with the same id where it stands; insert it when absent (by `sort`, else at the head) |
| `update` | replace where it stands; never insert |
| `remove` | remove the object with that id |
| `refetch` | read the request again |
| `ignore` | not this request's business |

The defaults, chosen by the kind and its named constructor:

| Request | An object arrives | A deletion arrives |
|---|---|---|
| `DwSingleRequest` | `update` (same id) | read again → `dw.notFound` |
| `DwMaybeRequest` | `matches ? upsert : remove` | `remove` |
| `DwListRequest()` / `DwPageRequest(pageSize:)` / `DwWindowRequest` | `matches ? upsert : remove` | `remove` |
| `DwListRequest.updateOnly()` / `DwPageRequest.updateOnly(pageSize:)` | `update` | `remove` |
| `DwListRequest.refetchOnUpdate()` | `refetch` | `refetch` |
| `DwTableRequest` | on the page: replaced in place; not on the page, or no longer matching: the page reads again | the page reads again |

How to choose:

- **The client can tell membership from the object** ("my invoices", "unpaid invoices of customer 7")
  → the default, with `matches` mirroring the server's filter on the request's fields. An object that
  stops matching leaves the list; a new one enters at its `sort` position.
- **Only the server knows membership** (a ranking, "recommended for you") → `.updateOnly()`: known
  objects update, nothing is inserted.
- **The value is derived** (aggregates, groups the client cannot compute) → `.refetchOnUpdate()`.
- **A page feed**: a new object that sorts past the loaded pages is dropped while more pages exist
  and shows up on scroll.
- **A window** (a chat): `positionOf` places a live insert; a new row newer than the loaded ones is
  inserted only while the window shows the newest rows, and counted as unseen otherwise.
- **A table page never grows by an update**: rows shift across pages and the total changes, so it
  reads the page again (rereads triggered together are coalesced). Narrow `matches` to the table's
  filter so a row that leaves the filter does not stay on the page.

A special case overrides `DwUpdateAction onUpdate(Object item)` on the request — kept a pure function
of the item and the fields.

## 6. The "my" pattern end to end

1. shared: `ListMyInvoices` declares `DwLiveChannel.ofCaller(AppChannel.invoices)` and no account id;
2. server: `DwChannelRule.ofCaller(AppChannel.invoices)`; the handler reads the caller from `ctx`;
3. every command changing an invoice publishes to `DwLiveChannel.forAccount(AppChannel.invoices,
   ownerAccountId)` — whoever made the change;
4. app: `ref.watch(dw.request(const ListMyInvoices()))` — state is kept per signed-in account, so
   switching accounts never shows the previous account's invoices.

## 7. Test it

Realtime is where silent failures live; each half gets a test in `__SERVER_PKG__/test/`, run by
`dartway test`.

**Two real clients** — the author changes, the other one hears it without asking:

```dart
final watch = manager.watch(const ListInvoicesPage());   // DwRequestWatch, live
await eventually(() => watch.isLive);

(await member.command(PayInvoice(invoiceId: id))).valueOrThrow;

await eventually(
  () => switch (watch.state) {
    DwRequestData(:final value) =>
      value.items.any((i) => i.id == id && i.status == InvoiceStatus.paid),
    _ => false,
  },
);
```

Clients come from `DwTestServer.connectClient()` (`package:dartway_core_server/testing.dart`) and are
signed in through the real sign-in; `eventually` is a polling helper of the test support — the
skeleton's server harness has both, plus a counter of HTTP calls to prove an update arrived live and
not by a re-read.

**The rule itself**, over a raw socket:

```dart
final socket = await server.openLive();
addTearDown(socket.close);
await socket.authenticate(memberToken);
final refused =
    await socket.subscribe('invoices:$otherAccountId') as DwSubscriptionRefusedMessage;
expect(refused.refusal?.isCode(DwCoreRefusal.forbidden), isTrue);
expect(await socket.subscribe('invoices:$ownAccountId'), isA<DwSubscribedMessage>());
```

What to cover for a new channel or a new publishing command:

- [ ] the other client's request hears the change (and the author's from the response);
- [ ] someone not entitled is refused at subscription (one refused subscribe per rule);
- [ ] "my" data published for account A never reaches account B's "my" request;
- [ ] a revoked right closes the channel (the client receives its `closed` frame) — on the group's
      own channel, not a caller channel, and verified by deleting the `ctx.revoke` and watching the
      test fail;
- [ ] a deletion leaves the other client's list;
- [ ] in `__SHARED_PKG__/test/`: `onUpdate` answers `upsert`/`remove` as intended for matching and
      non-matching objects.

Widget tests publish through the fake server (`server.publish(channel, [object])`) —
`dartway-testing`.
