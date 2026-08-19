# What happens to reads and writes when the network is gone?

By default: they fail, loudly and immediately. `dw.repo` is network-only, every read reaches the
backend and every write waits for it. For most apps that is the right answer — a spinner and a retry
beat a stale screen.

When it is not the right answer, `dw.repo` can keep a **local copy**. What that means is deliberately
split in two: the core defines what a local store must guarantee, and a store outside the core does
the keeping. The core never learns what SQLite is, and an app that keeps nothing carries none of it.

## The two halves of the contract

| Contract | What a store implementing it does |
|---|---|
| `DwRepoLocalReads` | Keeps repository responses and serves them when the connection is down |
| `DwRepoLocalWrites` | Queues writes that failed on the connection and replays them later |

Both are optional and independent. A store may implement one and not the other.

The ready-made implementation is [`dartway_offline_flutter`](offline.md), which keeps everything in
SQLite along with downloaded assets, signed access leases and trusted time. Writing your own is a
reasonable thing to do — the contract is small on purpose.

## It is declared with the core, not assigned to it

```dart
dw = DwCore<Client, UserProfile>(
  config: ...,
  client: ...,
  dwAlerts: ...,
  getUserId: (user) => user?.id,
  plugins: [DwOfflinePlugin(config: offlineConfig)],
);
```

That is the entire integration. There is no `dw.repo.localWrites = ...`, and its absence is the
point rather than an omission: a store assigned after startup outlives the core it was attached to.
Recreate the core — which tests do, and which some sign-in flows do — and the old store is still
there, still answering, still accepting mutations. Nothing fails. The writes simply go somewhere
that no longer belongs to anybody. Declaring the store on the core makes that state unreachable.

Read it back through `dw.repo.localReads` / `dw.repo.localWrites` when you need to know whether an
app build has one at all.

## Feature code does not change

```dart
await dw.repo.saveModel(booking.copyWith(status: BookingStatus.cancelled));
```

The same line, with a store or without one. What changes is what happens when it fails: with no
store the connection error surfaces as it always did; with one, a *connection* error — and only a
connection error — queues the mutation and hands you the store's optimistic response, so the screen
moves on and the write leaves the device when the network returns.

Only a connection error. An authorization refusal or a validation failure surfaces untouched,
because replaying it later would mean retrying a request the server already refused. The predicate
that decides this is `isStreamingConnectionError`, and widening it changes where data goes.

## Reads opt in per query; writes opt in inside the store

This asymmetry is real, and reading it as one paired switch is the natural mistake.

A **read** says for itself whether it is worth keeping:

```dart
ref.watch(
  dw.repo.modelList<Lesson>(
    customConfig: DwModelListStateConfig<Lesson>(
      readStrategy: DwRepoReadStrategy.networkFirstWithSnapshot,
    ),
  ),
);
```

The default is `DwRepoReadStrategy.networkOnly`. A registered store caches nothing until a config
asks it to — declaring the store does not quietly turn the app into a cache.

A **write** does not say anything at the call site. The store decides, per operation and model, by
returning a plan or `null` from `prepareSaveMutation` / `prepareDeleteMutation`. A list kept offline
for reading tells you nothing about whether saving that model is queued, and the two are configured
in different places on purpose: what is worth reading offline is a screen's question, what is safe
to replay later is the data's.

## What a store never gets to decide

**Who the data belongs to.** The store resolves a `DwRepoScope` — an opaque namespace string whose
meaning the application owns (a user id, a tenant, whatever the boundary is). The core never derives
a user identity itself. Each scope transition issues a fresh `DwRepoBinding`, revocable and never
persisted, so the same user signing out and back in does not inherit the previous session's rows.

**How a write leaves the device.** The core sends every write by its one path, whether or not it is
kept locally, and hands the store the mutation it sent. That is what makes a queued replay carry the
identity of the first attempt.

## Writing a store: the part the compiler will not check for you

A queued write must not survive the session it was written under. The dangerous window is small and
real: the connection drops, the write goes to the queue, and the user signs out in exactly that
moment.

So the enqueue is not a method you implement — it is a transaction you *open*, and the core writes
what happens inside it:

```dart
@override
Future<R> write<R>(Future<R> Function(DwRepoLocalWriteTx tx) body) =>
    database.transaction(() => body(_MyTx(this)));
```

The core then does the checking and the queuing inside your transaction, in that order, and an
implementation cannot separate them because it never sees them apart.

What a signature still cannot state — that the transaction is real, that `isBindingCurrent` reads
inside it, that a body which throws leaves nothing behind — is stated by tests the core ships:

```dart
import 'package:dartway_serverpod_core_flutter/testing.dart';

void main() {
  dwRepoLocalWritesConformance(
    'MyLocalWrites',
    createFixture: () async => MyFixture(await openStore()),
  );
}
```

Run them against your store. Passing your own tests says it does what you meant; passing these says
it does what `dw.repo` is entitled to assume.

## Where to go next

- [The offline package](https://pub.dev/packages/dartway_offline_flutter) — the ready-made store,
  with assets, signed leases and downloads.
- [Data layer](data-layer.md) — how reads and writes work when nothing is kept.
- [Plugins](plugins.md) — why the store arrives as a plugin and not as a config field.
