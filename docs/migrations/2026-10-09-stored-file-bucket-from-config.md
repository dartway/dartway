---
title: dw_stored_file names no bucket; a file's bucket comes from the configuration
affects:
  dartway_core_server: "0.21.0-dev.17"
---

## Who is affected

A project with file storage. The framework migration
`20261009_000002_dw_stored_file_bucket_from_config` drops `dw_stored_file.bucket`; from then on a
file is read, linked and deleted in the bucket the configuration names for its visibility. It
refuses to apply — and the server does not start — while the files of one visibility are recorded
in more than one bucket, which is the case where a storage was moved or a bucket renamed after
files were uploaded.

## What to change

1. Before upgrading, on every environment:

       SELECT visibility, bucket, count(*) FROM dw_stored_file GROUP BY 1, 2;

2. Where a visibility shows more than one bucket, or a bucket other than the one
   `DW_STORAGE_PUBLIC_BUCKET` / `DW_STORAGE_PRIVATE_BUCKET` names now, copy those objects under the
   same key into the configured bucket of their visibility, then record it:

       UPDATE dw_stored_file SET bucket = '<configured bucket>' WHERE visibility = '<visibility>';

   The migration's failure names the same statement if this step was missed; run it and start the
   server again.

From now on, moving storage or renaming a bucket is only a copy of each object into its visibility's
new bucket under the same key. The rows need nothing, and a hand `UPDATE dw_stored_file` is never
part of it.

## How to check

The server starts, and `SELECT column_name FROM information_schema.columns WHERE table_name =
'dw_stored_file' AND column_name = 'bucket'` returns no row. An existing public file's URL and a
private file's link open.
