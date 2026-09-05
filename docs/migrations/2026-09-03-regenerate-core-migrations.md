---
title: "Regenerate the module migration: dw_cloud_file gains a unique index, dw_auth_request an index"
affects:
  dartway_serverpod_core_server: "0.12.0"
---

## Who is affected

Every project with a database — the core's own tables changed, and a project inherits that the
ordinary way: its own `serverpod generate` and `create-migration`. Until it does, the schema is the
old one and both changes below simply are not there.

**Apply this after the code migrations of this release**, not before: one of the two can fail on
data, and finding that out while half the project is still uncompiled is the wrong order.

## What changed

**`dw_cloud_file`: a unique index on `(bucket, path)`, and a `fileName` column.** The ledger is
what makes an object key unique now — a repeat is a refused insert the endpoint answers by trying
the next candidate, rather than a silent overwrite.

**`dw_auth_request`: an index on `(userIdentifier, createdAt)`.** Rate limiting asks, by
construction, "how many times have we sent to this identifier in the window", and without an index
that answer was a sequential scan of a table that only ever grows — measured on a production app at
126 thousand rows and 12 ms on every sign-in.

## Before you apply it

**The `dw_cloud_file` migration fails on a table that already holds two rows for one
`(bucket, path)`** — which is precisely the trace the upload defect leaves behind. Find them first:

```sql
SELECT bucket, path, count(*), array_agg(id)
FROM dw_cloud_file GROUP BY bucket, path HAVING count(*) > 1;
```

Rows coming back mean one object was overwritten by another user's upload. Decide which row is the
truth, delete the others, then migrate. Do not widen the index to make it apply.

## What to change

In the server package, with the `serverpod_cli` version this project pins — `dartway doctor` states
it, and a drifted CLI writes generated code for its own version:

```bash
serverpod generate
serverpod create-migration
```

Commit the generated migration with the rest of the update, and apply it the way this project
applies migrations.

## How to check

The migration applies without an error, and `\d dw_cloud_file` shows the unique index. Then upload
the same file twice from two accounts and confirm the second lands on its own key instead of
replacing the first.
