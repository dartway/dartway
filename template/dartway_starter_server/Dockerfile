# Built from the **project root**, not from this folder: the compose file
# `dartway deploy setup` renders declares `context: .` and names this file
# explicitly, because the web image next to it needs two packages and a context
# can only be one directory. Every path below is therefore relative to the root.
FROM dart:3.12.0 AS build

WORKDIR /workspace
COPY dartway_starter_server/ dartway_starter_server/

WORKDIR /workspace/dartway_starter_server
RUN dart pub get
RUN dart compile exe bin/main.dart -o /server

FROM alpine:latest

# The compiled binary is dynamically linked; /runtime holds exactly the
# libraries it needs. ca-certificates is not part of them, and without it every
# outbound HTTPS call from the server fails on an unverifiable certificate.
COPY --from=build /runtime/ /
RUN apk add --no-cache ca-certificates

WORKDIR /app
COPY --from=build /server /app/server
# The Serverpod configuration is source, not something the deploy renders. What
# arrives over this directory at runtime comes from the server's secret store:
# passwords.yaml, and every file named under `requires.files` in
# deploy/config.yaml, each mounted read-only under its own name.
COPY --from=build /workspace/dartway_starter_server/config/ /app/config/
COPY --from=build /workspace/dartway_starter_server/web/ /app/web/
COPY --from=build /workspace/dartway_starter_server/migrations/ /app/migrations/
# Insights reads this file to filter endpoint logs.
COPY --from=build /workspace/dartway_starter_server/lib/src/generated/protocol.yaml /app/lib/src/generated/protocol.yaml

EXPOSE 8080 8081 8082

# Exec form on purpose. Migrations run as `docker compose run backend
# --mode=... --apply-migrations`, and those arguments replace CMD — which only
# happens in this form. Shell form (`ENTRYPOINT ./server --mode=$runmode`)
# ignores them and starts an ordinary server instead, so the deploy reports a
# migration that never ran. `dartway deploy check` fails on that form.
ENTRYPOINT ["/app/server"]
CMD ["--mode=production", "--server-id=default", "--logging=normal", "--role=monolith"]
