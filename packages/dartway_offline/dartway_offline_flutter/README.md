# dartway_offline_flutter

The app half of DartWay offline — `dw.plugins.offline`.

An app that has to work without a network needs more than a cache. It needs to know which content
this user is still allowed to hold and until when, to survive the clock being wound back, to finish
a half-downloaded file rather than start it again, to let a write happen with no connection and
replay it later exactly once, and to never hand one account's data to the next one signing in on the
same device. This package owns that part.

Optional by design: the core does not depend on it, and an app that never asks for offline carries
none of it.

## Wiring

```dart
dw = DwCore<Client, UserProfile>(
  // ...
  plugins: [DwOfflinePlugin(config: offlineConfig)],
);
```

That one line is the whole integration. Feature code is untouched — a write stays
`dw.repo.saveModel(...)`, a read stays `ref.watch(dw.repo.modelList<X>())` — because the plugin is
the local store `dw.repo` reads and writes through, and the repository finds it on the core rather
than being told about it.

Then say which reads are worth keeping, one query at a time:

```dart
dw.repo.modelList<Lesson>(
  customConfig: DwModelListStateConfig<Lesson>(
    readStrategy: DwRepoReadStrategy.networkFirstWithSnapshot,
  ),
);
```

Writes work the other way round: which ones are queued is decided inside the store, per operation
and model, not at the call site. The two are not one paired switch — a list kept for reading says
nothing about whether saving that model is queued.

## The family

| Package | Half |
|---|---|
| `dartway_offline_shared` | The wire contract: the manifest signing frame and the repository content digest |
| `dartway_offline_server` | Signing manifests, on the application's server |
| `dartway_offline_flutter` | This one: the runtime on the device |

## What it carries

- **Signed package manifests.** The server signs what a user may hold and until when; the device
  verifies the signature against a pinned key and refuses anything it cannot verify.
- **Trusted time.** Access that expires cannot be extended by changing the device clock.
- **Durable downloads.** Resumed across restarts, verified by hash, with disk space reserved before
  a byte is written.
- **Repository snapshots.** Reads that opted in are served from the device when the network is
  gone, and never across a change of user.
- **An outbox.** A write that failed on the connection is queued and replayed, once, on reconnect.
- **Scoped storage.** Everything belongs to a user scope, and signing out purges it.

## Opening downloaded assets

The runtime only returns files that belong to an active manifest whose access lease is readable.
Use the signed download URL when that URL is also stored in the application model:

```dart
final mediaHandle = await offlineClient.openDownloadedMedia(
  userScopeId: userScopeId,
  downloadUrl: modelDownloadUrl,
);
```

If the application stores a source URL while the manifest downloads a processed or transcoded
file from another URL, give the manifest an application-defined stable `assetId` and use it for
lookup instead:

```dart
final mediaHandle = await offlineClient.openDownloadedAsset(
  userScopeId: userScopeId,
  assetId: sourceAssetId,
);
```

Both lookups enforce the same scope, active-package, lease, ready-file and reader-pin checks. The
identifier changes how the candidate file is found; it does not bypass manifest verification or
access control.

Platform support is Android and iOS. Elsewhere the plugin reports `disabled` and the app runs
online-only, unchanged.
