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
EOF
) > ~/migrate.env
chmod 600 ~/migrate.env
```

Every command below takes `--env-file ~/migrate.env`; `rclone`'s own `env_auth=true` reads the same
`AWS_*` pair, so the connection strings below name no key or secret at all. `~/migrate.env` outlives
this note the same way `<project>_minio_data` does — keep it until the rollback window in step 6
below is over, then delete it with the rest.

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
docker run --rm --network <project>_default --env-file ~/migrate.env \
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

`<project>-storage-migrate` has nothing left to do — the Rollback section below reaches RustFS
through `<project>-storage-1`, the compose-managed container, not this one — so remove it now:

```bash
docker rm -f <project>-storage-migrate
```

**Do not remove `<project>_minio_data` or the MinIO image yet.** The volume is the rollback copy,
not a leftover — the data-volume guard exists precisely so that nothing here is ever forced to
delete it before it passes (`packages/dartway_cli/lib/src/deploy/data_volumes.dart`). Keep it and
`~/migrate.env` (the Rollback section below still needs both) until the project owner has confirmed
a period of good operation on RustFS. Only then:

```bash
cd ~/<project>
rm -f ~/migrate.env
docker volume rm <project>_minio_data
docker rmi quay.io/minio/minio:RELEASE.2025-09-07T16-13-09Z
```

## Rollback

**Everything up to step 5 is reversible by simply not proceeding** — MinIO is still running,
untouched. Once step 5 has started, rollback is no longer "undo the config edit": every upload since
then exists only in RustFS, and getting it back means copying it, not just pointing traffic at the
old stack again.

**Do not run `dartway deploy setup` for this.** The pre-#331 release you are downgrading to (`# CLI
back to the version this project ran before the upgrade`, below) carries an older, cruder ancestor
of the guard this note relies on above: it lists every `<project>_*_data` volume on the server and
refuses outright if any of them is not one the *current* config expects — no missing/stranger
pairing, no exception for "an old volume nothing asks for." Reverting `deploy/config.yaml` to
`storage: minio` makes `<project>_storage_data` exactly that kind of stranger, and that old `deploy
setup` refuses with:

```
Refusing to continue: this server already has the volume(s) <project>_storage_data, and the
rendered configuration uses <project>_postgres_data, <project>_minio_data instead — fresh, empty
data.
Mount the existing volume in deploy/compose.override.yml, or remove it deliberately
(docker volume rm), then run setup again.
```

**Never follow that suggestion.** `<project>_storage_data` is not a leftover by the time anyone
rolls back — it is the only copy of every file uploaded since step 5, and `docker volume rm` on it
is permanent loss of exactly the data this note exists to protect. Use `deploy run` instead: it
renders the compose file and starts the stack the same way `setup` does, but has no data-volume
guard in its own step list at all — a volume it has never heard of is simply not its business.

Rollback, in order:

1. **Freeze writes again**, the same as step 1 — everything written since the switch lives only in
   RustFS, and this copy is a point-in-time snapshot exactly like the first one:
   ```bash
   cd ~/<project>
   docker compose stop server
   ```
2. **Bring the old volume back to life beside the running RustFS**, the same throwaway-container
   pattern step 2 used the other way around — `<project>-minio-1` was itself *removed* by step 5 (see
   the note on `--remove-orphans` in step 6 below), so there is no container left to `docker start`;
   only its volume, `<project>_minio_data`, survives:
   ```bash
   docker run -d --name <project>-minio-rollback --network <project>_default --env-file ~/migrate.env \
     -v <project>_minio_data:/data \
     quay.io/minio/minio:RELEASE.2025-09-07T16-13-09Z server /data
   ```
3. **Copy everything written since the switch back to it** — the reverse of step 3. The source is
   `<project>-storage-1`, the live, compose-managed RustFS container the deployed app has actually
   been writing to since step 5 — not the retired `<project>-storage-migrate`, which has held no
   traffic since the switch:
   ```bash
   for bucket in <prefix>-public <prefix>-private; do
     docker run --rm --network <project>_default --env-file ~/migrate.env rclone/rclone:1.71.1 copy \
       ":s3,provider=Other,env_auth=true,endpoint='http://<project>-storage-1:9000':$bucket" \
       ":s3,provider=Minio,env_auth=true,endpoint='http://<project>-minio-rollback:9000':$bucket" -v
     docker run --rm --network <project>_default --env-file ~/migrate.env rclone/rclone:1.71.1 check \
       ":s3,provider=Other,env_auth=true,endpoint='http://<project>-storage-1:9000':$bucket" \
       ":s3,provider=Minio,env_auth=true,endpoint='http://<project>-minio-rollback:9000':$bucket" \
       --download -v
   done
   ```
   `copy`, never `sync`, in this direction: `sync` deletes from the destination whatever the source
   lacks, and RustFS is not guaranteed to be a superset of what MinIO already held. Read `check` for
   the same `0 differences found` step 3 asked for, now in reverse — this is the one step in the
   whole note where skipping it loses real, already-served files for good.
4. **Retire the throwaway container** — its job is done, and the compose-managed `<project>-minio-1`
   below will own the volume from here on:
   ```bash
   docker rm -f <project>-minio-rollback
   ```
5. **Revert the config, directly on the server checkout.** This is an emergency edit, not a commit —
   keep it out of git for now, so the next routine deploy does not have to know about it:
   ```bash
   cd ~/<project>
   git checkout deploy/config.yaml   # storage: minio again
   # dartway_cli back to the release this project ran before the upgrade
   ```
6. **Start the old stack** with `deploy run`, never `deploy setup`, and `--skip-git-update` so this
   edit survives instead of being reset back to `storage: bundled` by the checkout update `deploy
   run` would otherwise do first:
   ```bash
   dartway deploy run --env staging --skip-git-update
   ```
   This renders a compose file with a `minio` service again and starts it with `docker compose up -d
   --remove-orphans` — the same command every `deploy run` uses. The RustFS-based `storage` container
   step 5 started (`<project>-storage-1`) is no longer declared by this compose file, so
   `--remove-orphans` **removes** it outright, not merely stops it — exactly what happened to
   `<project>-minio-1` itself when step 5 switched forward (an earlier version of this note claimed
   it was "stopped, not deleted", which is wrong: it was removed the moment `deploy run` brought the
   RustFS-based stack up, because compose no longer declared it). `--remove-orphans` only ever removes
   containers, never volumes — `<project>_minio_data` was never touched by any of this, which is the
   only reason step 2 above had anything to restart into. `<project>-minio-1` is now recreated from
   that same volume, holding what it held before the switch plus everything copied back in step 3.
7. **Verify** with the same real-key checks as steps 4 and 6 above, now against MinIO — including
   whatever was uploaded after the original switch, to confirm it survived the round trip.

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
