# Built from the **project root**, not from this folder: the compose file
# `dartway deploy setup` renders declares `context: .` and names this file
# explicitly, because the server needs the shared contract package beside it
# and a context can only be one directory. Every path below is relative to the
# root.
FROM dart:3.12.0 AS build

WORKDIR /workspace
# Every path dependency by name. One whose directory never enters the build
# context fails inside `dart pub get` as exit code 66, three layers from the
# cause; `dartway deploy check` compares these lines with the pubspecs.
COPY dartway_starter_shared/ dartway_starter_shared/
COPY dartway_starter_server/ dartway_starter_server/

WORKDIR /workspace/dartway_starter_server
RUN dart pub get
RUN dart compile exe bin/server.dart -o /server

FROM alpine:latest

# The compiled binary is dynamically linked; /runtime holds exactly the
# libraries it needs. ca-certificates is not part of them, and without it every
# outbound HTTPS call from the server fails on an unverifiable certificate.
# Alpine also brings busybox `wget`, which the deployment's healthcheck calls.
COPY --from=build /runtime/ /
RUN apk add --no-cache ca-certificates

COPY --from=build /server /app/server

# Configured by the environment alone — DW_DATABASE_*, DW_STORAGE_*, PORT and
# the project's own keys — rendered by the deploy from deploy/config.yaml and
# the secret store. There is no configuration file. The server applies its
# migrations as it starts and exits non-zero when one fails.
EXPOSE 8080

# Exec form on purpose: the binary is PID 1 and receives the SIGTERM a deploy
# sends, which is what makes its stop graceful. Under shell form the signal
# stops at /bin/sh and the server is killed mid-call when the grace period
# runs out. `dartway deploy check` fails on that form.
ENTRYPOINT ["/app/server"]
