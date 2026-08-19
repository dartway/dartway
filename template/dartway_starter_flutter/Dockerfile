# Built from the **project root** by the compose file `dartway deploy setup`
# renders: the client package is a path dependency of this one, so a context
# narrower than the root cannot resolve it. Every path below is relative to the
# root.
FROM ghcr.io/cirruslabs/flutter:3.44.0 AS build

WORKDIR /workspace
COPY dartway_starter_client/ dartway_starter_client/
COPY dartway_starter_flutter/ dartway_starter_flutter/

WORKDIR /workspace/dartway_starter_flutter
RUN flutter pub get

# A web build compiles the API address into itself, so it has to be given one.
# The deploy passes the domain from the Serverpod configuration, which is what
# keeps it declared in a single place — do not hardcode it here or in the app.
# Building this image by hand means passing the argument by hand.
ARG DW_BACKEND_URL
RUN test -n "$DW_BACKEND_URL"
RUN flutter build web --release \
    --dart-define="DW_BACKEND_URL=${DW_BACKEND_URL}"

FROM nginx:alpine

COPY --from=build /workspace/dartway_starter_flutter/build/web /usr/share/nginx/html

# How the build is served, and above all what a browser may keep. A file of its
# own rather than a heredoc: the caching split is the part of a deployment that
# fails silently — a stale entry point serves the previous build to a browser
# that never asks again — so it has to be readable, diffable, and something
# `dartway deploy check` can interrogate.
COPY dartway_starter_flutter/nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 80
