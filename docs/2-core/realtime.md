# Realtime between users

A save returns the updated models to **whoever saved them**. That is why a list refreshes itself for
the person who edited it and stays stale for everyone else — and why "one user changes it, the others
see it" is a decision you make per model rather than something that silently happens to all of them.

That decision is one line of configuration.

## Broadcasting from a config

```dart
final newsPostCrudConfig = DwCrudConfig<NewsPost>(
  table: NewsPost.t,
  getListConfig: DwGetModelListConfig(accessFilter: (session) async => null),
  saveConfig: DwSaveConfig<NewsPost>(
    allowSave: (session, ctx) async => await session.isStaffMember,
    broadcastTo: (session, ctx) => [DwCoreConst.publicUpdatesChannel],
  ),
  deleteConfig: DwDeleteConfig<NewsPost>(
    allowDelete: (session, model) => session.isStaffMember,
    broadcastTo: (session, model) => [DwCoreConst.publicUpdatesChannel],
  ),
);
```

Nothing is written on the Flutter side. Every model arriving on a subscribed channel is routed **by
type** into any `dw.repo.modelList<T>()` the app holds, so a list already on screen redraws itself.
An app created by `dartway create` subscribes to `DwCoreConst.publicUpdatesChannel` at its root, which
is what makes the config above sufficient on its own.

**Delete alongside save, or not at all.** A model that broadcasts its saves and not its deletions
leaves every other client showing a row that no longer exists — noticed later, by someone else, in a
state you cannot reproduce.

## A channel is an audience, and `accessFilter` is not in it

`accessFilter` governs reading through the API. It has no say over what travels on a channel: every
subscriber receives what you post, including users who could never have fetched that row themselves.
Who is *in* the audience is a separate declaration — see [Declaring a channel](#declaring-a-channel)
below — but nothing filters the payload once it is in flight.

So `broadcastTo` is `null` by default, and the question to answer before setting it to the public
channel is not "should this be live?" but:

> **Is any user of this app entitled to read this row?**

- **Yes** — a catalogue item, a price, remaining capacity, a published announcement — the public
  channel is right.
- **No** — orders, messages, profiles — narrow the channel to the audience that may see it
  (`'chat:${ctx.currentModel.chatId}'`), or notify the single owner:

```dart
session.sendUpdatesToUser(order.clientProfileId, updatedModels: [order]);
```

## When the private row and the public fact differ

`broadcastTo` sends **everything the operation touched**, the saved row included. A booking is private
while the remaining capacity it changed is public, so broadcasting from the booking's config would
hand every client somebody else's booking.

Choose what travels instead:

```dart
saveConfig: DwSaveConfig<SessionBooking>(
  allowSave: ...,
  afterSaveSideEffects: (session, ctx) async {
    final clubSession = await ClubSession.db.findById(session, ctx.currentModel.clubSessionId);
    // only the public row leaves; the booking stays between its owner and the server
    session.sendUpdates(
      channels: [DwCoreConst.publicUpdatesChannel],
      updatedModels: [clubSession],
    );
  },
),
```

`sendUpdates` takes the channels and the models explicitly. `sendUpdatesToUser` is the shortcut for
the one audience that is always safe — a single known user — and delegates to it.

## Declaring a channel

A channel name reaches the server as a plain string chosen by the client. Nothing else in the system
can tell a real name from a guessed one, and every name worth guessing is guessable by construction —
`userUpdates42` differs from `userUpdates43` by one character. **Authentication is not the answer
here:** a signed-in stranger guesses just as well as an anonymous one.

So a channel is declared, and a channel nobody declared cannot be subscribed to:

```dart
DwCore.init(
  crudConfigurations: [...],
  channelConfigurations: [
    DwChannelConfig.public(prefix: 'catalogue'),
    DwChannelConfig.owner(prefix: 'orders'),        // orders42 — user 42 and nobody else
    DwChannelConfig.guarded(
      prefix: 'chat:',
      allowListen: (session, suffix) async => await session.isChatMember(int.parse(suffix)),
    ),
  ],
);
```

- **`public`** — anyone, signed in or not. One word, and it shows up in review.
- **`owner`** — the suffix is a user profile id, and only that user gets in. The shape behind
  `sendUpdatesToUser`, given a constructor because the hand-written version is the one that forgets
  to compare.
- **`guarded`** — your own check, handed the session and the part of the name after the prefix.
  `allowAnonymous` defaults to `false`, so the predicate is never called without a user unless you
  say otherwise.

The framework declares its own two: `DwCoreConst.publicUpdatesChannel` and the per-user channel behind
`sendUpdatesToUser`.

**A prefix is a prefix.** `DwChannelConfig.public(prefix: 'updates')` also opens `updates_admin`.
Name a public channel in full, and give a parametrised one a separator you would not type by accident
— `chat:`, not `chat`. When two declarations match, the longer prefix decides.

## Subscribing to a narrower channel

The root subscription covers the public channel. A screen that watches a group channel adds its own:

```dart
DwChannelSubscriptionWidget(
  channel: 'chat:$chatId',
  child: messagesList, // an ordinary ref.watch(dw.repo.modelList<ChatMessage>())
)
```

The channel name is built the same way on both sides, and the server refuses it unless a declaration
above covers it. `DwCoreConst.publicUpdatesChannel` exists so the common case has one spelling both
halves import rather than two string literals that drift.

## What is not covered

Broadcasting is delivery, not authorisation, and not persistence: a client that was offline when the
message went out learns about the change when it next reads. Reconnects keep their subscriptions —
`DwSocketService` reopens every requested channel on each connect — but messages sent while the socket
was down are not replayed.
