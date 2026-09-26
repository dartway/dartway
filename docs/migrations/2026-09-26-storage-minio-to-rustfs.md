---
title: "The bundled storage is RustFS, not MinIO: storage: minio becomes storage: bundled"
affects:
  dartway_cli: "0.13.0"
---

## Who is affected

Every project whose `deploy/config.yaml` sets `storage: minio` for a deployed environment. MinIO's
community edition stopped publishing images after its last 2025-10-15 release, and every registry
that used to serve them — Docker Hub, quay.io — now answers an anonymous pull with `401`
(dartway/dartway#331): `dartway deploy run` fails on a fresh host at the step that starts the
storage.

A project with no `storage:` key, or `storage: external`, is not affected — nothing about an
externally administered storage changed.

**This note replaces the bucket contents' storage engine underneath a live deployment. Read the
whole thing before running any command in it**, and do it on a server you can reach if something
needs to be undone — every step up to the switch itself is reversible, and this note says exactly
where that stops being true.

## Two names you need before anything else

The commands below use two names that are easy to conflate, because both come from the same
project and neither is `deploy/config.yaml`'s own vocabulary:

- **`<project>`** — the Compose project name, which is the checkout directory's name
  (`DwDeployTarget.projectName`, `packages/dartway_cli/lib/src/deploy/deploy_target.dart:103-110`):
  the last path segment of `repo:` in `deploy/config.yaml`, without `.git`. It is what every volume
  and container Compose manages is prefixed with — `<project>_postgres_data`, `<project>-minio-1` —
  because Compose derives its project name from the directory the compose file sits in, and that
  directory is `/home/<deploy_user>/<project>`. Read it on the server:
  ```bash
  cd ~ && ls                                # the checkout directory *is* <project>
  docker volume ls | grep _postgres_data    # confirms it: <project>_postgres_data
  ```
- **the bucket prefix** — a different name, derived from the *server package*, not the checkout
  (`DwStack.projectPrefix`, `packages/dartway_cli/lib/src/deploy/stack.dart:131-134`): the server
  package's name with `_server` removed, dashes for underscores. It names the buckets
  (`<prefix>-public`, `<prefix>-private`) and can differ from `<project>` — a repository named
  `acme/shop-app` (`<project>` = `shop-app`) can hold a server package `shop_server` (bucket prefix
  `shop`). Read it on the server, inside the checkout:
  ```bash
  ls ~/<project> | grep _server             # e.g. shop_server -> bucket prefix "shop"
  ```

Every command below names both explicitly — substitute your own throughout, including inside the
`endpoint=` values, where they name the bucket, not the host.

## The keys: reused, not regenerated

`DW_STORAGE_ACCESS_KEY` and `DW_STORAGE_SECRET_KEY` already exist in the secret store from when they
were generated for MinIO (`dartway secret init` never replaces an existing value, and the renderer
gives RustFS the very same two secret names — `RUSTFS_ACCESS_KEY`/`RUSTFS_SECRET_KEY` read from
those same store entries). There is nothing to generate: read them once and reuse them for the
temporary RustFS this note stands up.

```bash
grep '^DW_STORAGE_' ~/<project>/.env
# DW_STORAGE_ACCESS_KEY='...'
# DW_STORAGE_SECRET_KEY='...'
```

## 1. Freeze writes

The copy below is a point-in-time snapshot, not live replication, so nothing may write to MinIO
while it runs. Stop the application server only: the database and the proxy stay up, so the site
still serves what it already has, but uploads and anything that touches storage answer an error for
the length of this maintenance window.

```bash
cd ~/<project>
docker compose stop server
```

State the window to whoever needs to know before doing this on a project with real traffic.

## 2. Bring up RustFS on the compose network, with the volume it will keep

Create the **exact volume name Compose will look for once the config switches** —
`<project>_storage_data` — so that nothing more has to move once verification passes: this container
*is* the future `storage` service, started by hand once, ahead of the config change.

```bash
docker volume create <project>_storage_data
docker run -d --name <project>-storage-migrate \
  --network <project>_default \
  -e RUSTFS_ACCESS_KEY='<the DW_STORAGE_ACCESS_KEY read above>' \
  -e RUSTFS_SECRET_KEY='<the DW_STORAGE_SECRET_KEY read above>' \
  -e RUSTFS_CONSOLE_ENABLE=false \
  -v <project>_storage_data:/data \
  rustfs/rustfs:1.0.0 /data
```

`--network <project>_default` is Compose's own network for the project — the same one the deployed
`<project>-minio-1` container already sits on — and neither container needs a host port: everything
below reaches both by container name on that network, exactly as `storage-init` reaches the real
storage once the switch is made.

Create both buckets on it (empty; the copy below fills them):

```bash
for bucket in <prefix>-public <prefix>-private; do
  docker run --rm --network <project>_default \
    -e AWS_ACCESS_KEY_ID='<key>' -e AWS_SECRET_ACCESS_KEY='<secret>' -e AWS_DEFAULT_REGION=us-east-1 \
    amazon/aws-cli:2.31.13 --endpoint-url http://<project>-storage-migrate:9000 \
    s3 mb "s3://$bucket"
done
```

## 3. Copy both buckets, with checksums

`rclone/rclone`, pinned to an exact tag, on the same network, reaching both storages by container
name — the deployed MinIO publishes no host port, so this is the only way in. The `endpoint=` value
is quoted inside the connection string: an unquoted `http://` breaks rclone's own `key=value,...`
parsing.

```bash
for bucket in <prefix>-public <prefix>-private; do
  docker run --rm --network <project>_default rclone/rclone:1.71.1 sync \
    ":s3,provider=Minio,access_key_id='<key>',secret_access_key='<secret>',endpoint='http://<project>-minio-1:9000':$bucket" \
    ":s3,provider=Other,access_key_id='<key>',secret_access_key='<secret>',endpoint='http://<project>-storage-migrate:9000':$bucket" \
    --checksum -v
done
```

**Proof, not a hope — `rclone check` both, separately from the copy:**

```bash
for bucket in <prefix>-public <prefix>-private; do
  docker run --rm --network <project>_default rclone/rclone:1.71.1 check \
    ":s3,provider=Minio,access_key_id='<key>',secret_access_key='<secret>',endpoint='http://<project>-minio-1:9000':$bucket" \
    ":s3,provider=Other,access_key_id='<key>',secret_access_key='<secret>',endpoint='http://<project>-storage-migrate:9000':$bucket" \
    --checksum -v
done
```

Read for **`0 differences found`** and the matched count equal to the object count on both sides
(`rclone size` of each remote, before and after, is a second, independent count worth taking). Some
providers do not expose a hash rclone can compare for every object — `check` then reports "hashes
could not be checked" for those alongside the ones it did compare. `0 differences found` is the
verdict that matters; a hash it could not take is not a hash that disagreed.

This was run for real while writing this note, against a MinIO holding two objects it did not
create in the same session — the framework's own probe, and one file standing in for a real
upload — on exactly the commands above:

```
2026/09/26 08:15:13 INFO  : avatar/real-user-42.png: Copied (new)
2026/09/26 08:15:13 INFO  : _dartway/visibility-probe: Copied (new)
Transferred:            2 / 2, 100%
2026/09/26 08:15:21 NOTICE: S3 bucket shop-public: 0 differences found
2026/09/26 08:15:21 NOTICE: S3 bucket shop-public: 2 hashes could not be checked
2026/09/26 08:15:21 NOTICE: S3 bucket shop-public: 2 matching files
```

(and the same shape for `shop-private`: 2 objects, `0 differences found`.)

## 4. Verify real data, not only the probes

The probe object (`_dartway/visibility-probe`) proves anonymous read and write reached the new
storage at all — it says nothing about whether *your* files came across intact. Pick a handful of
real keys and read them back:

```bash
# a public file, exactly as a browser would — anonymous, through the migration container
docker run --rm --network <project>_default --entrypoint curl amazon/aws-cli:2.31.13 -sS -o /dev/null \
  -w '%{http_code}\n' http://<project>-storage-migrate:9000/<prefix>-public/<a real public key>

# a private file, exactly as the app would — signed. Directly with the storage's own keys is enough
# while the app server is stopped:
docker run --rm --network <project>_default \
  -e AWS_ACCESS_KEY_ID='<key>' -e AWS_SECRET_ACCESS_KEY='<secret>' -e AWS_DEFAULT_REGION=us-east-1 \
  amazon/aws-cli:2.31.13 --endpoint-url http://<project>-storage-migrate:9000 \
  s3 cp "s3://<prefix>-private/<a real private key>" -
```

Confirmed for real while writing this note: a public object read anonymously (`200`, the exact
bytes written), a private one refused anonymously (`403`) and read correctly with the storage's own
keys — the same shape `ctx.files` and a browser see in production.

## 5. Switch

```bash
cd ~/<project>
docker stop <project>-storage-migrate <project>-minio-1
```

Edit `deploy/config.yaml`:

```diff
 staging:
   ...
-  storage: minio
+  storage: bundled
   storage_domain: files.example.com
```

Upgrade the CLI to `dartway_cli` 0.13.0 or later, then:

```bash
dartway deploy setup --env staging   # re-renders the stack; the data-volume guard now passes,
                                      # because <project>_storage_data already exists and holds
                                      # what step 3 copied into it
dartway deploy run   --env staging
```

`storage-init` runs against the volume this note already filled: it finds both buckets present,
re-applies the public policy and CORS (idempotent — nothing it does undoes what is already there),
and the deploy's own outside checks pass against the real data, not an empty pair of buckets.

## 6. After the switch

Repeat the real-key check from step 4 — this time through the deployed domain, over HTTPS, the way
a user actually reaches it:

```bash
curl -o /dev/null -w '%{http_code}\n' https://files.<your-domain>/<prefix>-public/<a real public key>
```

**Do not remove `<project>_minio_data` or the MinIO image yet.** They are the rollback copy, not
leftovers — the data-volume guard exists precisely so that nothing here is ever forced to delete
them before it passes (`packages/dartway_cli/lib/src/deploy/data_volumes.dart`). Keep them until the
project owner has confirmed a period of good operation on RustFS; only then:

```bash
docker volume rm <project>_minio_data
docker rmi quay.io/minio/minio:RELEASE.2025-09-07T16-13-09Z
```

## Rollback

Before the old volume is removed, undoing this is exactly the reverse of step 5 and nothing more —
the MinIO container was stopped, not deleted, and its volume was never touched:

```bash
cd ~/<project>
git checkout deploy/config.yaml   # storage: minio again
# CLI back to the version this project ran before the upgrade
dartway deploy setup --env staging
dartway deploy run   --env staging
```

`<project>_minio_data` still holds everything it held before this note started, because nothing in
it was ever written to.

## The local `docker-compose.yaml`

A project's own `server/docker-compose.yaml` for development is not touched by anything above —
nothing regenerates it. Rename its `minio` service to `storage` and its environment from
`MINIO_ROOT_USER`/`MINIO_ROOT_PASSWORD` to `RUSTFS_ACCESS_KEY`/`RUSTFS_SECRET_KEY` by hand, the same
shape `template/dartway_starter_server/docker-compose.yaml` now has. Left undone, `dartway check`
names it (`devComposeDrifted`, a warning) instead of silently finding nothing to compare.

## How to check

`dartway deploy check --env staging`: `images-resolve` confirms `rustfs/rustfs:1.0.0` and
`amazon/aws-cli:2.31.13` resolve from Docker Hub; the outside checks confirm the deployed hosts
answer as before (public `GET` 200, private `GET` 403, both listings 403, the CORS preflight
admitting the app origin) — now answered by RustFS instead of MinIO, on the data this note copied.
