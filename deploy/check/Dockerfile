FROM dart:3.13.2 AS build
WORKDIR /cli
COPY packages/dartway_cli/ ./
# The check binary uses only the CLI's runtime dependencies, outside the pub
# workspace; Flutter and the server test dependencies do not enter this image.
RUN sed -i '/^resolution: workspace$/d; /^dev_dependencies:/,$d' pubspec.yaml \
 && dart pub get \
 && dart compile exe bin/check_stack.dart -o /check-stack

# Dart's runtime tree supplies the dynamic loader and libraries. A scratch
# image avoids overwriting /lib symlinks in distributions with merged /usr.
FROM scratch
COPY --from=build /runtime/ /
COPY --from=build /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/ca-certificates.crt
COPY --from=build /check-stack /app/check-stack
ENTRYPOINT ["/app/check-stack"]
