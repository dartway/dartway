---
name: dartway-realtime
description: >-
  Live updates in a DartWay project: channel kinds, the channels a request declares (keyed, ofCaller
  for "my" requests), the server's DwChannelRule per kind, publishing from commands, jobs and hooks
  after commit to every channel that shows the object (forAccount for someone's "my" channel),
  deletions, exceptAccounts, ctx.revoke, dw.listen, what an update does to each request kind, and how
  to test it. Use when a screen must follow changes made elsewhere, when adding a channel, when a
  command changes what others see, or when a screen stays stale or shows someone else's data.
---

# DartWay — realtime (`dartway-realtime`)

A screen follows the server by watching a request that declares channels; a command publishes what it
changed; every client watching a request on that channel applies it — the author's screens from the
command's response, everyone else's over the socket. No refetch code in the app. **Three halves, and
a missing one fails silently:** the request's channels (`__SHARED_PKG__`), the kind's rule (server),
the publication (every command that changes the object).

## 1. A channel is an audience

Access is checked once, at subscription; nothing re-checks each object. **A channel's audience is
exactly the accounts allowed to read every object published to it** — never one broad channel.

| Who may see the change | Request declares | Server rule |
|---|---|---|
| every signed-in member | `DwLiveChannel(AcmeChannel.news)` | `DwChannelRule.single(kind, canSubscribe: (ctx) async => true)` |
| one group | `DwLiveChannel(AcmeChannel.board, boardId)` (not `const`) | `DwChannelRule.keyed<int>(kind, parseKey: int.parse, canSubscribe: (ctx, boardId) …)` |
| one person — "my …" (`dartway-contract` §2) | `DwLiveChannel.ofCaller(AcmeChannel.invoices)` | `DwChannelRule.ofCaller(kind)` |
| a role | `DwLiveChannel(AcmeChannel.billing)` | `DwChannelRule.single(kind, canSubscribe: (ctx) => ctx.isAdmin)` |

- Every subscription needs a signed-in connection; signed out, the request is fetched and not live.
- A request without channels hears nothing, not even its author's commands — right for a snapshot.
- **The rule is declared by the feature that owns the kind**, `DwServerFeature(channels: [...])`
  (the skeleton's `profile_feature.dart`). A kind without one refuses every subscription
  (`dw.unknownChannel`) and throws on publish; `canSubscribe` is as strict as the strictest request on
  the channel (`dartway-access`). A keyed channel's key is canonical (`7`, not `07`).

## 2. Publish from every change

`ctx.publish(channel, object)` in a command, a job, a route or an auth hook — delivered **after
commit**, never from a rolled-back attempt; from a request handler it throws.

- **One function per data object knows every channel that shows it**, in the owning feature's
  `_publications.dart`, maps the row through the same `_objects` function the handlers use, publishes,
  and answers the object; every command that changes it calls it. Sample: the skeleton's
  `__SERVER_PKG__/lib/src/profile/profile_publications.dart`.
- **Name the account, never "the caller"**: someone's "my" request hears
  `DwLiveChannel.forAccount(kind, theirAccountId)` — the row owner's, not `ctx.accountId`. An unresolved
  `ofCaller` throws on the server. The addresses live in `core/channels.dart` (`AppChannels`).
- A derived object that changed (a counter, a total) is published too, by its owner's function; an
  object embedding the changed one is republished.
- **Deletions** are `ctx.publish(channel, DwDeletedObject.of<CustomerInvoice>(id, ctx.protocol))`.
- **Publish everything that changed; the channel rule sorts it.** A member's command may publish a
  managers-only figure: managers hear it, the member's response never carries it.
- An item some accounts must not get (a blocked author's message): `exceptAccounts: {…}` — never
  filtered on the client, never a channel per member.
- One object published twice to a channel in one call travels once, as it ended.

**Taking access away** — access was checked at subscription, so **every path that removes a right calls
`ctx.revoke(channel, accountId)`** (removing a member, deleting or moving the group, a role taken
away); without it the account keeps hearing until it reconnects. Sign-out and key revocation close their
subscriptions by themselves.

**Hearing without reading** — a "new posts" badge: `dw.listen([channels])`, a stream subscribed while
listened to. Never read a page just to get a subscription; missed publications are not replayed, so the
exact number comes from a request.
A phone's network blip is exactly this window, so whatever a screen shows comes from a watched
request, never from `listen`'s stream.

## 3. What an update does to a request

An arriving object of the request's type gets one `DwUpdateAction` from the request's `onUpdate`; a
`.refetchOnUpdate()` list also re-runs on objects and deletions of other types on its channels, which
never reach its `onUpdate`:

| Request | An object arrives | A deletion arrives |
|---|---|---|
| `DwSingleRequest` | `update` in place | read again → `dw.notFound` |
| `DwMaybeRequest`, `DwListRequest()`, `DwPageRequest(pageSize:)`, `DwWindowRequest` | `matches ? upsert : remove` | `remove` |
| `.updateOnly()` list or page | `update`, never insert | `remove` |
| `DwListRequest.refetchOnUpdate()` | `refetch` | `refetch` |
| `DwTableRequest` | replaced in place when on the page; otherwise the page reads again | the page reads again |

Choose by who knows membership: the client can tell from the object → the default, with `matches`
mirroring the server's filter and `sort` placing inserts; only the server knows → `.updateOnly()`; the
value is derived → `.refetchOnUpdate()`. A table request narrows `matches` to its filter, so a row that
leaves the filter leaves the page. A feed drops an insert that sorts past the loaded pages; a window
inserts live only while it shows the newest rows, and counts the rest as unseen. A special case overrides
`onUpdate`, still pure.

## 4. Test it

Choose cases by `dartway-testing` §4. **Access (class 1)**: the rule over a raw socket —
`server.openLive()`, `authenticate`, `subscribe('invoices:$other')` answers
`DwSubscriptionRefusedMessage`; A's "my" data never reaches B. A revoked right closes the channel —
**on the group's channel, not a caller channel** (which is never revoked). `onUpdate` of each request
is a contract test (class 5).

**Positive delivery is not mandatory**; it answers the §4 gate. When justified, use two real clients:
one commands, the other's `watch(…)`, awaited until `watch.isLive` before the command, sees the change
with `dwWaitUntil`; `DwCountingTransport` proves it came live, not by a re-read. A deletion leaving
the other list is another case at that boundary. Red proof follows §5.
