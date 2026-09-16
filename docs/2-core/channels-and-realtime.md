# How does a change reach every screen that shows it?

Through channels. A request declares the channels its state lives on; a command publishes the objects
it changed to channels; every watched request that declares a channel absorbs what is published to
it, on the caller's device and on everyone else's. Nobody polls, and no screen refreshes by hand.

## Channel kinds and channels

The project declares its kinds as one enum in its shared package
(`example/dartway_example_shared/lib/src/example_channel.dart`):

```dart
enum ExampleChannel with DwChannelKind {
  schedule,
  bookings,
  staffChat,
  // ...
}
```

A kind's wire name is the value's name (`channelName`) and must not contain `:`. A `DwLiveChannel` is
one instance of a kind:

| Channel | Wire name | Used for |
|---|---|---|
| `DwLiveChannel(ExampleChannel.schedule)` | `schedule` | one instance for everyone allowed |
| `DwLiveChannel(ExampleChannel.staffChat, 7)` | `staffChat:7` | one instance per key, an `int` or a `String` |
| `DwLiveChannel.ofCaller(ExampleChannel.bookings)` | none until resolved | declared by a "my …" request |
| `DwLiveChannel.forAccount(ExampleChannel.bookings, 7)` | `bookings:7` | what the server publishes to for account 7 |

**"My" requests carry no account id (D-037).** `ListMyBookings` declares
`DwLiveChannel.ofCaller(ExampleChannel.bookings)`; the client resolves it for whoever is signed in
when it subscribes, and a handler publishing a booking names whose it is with
`DwLiveChannel.forAccount(kind, accountId)`. Publishing an unresolved `ofCaller` channel on the server
throws `ArgumentError`: there it could only mean "the caller", and a staff member marking someone
else's visit is exactly where that reading goes wrong.

## Who may subscribe

The server declares one rule per kind and passes the list to `DwAppServer(channels: …)`
(`example/dartway_example_server/lib/src/example_channels.dart`):

```dart
// ExampleChannels
static final rules = <DwChannelRule>[
  DwChannelRule.single(ExampleChannel.schedule, canSubscribe: _anyMember),
  DwChannelRule.keyed<int>(
    ExampleChannel.staffChat,
    parseKey: int.parse,
    canSubscribe: (ctx, channelId) => ctx.isStaff,
  ),
  // "My" channels: a member subscribes to their own account's only.
  DwChannelRule.ofCaller(ExampleChannel.bookings),
  DwChannelRule.single(
    ExampleChannel.admin,
    canSubscribe: (ctx) => ctx.isAdmin,
  ),
];
```

- `single` — a kind with one instance; `canSubscribe(ctx)`.
- `keyed` — `parseKey` turns the wire text into the key and throws on malformed input; the name must
  be canonical (`staffChat:7`, not `staffChat:07`), otherwise `dw.invalid` on field `channel`.
- `ofCaller` — a connection may subscribe to its own account's key only; another key is
  `dw.forbidden`.
- A kind without a rule refuses every subscription with `dw.unknownChannel`, which the client reports
  as a wiring mistake. Two rules for one kind fail the server's startup.
- A rule that throws is an incident, alerted, and answered as a failed subscription — not a refusal.

**Every subscription requires sign-in (D-020).** An anonymous connection is answered "not
authenticated", and the client does not open the socket at all while signed out. Anonymous screens
read; they do not follow.

**Access is checked once, at subscription.** The server does not check each publication against each
subscriber, so **everything published to a channel must be readable by every subscriber of it**. That
is why `ClubSession` on the schedule carries nothing personal — whether *you* booked it lives on your
own bookings channel. Publish a member's booking to `schedule` and every member's device receives it.

## Publishing

A command publishes with `ctx.publish(channel, object)`; the object is a data object of the protocol
or a deletion notice (`example/dartway_example_server/lib/src/handlers/schedule_handlers.dart`):

```dart
await ctx.db.clubSessions.delete(command.sessionId);
ctx.publish(
  scheduleChannel,
  DwDeletedObject.of<ClubSession>(command.sessionId, ctx.protocol),
);
for (final booking in affected) {
  ctx.publish(
    ExampleChannels.bookingsOf(clients[booking.clientProfileId]!),
    DwDeletedObject.of<SessionBooking>(booking.id!, ctx.protocol),
  );
}
```

- **Publications happen after commit.** Made inside a transaction they are held and delivered only
  when it commits; a rolled-back command publishes nothing, so no screen shows a change the database
  does not have. Outside a transaction they go when the call ends.
- **A request cannot publish.** `ctx.publish` in a request throws `StateError`: a read has no side
  effects. Jobs and routes may publish.
