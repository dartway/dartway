---
title: The web image installs the Flutter your .fvmrc names
affects:
  dartway_cli: "0.11.1"
---

## Who is affected

A project whose `<project>_flutter/Dockerfile` builds `FROM ghcr.io/cirruslabs/flutter:<version>`
while its `.fvmrc` pins another version — every project created before `dartway_cli` 0.11.1 that
moves its `.fvmrc` past 3.44.0, the last image published. Flutter pins some of the packages an app
resolves, so the lock your Flutter writes is refused by the image's
`flutter pub get --enforce-lockfile`, inside `docker build`, with a list of changed packages.
`dartway deploy check` names the mismatch first (`web-flutter-version`, an error).

A project whose image tag and `.fvmrc` agree has nothing to do until it moves its Flutter.

## What to change

`<project>_flutter/Dockerfile`, the first line of the build stage:

    - FROM ghcr.io/cirruslabs/flutter:3.44.0 AS build
    + FROM debian:bookworm-slim AS build
    +
    + RUN apt-get update \
    +  && apt-get install -y --no-install-recommends ca-certificates curl git unzip xz-utils \
    +  && rm -rf /var/lib/apt/lists/*
    + COPY <project>_flutter/.fvmrc /tmp/fvmrc
    + RUN version="$(sed -n 's/.*"flutter"[^"]*"\([^"]*\)".*/\1/p' /tmp/fvmrc)" \
    +  && test -n "$version" \
    +  && git clone --quiet --depth 1 --branch "$version" \
    +       https://github.com/flutter/flutter.git /opt/flutter
    + ENV PATH="/opt/flutter/bin:$PATH"
    + RUN flutter --disable-analytics && flutter precache --web

The rest of the stage is unchanged. The first build on a server takes a few minutes longer; the
Flutter layer is cached until `.fvmrc` changes.

## How to check

`dartway deploy check --env <environment> --local`: `web-flutter-version` passes with
"read from .fvmrc".
