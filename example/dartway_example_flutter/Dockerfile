# Built from the **project root** by the compose file `dartway deploy setup`
# renders: the shared contract package is a path dependency of this one, so a
# context narrower than the root cannot resolve it. Every path below is relative
# to the root.
FROM debian:bookworm-slim AS build

# Flutter at the version the project's `.fvmrc` names, installed here rather
# than taken from a Flutter image. The SDK pins some of the packages an app
# resolves (`meta`, `vector_math`, …), so a lock written on one Flutter is not
# satisfiable on another and `--enforce-lockfile` below refuses it: the image
# has to build on the Flutter the project resolved with. Images trail Flutter
# releases by months, and `.fvmrc` stays the one place the version is stated.
# The layer is cached until `.fvmrc` changes.
RUN apt-get update \
 && apt-get install -y --no-install-recommends ca-certificates curl git unzip xz-utils \
 && rm -rf /var/lib/apt/lists/*
COPY dartway_example_flutter/.fvmrc /tmp/fvmrc
RUN version="$(sed -n 's/.*"flutter"[^"]*"\([^"]*\)".*/\1/p' /tmp/fvmrc)" \
 && test -n "$version" \
 && git clone --quiet --depth 1 --branch "$version" \
      https://github.com/flutter/flutter.git /opt/flutter
ENV PATH="/opt/flutter/bin:$PATH"
RUN flutter --disable-analytics && flutter precache --web

WORKDIR /workspace
COPY dartway_example_shared/ dartway_example_shared/
COPY dartway_example_flutter/ dartway_example_flutter/

WORKDIR /workspace/dartway_example_flutter
# `--enforce-lockfile`: a deploy builds exactly what was committed. Without it
# pub is free to resolve a different set inside the container than the one the
# project tested — that has already cost a failed deploy, where a transitive
# package the app needs was dropped and pub then could not read its own
# `package_graph.json`. With it, a lock that has drifted from the pubspec is an
# honest error naming both.
RUN flutter pub get --enforce-lockfile

# A web build compiles the server address into itself, so it has to be given
# one: the origin its calls go to — the web app's own host, where `/dw/` and
# `/health` are proxied to the server (`https://app.example.com`). The deploy
# passes it, which keeps it declared in a single place — do not hardcode it
# here or in the app. Building this image by hand means passing it by hand.
ARG DW_BACKEND_URL
RUN test -n "$DW_BACKEND_URL"
RUN flutter build web --release \
    --dart-define="DW_BACKEND_URL=${DW_BACKEND_URL}"

# `COPY` keeps each file's mode, and the checkout's modes come from the umask
# of whoever pulled it on the server: under `077` a newly added asset reaches
# the image as `rw-------`, nginx's workers answer it 403, and the deploy, its
# checks and every page still look fine. Normalised here, in the build stage,
# so the image does not depend on the build host and no layer copies the site.
RUN chmod -R a+rX build/web

FROM nginx:1.30.5-alpine

COPY --from=build /workspace/dartway_example_flutter/build/web /usr/share/nginx/html

# How the build is served, and above all what a browser may keep. A file of its
# own rather than a heredoc: the caching split is the part of a deployment that
# fails silently — a stale entry point serves the previous build to a browser
# that never asks again — so it has to be readable, diffable, and something
# `dartway deploy check` can interrogate.
COPY dartway_example_flutter/nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 80
