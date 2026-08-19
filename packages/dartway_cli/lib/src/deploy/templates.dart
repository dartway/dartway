/// Built-in infrastructure templates.
///
/// A project overrides them rather than forking them: `deploy/compose.override.yml`
/// is merged by Docker Compose itself, and files under `deploy/nginx.d/` are
/// included by the rendered Nginx config. Only a project that needs something
/// neither hook reaches replaces a template wholesale.
library;

/// Placeholders substituted before upload. Kept explicit so a typo in a
/// template fails loudly at render time instead of shipping `${...}` to a
/// server.
enum DwTemplateToken {
  serverpodEnv,
  serverPackage,
  flutterPackage,
  runtimeConfigDir,
  databaseName,
  databaseUser,
  apiPort,
  insightsPort,
  webServerPort,
  apiDomain,
  insightsDomain,
  webServerDomain,
  webAppDomain,
  certName,
  registryPrefix;

  String get placeholder => '__${name.toUpperCase()}__';
}

/// The compose file every DartWay deployment starts from.
///
/// Secrets arrive as a single-file mount from the runtime store, never through
/// the build context: a credential copied into an image layer is a credential
/// in every copy of that image.
const String dwComposeTemplate = '''
# Rendered by "dartway deploy setup". Project-specific changes belong in
# deploy/compose.override.yml, which Compose merges over this file.

services:
  postgres:
    image: __REGISTRYPREFIX__postgres:16-alpine
    restart: unless-stopped
    environment:
      POSTGRES_DB: __DATABASENAME__
      POSTGRES_USER: __DATABASEUSER__
      POSTGRES_PASSWORD: \${DB_PASSWORD}
    volumes:
      - postgres_data:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U __DATABASEUSER__ -d __DATABASENAME__"]
      interval: 5s
      timeout: 5s
      retries: 20

  backend:
    build:
      context: .
      dockerfile: __SERVERPACKAGE__/Dockerfile
    restart: unless-stopped
    # The run mode is stated twice because the two Dockerfile forms read it
    # differently: the canonical exec-form image takes it from `command`, while
    # a shell-form one interpolates the environment variable and ignores
    # `command` altogether. `docker compose run` replaces `command` — that is
    # how the migration run gets its own arguments.
    environment:
      runmode: __SERVERPODENV__
    command:
      - "--mode=__SERVERPODENV__"
      - "--server-id=default"
      - "--logging=normal"
      - "--role=monolith"
    expose:
      - "__APIPORT__"
      - "__INSIGHTSPORT__"
      - "__WEBSERVERPORT__"
    volumes:
      - __RUNTIMECONFIGDIR__/passwords.yaml:/app/config/passwords.yaml:ro
    depends_on:
      postgres:
        condition: service_healthy

  web:
    build:
      context: .
      dockerfile: __FLUTTERPACKAGE__/Dockerfile
      args:
        # A web build compiles the API address into itself, so the deploy has
        # to supply it — and it supplies the one from the Serverpod
        # configuration. Otherwise the domain would have to be repeated in the
        # Flutter code or in the override, which is a copy nothing compares
        # against: the build would keep succeeding against yesterday's API.
        DW_BACKEND_URL: https://__APIDOMAIN__/
    restart: unless-stopped
    expose:
      - "80"

  nginx:
    image: __REGISTRYPREFIX__nginx:alpine
    restart: unless-stopped
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx.conf:/etc/nginx/conf.d/default.conf:ro
      - ./nginx.d:/etc/nginx/dartway:ro
      - certbot_data:/etc/letsencrypt:ro
      - certbot_www:/var/www/certbot:ro
    depends_on:
      - backend
      - web

  certbot:
    image: __REGISTRYPREFIX__certbot/certbot:latest
    volumes:
      - certbot_data:/etc/letsencrypt
      - certbot_www:/var/www/certbot
    entrypoint: /bin/sh
    command:
      - -c
      # \$\$ is how Compose passes a literal dollar down instead of
      # substituting a variable. A YAML-style escape is invalid here and breaks parsing.
      - "trap exit TERM; while :; do certbot renew --webroot -w /var/www/certbot; sleep 12h & wait \$\${!}; done"

volumes:
  postgres_data:
  certbot_data:
  certbot_www:
''';

/// The Redis service, appended when the Serverpod config enables it and points
/// at a container this deployment owns.
const String dwComposeRedisService = '''

  redis:
    image: __REGISTRYPREFIX__redis:7-alpine
    restart: unless-stopped
    command: ["redis-server", "--requirepass", "\${REDIS_PASSWORD}"]
    healthcheck:
      test: ["CMD-SHELL", "redis-cli -a \\"\${REDIS_PASSWORD}\\" ping | grep -q PONG"]
      interval: 5s
      timeout: 5s
      retries: 20
''';

/// The Nginx config every DartWay deployment starts from.
///
/// Three include points carry project specifics: `http` for directives that
/// cannot live inside a server block — `map`, upstreams — `api` for the API
/// host, where CORS and preflight handling belong, and `app` for extra
/// locations on the web-app host.
const String dwNginxTemplate = '''
# Rendered by "dartway deploy setup". Project-specific directives belong in
# deploy/nginx.d/http/*.conf and deploy/nginx.d/app/*.conf.

# Connection: upgrade only on a real upgrade. For an ordinary POST it must be
# close, or the upstream never reads the request body.
map \$http_upgrade \$connection_upgrade {
    default upgrade;
    ""      close;
}

include /etc/nginx/dartway/http/*.conf;

server {
    listen 80;
    server_name __APIDOMAIN__ __INSIGHTSDOMAIN__ __WEBSERVERDOMAIN__ __WEBAPPDOMAIN__;

    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
    }

    location / {
        return 301 https://\$host\$request_uri;
    }
}

server {
    listen 443 ssl;
    server_name __APIDOMAIN__;
    ssl_certificate     /etc/letsencrypt/live/__CERTNAME__/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/__CERTNAME__/privkey.pem;

    location / {
        # Included inside the location, not beside it: what a project adds
        # here — CORS headers, a preflight short-circuit, a longer read
        # timeout — only has an effect on the proxied request itself.
        include /etc/nginx/dartway/api/*.conf;

        proxy_pass http://backend:__APIPORT__;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection \$connection_upgrade;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}

server {
    listen 443 ssl;
    server_name __INSIGHTSDOMAIN__;
    ssl_certificate     /etc/letsencrypt/live/__CERTNAME__/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/__CERTNAME__/privkey.pem;

    location / {
        proxy_pass http://backend:__INSIGHTSPORT__;
        proxy_set_header Host \$host;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}

server {
    listen 443 ssl;
    server_name __WEBSERVERDOMAIN__;
    ssl_certificate     /etc/letsencrypt/live/__CERTNAME__/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/__CERTNAME__/privkey.pem;

    location / {
        proxy_pass http://backend:__WEBSERVERPORT__;
        proxy_set_header Host \$host;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}

server {
    listen 443 ssl;
    server_name __WEBAPPDOMAIN__;
    ssl_certificate     /etc/letsencrypt/live/__CERTNAME__/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/__CERTNAME__/privkey.pem;

    include /etc/nginx/dartway/app/*.conf;

    location / {
        proxy_pass http://web:80;
        proxy_set_header Host \$host;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
''';
