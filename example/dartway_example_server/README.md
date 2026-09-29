# dartway_example_server

The DartWay example server — a fitness club — on `dartway_core_server`. How to
run it, seed it and test it: `../README.md`.

- `lib/src/core/` — the server-wide wiring, fixed names, `App*` classes:
  - `auth.dart` — `AppAuth`: sign-in by phone and code, the profile a new
    account starts with, the tombstone a deleted one leaves
  - `bootstrap.dart` — `AppBootstrap`: the first administrator
  - `call_context.dart` — `AppCallContext` (`ctx.profile`) and `AppAccess`
  - `channels.dart` — `AppChannels`: the channels handlers publish to
  - `files.dart` — `AppFiles`: every upload rule, who reads a private file,
    the storage configuration
  - `push.dart` — `AppPush`: push notification wiring
- `lib/src/<feature>/` — one folder per area (`admin/`, `bookings/`, `chat/`,
  `content/`, `profile/`, `schedule/`), every file `<feature>_*.dart`:
  `_feature` (its `DwServerFeature`: handlers, channel rules, jobs), `_rows`
  (row classes, generated tables in `*.dw.dart`), `_handlers` (one per request
  and command, with its access rule), `_objects` (rows → data objects),
  `_publications` (what a change is published as, and to whom), `_jobs`
- `lib/src/migrations/` — migrations, written by `bin/migrate.dart create`
- `bin/server.dart` · `bin/migrate.dart` · `bin/seed_dev.dart`

## File storage

Uploads go from the app straight to an S3-compatible storage in two buckets:
a **public** one, whose objects anyone reads by URL (the avatar), and a
**private** one, read only through short presigned links after the read rule
(`AppFiles.canRead`). A rule's visibility picks the bucket; a new purpose is a
new rule in `lib/src/core/files.dart` and nothing else.

Without `DW_STORAGE_ENDPOINT` the server runs without uploads. For development,
a local RustFS:

```bash
docker run -d --name club-storage -p 127.0.0.1:9000:9000 \
  -e RUSTFS_ACCESS_KEY=club -e RUSTFS_SECRET_KEY=club-secret \
  rustfs/rustfs:1.0.0 /data

export DW_STORAGE_ENDPOINT=http://127.0.0.1:9000 \
       DW_STORAGE_ACCESS_KEY=club DW_STORAGE_SECRET_KEY=club-secret \
       DW_STORAGE_PROVISION=true
dart run bin/server.dart
```

| Variable | Default |
|---|---|
| `DW_STORAGE_ENDPOINT`, `DW_STORAGE_ACCESS_KEY`, `DW_STORAGE_SECRET_KEY` | required together |
| `DW_STORAGE_PUBLIC_BUCKET` | `club-public` |
| `DW_STORAGE_PRIVATE_BUCKET` | `club-private` |
| `DW_STORAGE_PUBLIC_BASE_URL` | `<DW_STORAGE_ENDPOINT>/<public bucket>` (path style) |
| `DW_STORAGE_REGION` · `DW_STORAGE_PATH_STYLE` | `us-east-1` · `true` |
| `DW_STORAGE_VERIFY_BUCKETS` | `true` |
| `DW_STORAGE_PROVISION` | off |

`DW_STORAGE_PROVISION=true` creates both buckets before the server starts and
sets their access — anonymous `s3:GetObject` on the public one, no policy on
the private one — idempotently. Use it only on a storage the project owns
wholly; `dartway deploy` with `storage: bundled` does the same in
`storage-init`.

As it starts, the server writes a probe object into each bucket and reads it
back without credentials: the public one must answer, the private one must
refuse, and neither may list its keys. Anything else stops the start with the
reason. `DW_STORAGE_VERIFY_BUCKETS=false` skips the check where storage is not
reachable while the server starts (the deploy's bundled storage, checked from
outside afterwards).
