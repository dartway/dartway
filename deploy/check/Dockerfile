FROM debian:bookworm-slim AS build
RUN apt-get update \
 && apt-get install -y --no-install-recommends ca-certificates curl git unzip xz-utils \
 && rm -rf /var/lib/apt/lists/*
# Resolve the real workspace on the same Flutter that wrote its committed lock.
COPY .fvmrc /tmp/fvmrc
RUN version="$(sed -n 's/.*"flutter"[^"]*"\([^"]*\)".*/\1/p' /tmp/fvmrc)" \
 && test -n "$version" \
 && git clone --quiet --depth 1 --branch "$version" \
      https://github.com/flutter/flutter.git /opt/flutter
ENV PATH="/opt/flutter/bin:$PATH"
RUN flutter --disable-analytics
WORKDIR /workspace
COPY pubspec.yaml pubspec.lock ./
COPY packages/ packages/
COPY tool/ tool/
RUN flutter pub get --enforce-lockfile \
 && dart compile exe packages/dartway_cli/bin/check_stack.dart -o /check-stack

# Match the compiler's libc and loader without copying over system symlinks.
FROM debian:bookworm-slim
COPY --from=build /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/ca-certificates.crt
COPY --from=build /check-stack /app/check-stack
ENTRYPOINT ["/app/check-stack"]
