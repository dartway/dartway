# dartway_starter_server

The server, on `dartway_core_server`. How to run, seed and test it:
`../README.md`.

- `bin/server.dart` — starts the server; configured by the environment alone
  (every variable is listed there)
- `bin/migrate.dart` — `apply | rollback | status | create <name> | check | rehash`
- `bin/seed_dev.dart` — development accounts, once
- `lib/dartway_starter_server.dart` — the server: protocol, schema, auth, files
  and the features
- `lib/src/core/` — the server-wide wiring:
  - `auth.dart` — sign-in: identifier rule, code delivery, the profile a new
    account starts with, the consent a sign-up needs
  - `bootstrap.dart` — the first administrator (`DW_ADMIN_IDENTIFIER`)
  - `call_context.dart` — the caller's profile and the access rules
  - `channels.dart` — the channels handlers publish to
  - `files.dart` — upload rules and the storage configuration
- `lib/src/<feature>/` — one folder per area (`profile/`, `admin/`,
  `settings/`): its `DwServerFeature` in `<feature>_feature.dart` (handlers,
  who may listen to its channels, jobs), its row classes (`…Row`, generated
  tables in `*.dw.dart`), one handler per request and command with its access
  rule, rows → data objects, and what a change is published to
- `lib/src/migrations/` — migrations, written by `bin/migrate.dart create`
- `test/` — acceptance on real clients, a real server, Postgres and RustFS

## File storage

Uploads go from the app straight to an S3-compatible storage in two buckets: a
**public** one, whose objects anyone reads by URL (the avatar), and a
**private** one, read only through short presigned links. A rule's visibility
picks the bucket; a new purpose is a new rule in `lib/src/core/files.dart`.

| Variable | Default |
|---|---|
| `DW_STORAGE_ENDPOINT`, `DW_STORAGE_ACCESS_KEY`, `DW_STORAGE_SECRET_KEY` | required together; without the endpoint there are no uploads |
| `DW_STORAGE_PUBLIC_BUCKET` | `dartway-starter-public` |
| `DW_STORAGE_PRIVATE_BUCKET` | `dartway-starter-private` |
| `DW_STORAGE_PUBLIC_BASE_URL` | `<DW_STORAGE_ENDPOINT>/<public bucket>` (path style) |
| `DW_STORAGE_REGION` · `DW_STORAGE_PATH_STYLE` | `us-east-1` · `true` |
| `DW_STORAGE_VERIFY_BUCKETS` | `true` |
| `DW_STORAGE_PROVISION` | off |

As it starts, the server checks that the public bucket reads anonymously and
the private one does not, and that neither lists its keys; anything else stops
the start with the reason. `DW_STORAGE_PROVISION=true` creates both buckets and
sets their access first — only on a storage the project owns wholly.
