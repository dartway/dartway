# dartway_starter_server

The server, on `dartway_core_server`. How to run, seed and test it:
`../README.md`.

- `bin/server.dart` — starts the server; configured by the environment alone
  (every variable is listed there)
- `bin/migrate.dart` — `apply | rollback | status | create <name> | check | rehash`
- `bin/seed_dev.dart` — development accounts, once
- `lib/dartway_starter_server.dart` — the server: protocol, schema, auth, the
  features and every upload purpose's rule
- `lib/src/core/` — what every feature imports, and which imports no feature:
  - `channels.dart` — the channels handlers publish to
  - `environment.dart` — the configuration, read once at start
  - `files.dart` — the storage's default bucket names
- `lib/src/<feature>/` — one folder per area (`profile/`, `admin/`,
  `settings/`, `account/`): its `DwServerFeature` in `<feature>_feature.dart`
  (handlers, who may listen to its channels, jobs), its row classes (`…Row`,
  generated tables in `*.dw.dart`), one handler per request and command with
  its access rule, rows → data objects, and what a change is published to.
  `profile/profile_access.dart` is the caller's profile and the access rules,
  `profile/profile_changes.dart` every write of a profile from outside it —
  the profile a new account starts with, the consent a sign-up needs, a role;
  `account/` is sign-in — identifier rule, code delivery (`logic/auth.dart`) —
  and the first administrator (`DW_ADMIN_IDENTIFIER`)
- Features import each other without cycles, and only another's `_rows`,
  `_access`, `_objects`, `_publications` and `_changes`; a feature writes only
  its own rows, and another's through its `_changes`
- `lib/src/migrations/` — migrations, written by `bin/migrate.dart create`
- `test/` — acceptance on real clients, a real server, Postgres and RustFS

## File storage

Uploads go from the app straight to an S3-compatible storage in two buckets: a
**public** one, whose objects anyone reads by URL (the avatar), and a
**private** one, read only through short presigned links. A rule's visibility
picks the bucket; a new purpose is a new rule in the `_access.dart` of the
feature it belongs to, listed in `DartwayStarterServer.uploadRules`.

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
