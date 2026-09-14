# Built from the **project root**: the shared contract package is a path
# dependency of this one, so a context narrower than the root cannot resolve
# it. Every path below is relative to the root.
FROM dart:3.12.0 AS build

WORKDIR /workspace
COPY dartway_example_shared/ dartway_example_shared/
COPY dartway_example_server/ dartway_example_server/

WORKDIR /workspace/dartway_example_server
RUN dart pub get
RUN dart compile exe bin/server.dart -o /server

FROM alpine:latest

# The compiled binary is dynamically linked; /runtime holds exactly the
# libraries it needs. ca-certificates is not part of them, and without it every
# outbound HTTPS call from the server fails on an unverifiable certificate.
COPY --from=build /runtime/ /
RUN apk add --no-cache ca-certificates

COPY --from=build /server /app/server

# Configured by the environment: DW_DATABASE_*, PORT, DW_MIN_APP_BUILD,
# DW_ALLOWED_ORIGINS (see bin/server.dart). It applies its migrations on start.
EXPOSE 8080
ENTRYPOINT ["/app/server"]
