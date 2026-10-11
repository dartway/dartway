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

# Runtime dependencies:
# - bookworm-slim's libc6 supplies the ELF loader, libc, libm, libdl and
#   libpthread, matching the compiler stage; TLS code is linked into the binary.
# - ca-certificates in this layer supplies Dart's system TLS trust store.
# - libc6 and the base's /etc/nsswitch.conf resolve DNS; Docker supplies
#   /etc/resolv.conf and /etc/hosts when the container starts.
# - the base's tzdata and /etc/localtime supply timezone data (UTC by default).
# The AOT binary includes its Dart packages and reads only the mounted project;
# its entry point launches no subprocesses and needs no Dart SDK or git.
FROM debian:bookworm-slim
RUN apt-get update \
 && apt-get install -y --no-install-recommends ca-certificates \
 && rm -rf /var/lib/apt/lists/*
COPY --from=build /check-stack /app/check-stack
ENTRYPOINT ["/app/check-stack"]
