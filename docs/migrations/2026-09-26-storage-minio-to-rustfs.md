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

**This note replaces the bucket contents' storage engine underneath a live deployment, for good —
there is no rollback.** The move to RustFS is one-time; this project does not go back to MinIO
(owner decision, 2026-09-26). **Read the whole thing before running any command in it.** Steps 1
through 4 touch nothing that is already live — MinIO keeps running, untouched, until step 5 — so
stopping at any point before the switch simply leaves it as it was. Step 5 is the one-way step.

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

Build one throwaway env file from them, used by every container below in place of `-e KEY='value'`
on the command line — a command's flags end up in `docker inspect` and in shell history, an
`--env-file` does not:

```bash
cd ~/<project>
( set -a; . ./.env; set +a
  cat <<EOF
RUSTFS_ACCESS_KEY=$DW_STORAGE_ACCESS_KEY
RUSTFS_SECRET_KEY=$DW_STORAGE_SECRET_KEY
AWS_ACCESS_KEY_ID=$DW_STORAGE_ACCESS_KEY
AWS_SECRET_ACCESS_KEY=$DW_STORAGE_SECRET_KEY
AWS_DEFAULT_REGION=us-east-1
AWS_REQUEST_CHECKSUM_CALCULATION=when_required
AWS_RESPONSE_CHECKSUM_VALIDATION=when_required
EOF
) > ~/migrate.env
chmod 600 ~/migrate.env
```

Every command below takes `--env-file ~/migrate.env`; `rclone`'s own `env_auth=true` reads the same
`AWS_*` pair, so the connection strings below name no key or secret at all. The last two variables
are not optional against a plain-HTTP, non-AWS endpoint: `rclone/rclone:1.71.1`'s S3 backend defaults
to computing an upload checksum in a trailer, which its own SDK refuses to send over anything but
TLS — every `PutObject` below fails with `compute input header checksum failed, unseekable stream is
not supported without TLS and trailing checksum` without them (found by actually running this
rehearsal; see the real transcript in step 3). `~/migrate.env` is only needed through step 4 below —
delete it once the switch in step 5 is verified, alongside the rest of the cleanup in step 6.

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

**From here until step 5 switches for real, nobody runs `dartway deploy` (any subcommand) or
`docker compose up` on this host by hand.** The guard step 5 relies on only checks that
`<project>_storage_data` exists *by name* — nothing about what is inside it. A routine deploy
someone else kicks off in the middle of this window would render the stack fresh, notice the volume
missing, create it empty, and satisfy that same check perfectly; the guard would still pass, on
nothing.

Create the **exact volume name Compose will look for once the config switches** —
`<project>_storage_data` — so that nothing more has to move once verification passes: this container
*is* the future `storage` service, started by hand once, ahead of the config change.

```bash
docker volume create <project>_storage_data
docker run -d --name <project>-storage-migrate \
  --network <project>_default \
  --env-file ~/migrate.env \
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
  docker run --rm --network <project>_default --env-file ~/migrate.env \
    amazon/aws-cli:2.31.13 --endpoint-url http://<project>-storage-migrate:9000 \
    s3 mb "s3://$bucket"
done
```

## 3. Copy both buckets, then prove it byte for byte

`rclone/rclone`, pinned to an exact tag, on the same network, reaching both storages by container
name — the deployed MinIO publishes no host port, so this is the only way in. The `endpoint=` value
is quoted inside the connection string: an unquoted `http://` breaks rclone's own `key=value,...`
parsing.

```bash
for bucket in <prefix>-public <prefix>-private; do
  docker run --rm --network <project>_default --env-file ~/migrate.env rclone/rclone:1.71.1 sync \
    ":s3,provider=Minio,env_auth=true,endpoint='http://<project>-minio-1:9000':$bucket" \
    ":s3,provider=Other,env_auth=true,endpoint='http://<project>-storage-migrate:9000':$bucket" \
    --checksum -v
done
```

**Proof, not a hope — `rclone check --download` both, separately from the copy.** Not `--checksum`:
the run below, from this note's own round 2, hit a MinIO/RustFS pair where neither side offered a
hash rclone recognised, so `--checksum` had nothing to compare and reported "could not be checked"
for every object instead of a verdict —

```
2026/09/26 08:15:13 INFO  : avatar/real-user-42.png: Copied (new)
2026/09/26 08:15:13 INFO  : _dartway/visibility-probe: Copied (new)
Transferred:            2 / 2, 100%
2026/09/26 08:15:21 NOTICE: S3 bucket shop-public: 0 differences found
2026/09/26 08:15:21 NOTICE: S3 bucket shop-public: 2 hashes could not be checked
2026/09/26 08:15:21 NOTICE: S3 bucket shop-public: 2 matching files
```

— a `0 differences found` that means nothing when every file behind it says "could not be checked".
`--download` has no such escape hatch: it reads every object on both sides and compares the bytes
directly, so it always reaches a real verdict, at the cost of a full read of everything once.

```bash
for bucket in <prefix>-public <prefix>-private; do
  docker run --rm --network <project>_default --env-file ~/migrate.env rclone/rclone:1.71.1 check \
    ":s3,provider=Minio,env_auth=true,endpoint='http://<project>-minio-1:9000':$bucket" \
    ":s3,provider=Other,env_auth=true,endpoint='http://<project>-storage-migrate:9000':$bucket" \
    --download -v
done
```

Read for **`0 differences found`** with no "could not be checked" line at all. `rclone size` of each
remote, before and after, is a second, independent object count worth taking on both sides:

