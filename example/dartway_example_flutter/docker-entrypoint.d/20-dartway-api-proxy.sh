#!/bin/sh
set -eu

output=/etc/nginx/conf.d/dartway-api-proxy.inc
: > "$output"

if [ -z "${DW_API_ORIGIN:-}" ]; then
  exit 0
fi

if ! printf '%s\n' "$DW_API_ORIGIN" | grep -Eq '^https://[A-Za-z0-9.-]+(:[0-9]+)?$'; then
  echo 'DW_API_ORIGIN must be https://host[:port]' >&2
  exit 1
fi

if [ -z "${DW_API_PATHS:-}" ]; then
  echo 'DW_API_PATHS must contain one or more absolute paths' >&2
  exit 1
fi

DW_API_HOST=${DW_API_ORIGIN#https://}
export DW_API_ORIGIN DW_API_HOST

for path in $DW_API_PATHS; do
  if ! printf '%s\n' "$path" | grep -Eq '^/[A-Za-z0-9._~:@%+-]+(/[A-Za-z0-9._~:@%+-]+)*/?$'; then
    echo "DW_API_PATHS contains invalid path: $path" >&2
    exit 1
  fi

  if [ "$path" = /dw ]; then
    cat >> "$output" <<'EOF'
location ^~ /dw/ {
  client_max_body_size 0;
  proxy_pass ${DW_API_ORIGIN};
  proxy_request_buffering off;
  proxy_ssl_server_name on;
  proxy_ssl_verify on;
  proxy_ssl_trusted_certificate /etc/ssl/certs/ca-certificates.crt;
  proxy_ssl_verify_depth 2;
  proxy_set_header Host ${DW_API_HOST};
  proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
  proxy_set_header X-Forwarded-Proto $http_x_forwarded_proto;
  proxy_http_version 1.1;
  proxy_set_header Upgrade $http_upgrade;
  proxy_set_header Connection "upgrade";
  proxy_buffering off;
  proxy_read_timeout 1h;
}
EOF
  else
    if [ "${path%/}" != "$path" ]; then
      app_path=${path%/}
      cat >> "$output" <<EOF
location = $app_path {
  try_files \$uri \$uri/ /index.html;
  add_header Cache-Control "no-cache";
}
EOF
    fi

    cat >> "$output" <<EOF
location ^~ $path {
  client_max_body_size 0;
  proxy_pass \${DW_API_ORIGIN};
  proxy_request_buffering off;
  proxy_ssl_server_name on;
  proxy_ssl_verify on;
  proxy_ssl_trusted_certificate /etc/ssl/certs/ca-certificates.crt;
  proxy_ssl_verify_depth 2;
  proxy_set_header Host \${DW_API_HOST};
  proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
  proxy_set_header X-Forwarded-Proto \$http_x_forwarded_proto;
}
EOF
  fi
done

envsubst '${DW_API_ORIGIN} ${DW_API_HOST}' < "$output" > "$output.rendered"
mv "$output.rendered" "$output"
