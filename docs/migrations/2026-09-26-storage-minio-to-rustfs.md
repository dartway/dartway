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
storage, and `dartway deploy check` used to have nothing that caught it earlier.

A project with no `storage:` key, or `storage: external`, is not affected — nothing about an
externally administered storage changed.

## What to change

**1. `deploy/config.yaml`**: rename the value.

```diff
 staging:
   ...
-  storage: minio
+  storage: bundled
   storage_domain: files.example.com
```

`dartway deploy check --env <environment> --local` fails with "storage" is bundled or external"
until this is done.

**2. Re-render the stack.** `dartway deploy setup --env <environment>` writes the new
`docker-compose.yml`: the services are renamed `storage` and `storage-init` (were `minio` and
`minio-init`), the image is `rustfs/rustfs:1.0.0`, and the data volume is renamed
`<project>_storage_data` (was `<project>_minio_data`). `setup`'s own data-volume guard refuses to
proceed while the server still carries the old volume under its old name — that guard is what stops
this from silently creating an empty bucket pair beside the real one; it is not a defect to work
around.

**3. Move the bucket contents once, by hand, before `setup` runs on that server.** There is no
automated migration and none is planned (zero-major: the framework does not carry code that
recognises and heals another vendor's on-disk state). On the server that is still running MinIO,
with its image still cached:

```bash
# a. Bring up RustFS alongside the still-running MinIO container, on a scratch port and volume —
#    do not touch the MinIO container or its volume yet.
docker run -d --name storage-rustfs -p 127.0.0.1:19000:9000 \
  -e RUSTFS_ACCESS_KEY=migrate -e RUSTFS_SECRET_KEY=migrate-secret \
  -v <project>_storage_data:/data \
  rustfs/rustfs:1.0.0 /data

# b. Create the two buckets on it (same names MinIO already used: <prefix>-public, <prefix>-private).
docker run --rm --network container:storage-rustfs \
  -e AWS_ACCESS_KEY_ID=migrate -e AWS_SECRET_ACCESS_KEY=migrate-secret -e AWS_DEFAULT_REGION=us-east-1 \
  amazon/aws-cli:2.31.13 --endpoint-url http://127.0.0.1:9000 s3 mb s3://<prefix>-public
# ...and s3://<prefix>-private the same way.

# c. Copy both buckets, with checksums, from the running MinIO to RustFS.
docker run --rm --network host rclone/rclone sync \
  ":s3,provider=Minio,access_key_id=<minio key>,secret_access_key=<minio secret>,endpoint=http://127.0.0.1:<minio port>:<prefix>-public" \
  ":s3,provider=Other,access_key_id=migrate,secret_access_key=migrate-secret,endpoint=http://127.0.0.1:19000:<prefix>-public" \
  --checksum
# ...and <prefix>-private the same way.

# d. Verify object counts agree on both sides before doing anything irreversible.
docker run --rm --network host rclone/rclone size ":s3,...:<prefix>-public"
docker run --rm --network host rclone/rclone size ":s3,...:<prefix>-public"  # the RustFS side

# e. Stop and remove the scratch RustFS container (its volume is the project's real one — keep it),
#    stop the MinIO container, then run `dartway deploy setup --env <environment>` for real: it
#    starts the real `storage` service on that same volume, sees the buckets already there
#    (bucket creation is idempotent — an existing bucket keeps its objects), and sets their access
#    and CORS again.
docker rm -f storage-rustfs
docker stop dw10-minio   # or whatever the deployed MinIO container is named

# f. Only after `dartway deploy run` has verified the deployment from outside (public GET 200,
#    private GET 403, listing 403 on both buckets — the same checks `dartway deploy check` and
#    `deploy run` already make): remove the old MinIO container and image. Never remove its volume
#    before step (d) has confirmed the copy — it is the only copy of the objects until then.
```

## How to check

`dartway deploy check --env <environment>`: the renamed `stack-names` check reports the same bucket
names as before (they do not change, only the service and volume that hold them do); the new
`images-resolve` check confirms `rustfs/rustfs:1.0.0` and `amazon/aws-cli:2.31.13` resolve from
Docker Hub. `dartway deploy run --env <environment>` ends with the same outside verification as
before — public GET 200, private GET 403, both listings 403, CORS preflight admitting the app
origin — now answered by RustFS instead of MinIO.