```bash
for bucket in <prefix>-public <prefix>-private; do
  docker run --rm --network <project>_default --env-file ~/migrate.env rclone/rclone:1.71.1 size \
    ":s3,provider=Minio,env_auth=true,endpoint='http://<project>-minio-1:9000':$bucket"
  docker run --rm --network <project>_default --env-file ~/migrate.env rclone/rclone:1.71.1 size \
    ":s3,provider=Other,env_auth=true,endpoint='http://<project>-storage-migrate:9000':$bucket"
done
```

Run for real against exactly these commands (three objects across both buckets — a public upload, the
framework's probe, and a private document — copied from a real MinIO to a real temporary RustFS, both
containers on a compose-like network, `~/migrate.env` from the section above providing the checksum
settings the sync above needs):

```
INFO  : _dartway/visibility-probe: Copied (new)
INFO  : avatar/real-user-42.png: Copied (new)
Transferred:            2 / 2, 100%
INFO  : docs/order-9001.pdf: Copied (new)
Transferred:            1 / 1, 100%

NOTICE: S3 bucket shop-public: 0 differences found
NOTICE: S3 bucket shop-public: 2 matching files
NOTICE: S3 bucket shop-private: 0 differences found
NOTICE: S3 bucket shop-private: 1 matching files

shop-public  — MinIO:  Total objects: 2, Total size: 56 B
shop-public  — RustFS: Total objects: 2, Total size: 56 B
shop-private — MinIO:  Total objects: 1, Total size: 42 B
shop-private — RustFS: Total objects: 1, Total size: 42 B
```

No "could not be checked" anywhere — `--download` reached a real verdict on every object, and `size`
agrees exactly on both sides, for both buckets.

## 4. Verify real data, not only the probes

The probe object (`_dartway/visibility-probe`) proves anonymous read and write reached the new
storage at all — it says nothing about whether *your* files came across intact. Pick a handful of
real keys and read them back:

```bash
docker run --rm --network <project>_default --env-file ~/migrate.env \
  amazon/aws-cli:2.31.13 --endpoint-url http://<project>-storage-migrate:9000 \
  s3 cp "s3://<prefix>-public/<a real public key>" -

docker run --rm --network <project>_default --env-file ~/migrate.env \
  amazon/aws-cli:2.31.13 --endpoint-url http://<project>-storage-migrate:9000 \
  s3 cp "s3://<prefix>-private/<a real private key>" -
```

Both signed, on purpose, even the public one: this container has never had a bucket policy applied to
it — that is `storage-init`'s job, and `storage-init` does not run until step 5 starts the real stack
for real. An anonymous `curl` against the public key here would get `403`, not the `200` you might
expect, and that is not a bug to chase — it would be testing something this step was never meant to
prove. What this step proves is that the *bytes* survived the copy; step 6, after the switch, is
where anonymous public access gets its real test, against the policy `storage-init` actually applies.

Confirmed for real while writing this note: both keys read back byte for byte through the storage's
own credentials.

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
dartway deploy setup --env staging   # re-renders the stack; the data-volume guard passes because a
                                      # volume named <project>_storage_data already exists on the
                                      # server. That is an existence check, not a content one — it
                                      # says nothing about what is inside it. What vouches for the
                                      # content is step 3's copy and its `rclone check --download`,
                                      # already done by the time this runs.
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

That proves the storage domain, its CORS rule and its public policy — not that the *application*
can still reach a private file: the server has been stopped since step 1, and this is its first
request since. Open one real private file through the app itself — whatever screen already shows
one, an avatar, a document, an order attachment — and confirm it loads. That request is the one
this note has not exercised anywhere above: `ctx.files` asks the running server for a presigned
URL, and only that signed URL reaches nginx on `storage_domain`. It is the check your users would
notice first if anything here were wrong.

`<project>-storage-migrate` and `~/migrate.env` have nothing left to do — remove them:

```bash
docker rm -f <project>-storage-migrate
rm -f ~/migrate.env
```

**Do not remove `<project>_minio_data` or the MinIO image until the project owner has confirmed the
files are intact after the switch.** There is no rollback to it — the move to RustFS is one-time —
but until that confirmation, it is the only other copy of everything this note just moved. Once
confirmed:

```bash
docker volume rm <project>_minio_data
docker rmi quay.io/minio/minio:RELEASE.2025-09-07T16-13-09Z
```

## The local `docker-compose.yaml`

A project's own `server/docker-compose.yaml` for development is not touched by anything above —
nothing regenerates it. By hand: rename its `minio` service to `storage` and its environment from
`MINIO_ROOT_USER`/`MINIO_ROOT_PASSWORD` to `RUSTFS_ACCESS_KEY`/`RUSTFS_SECRET_KEY`, and delete its
`minio_init` service entirely — bucket creation is no longer a separate init container; the server
provisions both buckets itself on start wherever `DW_STORAGE_PROVISION: true` is set
(`deploy/config.yaml` > `local`), the same shape `template/dartway_starter_server/docker-compose.yaml`
now has. Left undone, `dartway check` names it (`devComposeDrifted`, a warning) instead of silently
finding nothing to compare.

## How to check

`dartway deploy check --env staging`: `images-resolve` confirms `rustfs/rustfs:1.0.0` and
`amazon/aws-cli:2.31.13` resolve from Docker Hub; the outside checks confirm the deployed hosts
answer as before (public `GET` 200, private `GET` 403, both listings 403, the CORS preflight
admitting the app origin) — now answered by RustFS instead of MinIO, on the data this note copied.
