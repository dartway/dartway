---
title: The deploy that crosses the session key migration cannot roll back to an older image
affects:
  dartway_core_server: "0.21.0-dev.17"
---

## Who is affected

A deployed project whose framework pin is before dartway/dartway@d1ec9d9f (#509) — every project
on `dartway_core_server` 0.21.0-dev.16 or older, and one on 0.21.0-dev.17 pinned to an earlier
commit. Its next deploy applies the framework migration `20261009_000003_dw_auth_key_last_used`,
which drops `NOT NULL` and the default on `dw_auth_key.last_used_at` and writes `NULL` into keys
that were never used. An image built before that migration inserts a key without the column and
reads it back as non-null, so it fails against the migrated schema.

**Deploy across it with a fresh database backup; if that deploy fails, restore the backup, not the
previous image.** Rolling back to the previous image alone leaves it running on a schema it cannot
read.

A project already deployed on d1ec9d9f or later has crossed it: record this note as not applicable.

## What to change

No code. Before the first deploy that crosses the migration, on each environment:

1. Take a database backup right before the deploy, and confirm it restores.
2. Deploy.
3. If the deploy fails, restore the backup, not the previous image: bring the database back from
   that backup first, and only then run the previous image on it.

## How to check

After the deploy,
`SELECT state FROM dw_migrations WHERE namespace = 'dw' AND id = '20261009_000003_dw_auth_key_last_used'`
returns the row, and a key issued by a new sign-in has `last_used_at` `NULL` until its first call.
