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

# This server block serves the build inside the container; the deployment's own
# Nginx sits in front of it and terminates TLS.
COPY <<'EOF' /etc/nginx/conf.d/default.conf
server {
  listen 80;
  root /usr/share/nginx/html;
  index index.html;

  # A Flutter route is not a file: everything unknown is answered by the app.
  location / {
    try_files $uri $uri/ /index.html;
  }

  location ~* \.(png|jpg|jpeg|gif|ico|svg|woff|woff2)$ {
    expires 1y;
    add_header Cache-Control "public, immutable";
  }

  # The build's own files change on every deploy and carry no hash in the name,
  # so a cached copy is a stale app that nobody can refresh out of.
  location ~* \.(js|css|json|wasm)$ {
    add_header Cache-Control "no-cache";
  }

  location = /index.html {
    add_header Cache-Control "no-cache";
  }
}
EOF

EXPOSE 80
