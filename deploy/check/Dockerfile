FROM dart:3.13.2 AS build
WORKDIR /cli
COPY packages/dartway_cli/ ./
# The check binary uses only the CLI's runtime dependencies, outside the pub
# workspace; Flutter and the server test dependencies do not enter this image.
RUN sed -i '/^resolution: workspace$/d; /^dev_dependencies:/,$d' pubspec.yaml \
 && dart pub get \
 && dart compile exe bin/check_stack.dart -o /check-stack

FROM debian:bookworm-slim
RUN apt-get update \
 && apt-get install -y --no-install-recommends ca-certificates \
 && rm -rf /var/lib/apt/lists/*
COPY --from=build /runtime/ /
COPY --from=build /check-stack /app/check-stack
ENTRYPOINT ["/app/check-stack"]
