---
title: Declare Studio migration paths and pass web build numbers
affects:
  dartway_cli: "0.25.0"
---

## Who is affected

Projects with generated `deploy/studio.yml` and `.github/workflows/images.yml`,
or a web Dockerfile copied before it accepted `BUILD_NUMBER`.

## What to change

Run `dartway deploy kamal` after resolving the Flutter package dependencies.
Commit the regenerated files: `deploy/studio.yml` now declares migration globs
relative to the repository root, using the actual server directory, and Images
passes `BUILD_NUMBER=${{ github.run_number }}` to every service build.

The web Dockerfile is project-owned. In `<project>_flutter/Dockerfile`, add
`ARG BUILD_NUMBER=0` after `RUN flutter pub get --enforce-lockfile`, then add
`--build-number=$BUILD_NUMBER` to the existing `flutter build web` command:

```dockerfile
RUN flutter pub get --enforce-lockfile

ARG BUILD_NUMBER=0

RUN flutter build web --release --build-number=$BUILD_NUMBER --no-web-resources-cdn
```

Keep the argument after dependency resolution so changing the number does not
invalidate dependency layers. The `0` default is only for direct local Docker
builds. Kamal passes the GitHub Actions run number, while `dartway deploy run`
passes the deployment's UTC epoch second; both deployed web-image paths
therefore override the default. No server or storage Dockerfile edit is needed.

## How to check

Run `dartway deploy kamal --check`. Confirm the manifest's migration globs cover
`<project>_server/lib/src/migrations/migrations.dart` and
`<project>_server/pubspec.lock`.

Build from the project root with
`docker build --build-arg BUILD_NUMBER=7 -f <project>_flutter/Dockerfile -t web-build-number .`.
Read the built metadata with
`docker run --rm --entrypoint cat web-build-number /usr/share/nginx/html/version.json`;
`build_number` must be `"7"`.

Image tags remain SHA-based. An existing image is skipped and keeps its original
build number; a rerun does not relabel or rebuild it.