- **Deletion is `DwDeletedObject.of<T>(id, ctx.protocol)`** — the type and the id, removed from every
  request of that type on the channel.
- The same object may go to several channels; each reaches its own requests
  (`ChangeRole` publishes a profile to the admin table and to the member's own profile channel).

## Revoking

Because access is checked once, a command that takes access away closes what it opened
(`example/dartway_example_server/lib/src/handlers/admin_handlers.dart`):

```dart
if (row.role == UserRole.admin && command.role != UserRole.admin) {
  ctx.revoke(adminChannel, account);
}
```

`ctx.revoke(channel, accountId)` takes effect after commit: that account's connections lose the
subscription and receive `closed`. The client keeps the data on screen, stops showing it as live and
reads the request again, so the screen shows what the new access allows — data or a refusal. A
closed channel is not resubscribed for the same account. A connection whose account changes (sign-in,
sign-out, a revoked key) loses every subscription, since each was checked for the previous account.

## Two ways to the client

A command's publications reach its own caller **in the response** and everyone else **over the
socket**, and every object travels with its channel (D-036):

```json
{"status":"ok","result":{…},"updates":{"schedule":{"ClubSession":[{…}]},"bookings:7":{"SessionBooking":[{…}]}}}
```

The channel is the only fact that says whose data an object is. An admin changing a member's role gets
that member's `UserProfile` back; applied by type alone it would land in the admin's own "my profile".
So the client applies an object only to requests that declare the channel it came on. Within one
channel an object travels once, as it ended: updated twice, it travels once; updated then deleted, it
travels as its deletion.

**The response carries what the caller may read, socket or not** (D-053). For each channel the
command published to, the server asks that channel's rule — the same `canSubscribe` a subscription
asks — for the caller. Allowed: the channel's updates travel in the response. Not allowed: only
subscribers hear them. A command may publish where its caller may not read — a newcomer's sign-in
announces them on a staff-only channel — and that never reaches the newcomer; a member's booking
reaches the member's own lists from the response even with no socket at all. An anonymous caller's
response carries none: rules run for accounts (D-020).

The client names its socket in `Dw-Live-Connection` (D-026) when the socket is authenticated as the
same token. That connection is left out of the socket broadcast of this command, so nothing reaches
one client twice, and the channels it subscribes to go in the response without asking their rules
again — access was checked when it subscribed. The caller's other devices get the socket message. A
connection named by a call of another account is ignored.

Rule checks share one context per response, so a rule reading the caller's profile through
`ctx.memo` reads it once. A rule that throws is reported and keeps its channel out of the response.
A channel the command revoked for its caller stays out, and a command that revoked the caller's own
key (sign-out) carries none.

**So a rule must be honest for any caller**, not only for whoever opens the screen that subscribes: it
answers "may this account read this channel". A rule that allows everyone because "only the admin
screen subscribes here" hands the admin channel to every caller whose command publishes to it.

A command may publish only to a channel whose kind has a rule, in a form a subscriber could name (a
keyed kind with its key, a single kind without): anything else throws `ArgumentError` at `ctx.publish`.

The response's updates are applied before the result is handed on, so the caller's screen never
changes ahead of the updates that came with it. A replayed command answer carries none
([commands-and-idempotency.md](commands-and-idempotency.md)).

## On the client

- **Subscriptions are reference-counted.** One subscription per wire channel however many requests
  declare it; `unsub` goes out when the last of them is released.
- **The socket opens on demand** — while an account is signed in and something watched declares
  channels — and closes a few seconds after neither holds.
- **A first load waits for its subscriptions**, briefly, so nothing published between the read and the
  subscription is lost; data read before its channel became active is read again once it is.
- **On a lost connection** every subscription returns to idle, `dw.liveStatus` becomes
  `disconnected`, and the client reconnects with growing backoff (reset after a connection that
  authenticated). On reconnect it authenticates, subscribes again to what is still watched — a refused
  subscription is retried, a closed one stays closed — and **every request on a resubscribed channel
  reads itself again**: updates published while the socket was down are not replayed, the read covers
  them. Calls waiting out a retry go at once when the socket says hello.
- A close for incompatibility is terminal (see [wire-and-versions.md](wire-and-versions.md)); a close
  caused by what the client sent is reported and backed off.

## One process

Connections, subscriptions and fan-out live in the memory of one server process (D-014). A
publication made by another process — a second server instance behind a balancer, a script writing
to the database — reaches no socket of this one, and nothing relays it. Run one server process; a
change made outside it is seen by clients when they next read.

Wire messages of the socket are listed in [wire-and-versions.md](wire-and-versions.md).
