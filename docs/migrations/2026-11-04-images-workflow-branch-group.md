---
title: Images workflow serializes by branch
affects:
  dartway_cli: "0.27.0"
---

## Who is affected

Projects deploying with Kamal, whose `.github/workflows/images.yml` still has
`group: images-${{ github.event.workflow_run.head_sha }}`.

## What to change

Run `dartway deploy kamal` and commit the regenerated
`.github/workflows/images.yml`. The concurrency group becomes
`images-${{ github.event.workflow_run.head_branch }}` with
`cancel-in-progress: false`: a running build finishes, and a newer pending run
of the same branch replaces an older pending one, so earlier commits of a busy
branch get no images unless they were built before. Rollbacks use images that
already exist.

## How to check

`dartway deploy kamal --check` exits 0; on the old workflow it fails with
`Stale Kamal files: .github/workflows/images.yml` and asks to regenerate.
