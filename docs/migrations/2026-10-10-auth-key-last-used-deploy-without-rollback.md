---
title: The release's stored-file and session-key migrations require a backup before deployment
affects:
  dartway_core_server: "0.21.0"
---

## Who is affected

A deployed project that has not yet applied either of these framework migrations in the
`dartway_core_server` 0.21.0 release:

- `20261009_000002_dw_stored_file_bucket_from_config` (#503, dartway/dartway@cdc2f0c8)
  drops `dw_stored_file.bucket`. An older image still reads and writes that column, so it fails
  against the migrated schema, even if the project currently has no uploaded files.
- `20261009_000003_dw_auth_key_last_used` (#509, dartway/dartway@d1ec9d9f) drops `NOT NULL`
  and the default on `dw_auth_key.last_used_at` and writes `NULL` into keys that were never used.
  An older image inserts a key without the column and reads it back as non-null, so it fails
  against the migrated schema.

**Deploy across it with a fresh database backup; if that deploy fails, restore the backup, not the
previous image.** Both are one-way deployment boundaries: rolling back to the previous image
alone leaves it running on a schema it cannot read or write. Automatic image rollback is not
database recovery, and these migrations' down operations do not recover the original data.

A project whose deployed image supports both migrations, with both already applied in every
environment, has crossed both boundaries: record this note as not applicable.

## What to change

No code. Before the first deploy that crosses either migration, on each environment:

1. Take a database backup right before the deploy, and confirm it restores. Preserve the previous
   image and its configuration together with the backup.
2. For stored files, follow [the bucket preparation note](2026-10-09-stored-file-bucket-from-config.md)
   before deploying: copy objects under their existing keys into the configured bucket for each
   visibility and record the bucket while the column still exists. Keep the old objects and storage
   configuration available for recovery.
3. Deploy.
4. If the deploy fails after either migration has applied, stop the new image and restore the
   database from that backup first. Restore the previous storage configuration and ensure its
   objects are available, then run the previous image. Do not rely on image rollback alone.

## How to check

After the deploy, check both ledger entries:

```sql
SELECT id, state FROM dw_migrations
WHERE namespace = 'dw' AND id IN (
  '20261009_000002_dw_stored_file_bucket_from_config',
  '20261009_000003_dw_auth_key_last_used'
);
```

Both are applied, `dw_stored_file` has no `bucket` column, existing public and private files open,
and a key issued by a new sign-in has `last_used_at` `NULL` until its first call.
