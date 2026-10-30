---
title: Production deploys require a database backup policy
affects:
  dartway_cli: "0.27.0"
---

## Who is affected

Projects using the Compose `dartway deploy run --env production` workflow.

## What to change

Add `backup:` to the production environment in `deploy/config.yaml`, including
the S3-compatible store's HTTPS `endpoint` (and its `region`, which defaults to
`ru-1`), deliver
`AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY` with `dartway secret set`, and
run `dartway deploy setup --env production`. See
[Database backups](../5-tooling/deploy.md#database-backups) for the complete
configuration and the restore-check procedure.

Production deployment now refuses to continue without that policy. The
one-time emergency exception is `--skip-backup`; it is deliberately recorded
in the deployment journal and is not a replacement for configuring backups.
