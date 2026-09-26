import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'deploy_target.dart';
import 'stack.dart';

/// Renders the two infrastructure files of a deployment: the compose file and
/// the front proxy's configuration.
///
/// Built in code rather than substituted into a text template, because the
/// stack has optional parts — a site, a storage, TLS or not — and a template
/// with conditional sections is a second language nobody tests. The output is
/// still plain text meant to be read on the server while debugging, so it is
/// laid out and commented as if written by hand.
///
/// A project changes it without forking it: `deploy/compose.override.yml` is
/// merged by Compose itself, and `deploy/nginx.d/{http,api,app}/*.conf` are
/// included by the proxy.
class DwStackRenderer {
  DwStackRenderer({
    required this.stack,
    this.projectRoot,
    this.buildContext = '.',
  });

  final DwStack stack;

  /// The working copy, for the optional project files. Null when rendering
  /// for a project that is not on this machine.
  final Directory? projectRoot;

  /// The build context and site root as the compose file names them. `.` on a
  /// server, where the compose file sits in the checkout root; an absolute
  /// path when the stack is rendered somewhere else, as the local proof does.
  final String buildContext;

  DwDeployTarget get _target => stack.target;

  /// [image] as the compose file names it: through `registry_mirror` when
  /// the mirror can serve it (see [DwStack.mirrorServes]).
  String _image(String image) => switch (_target.registryMirror) {
    final mirror? when DwStack.mirrorServes(image) => '$mirror/$image',
    _ => image,
  };

  bool get _tls => stack.front is DwTlsFront;

  /// A path inside the build context, as a bind-mount source. Relative ones
  /// keep their `./`: Compose reads a bare `app_site/build:/srv/site` as a
  /// named volume and refuses the whole project.
  String _context(String relative) => buildContext == '.'
      ? './$relative'
      : p.posix.join(buildContext, relative);

  /// A YAML scalar that means exactly [value]: a JSON string is a valid YAML
  /// double-quoted scalar, and quoting everything spares the reader every rule
  /// about which bare words YAML turns into booleans.
  static String _q(String value) => jsonEncode(value);

  /// A Compose interpolation that refuses to render without its value.
  ///
  /// `:?` turns a missing secret into an error naming it on every Compose
  /// command, instead of a Postgres initialised with an empty password.
  static String _secret(String key) =>
      '\${$key:?$key is missing from ${DwStack.envFile} - '
      'dartway deploy renders it from the secret store}';

  String get composeFile {
    final storage = _target.storage == DwStorageMode.bundled;
    final site = _target.site;
    final buffer = StringBuffer()
      ..writeln(
        '# Rendered by "dartway deploy setup" from deploy/config.yaml '
        '[${_target.environment}].',
      )
      ..writeln(
        '# Do not edit: project additions belong in '
        'deploy/compose.override.yml, which',
      )
      ..writeln('# every deploy merges over this file.')
      ..writeln()
      ..writeln('services:');

    // --- postgres
    buffer
      ..writeln('  ${DwStack.postgresService}:')
      ..writeln('    image: ${_q(_image(DwStack.postgresImage))}')
      ..writeln('    restart: unless-stopped')
      ..writeln('    environment:')
      ..writeln('      POSTGRES_DB: ${_q(stack.databaseName)}')
      ..writeln('      POSTGRES_USER: ${_q(stack.databaseName)}')
      ..writeln(
        '      POSTGRES_PASSWORD: ${_q(_secret(DwStack.databasePasswordKey))}',
      )
      ..writeln('    volumes:')
      ..writeln(
        '      - ${_q('${DwStack.postgresDataVolume}:/var/lib/postgresql/data')}',
      )
      ..writeln('    healthcheck:')
      ..writeln(
        '      test: ["CMD-SHELL", '
        '${_q('pg_isready -U ${stack.databaseName} -d ${stack.databaseName}')}]',
      )
      ..writeln('      interval: 5s')
      ..writeln('      timeout: 5s')
      ..writeln('      retries: 30')
      ..writeln();

    // --- server
    buffer
      ..writeln('  ${DwStack.serverService}:')
      ..writeln('    build:')
      ..writeln('      context: ${_q(buildContext)}')
      ..writeln('      dockerfile: ${_q('${stack.serverPackage}/Dockerfile')}')
      ..writeln('    restart: unless-stopped')
      ..writeln(
        '    # Secrets, rendered from the secret store by every deploy. The '
        'derived',
      )
      ..writeln(
        '    # values below win over a key of the same name there, which is '
        'why the',
      )
      ..writeln('    # store refuses those names.')
      ..writeln('    env_file:')
      ..writeln('      - ${_q(DwStack.envFile)}')
      ..writeln('    environment:');
    for (final MapEntry(:key, :value) in stack.serverEnvironment.entries) {
      buffer.writeln('      $key: ${_q(value)}');
    }
    buffer
      ..writeln('    expose:')
      ..writeln('      - ${_q('${DwStack.serverPort}')}')
      ..writeln(
        '    # SIGTERM is a graceful stop: calls in flight are answered, live '
        'sockets',
      )
      ..writeln(
        '    # closed, jobs finished — each bounded by the server\'s stop '
        'timeout.',
      )
      ..writeln('    stop_grace_period: 45s')
      ..writeln('    healthcheck:')
      ..writeln(
        '      # 200 once migrated and serving, 503 while the database is '
        'unreachable.',
      )
      ..writeln(
        '      test: ["CMD", "wget", "-q", "-O", "/dev/null", '
        '${_q('http://127.0.0.1:${DwStack.serverPort}/health')}]',
      )
      ..writeln('      interval: 5s')
      ..writeln('      timeout: 5s')
      ..writeln('      retries: 3')
      ..writeln(
        '      # Migrations run before the port opens; a long one is not a '
        'failure.',
      )
      ..writeln('      start_period: 600s')
      ..writeln('      start_interval: 2s');
    final files = _target.requiredSecretFiles;
    if (files.isNotEmpty) {
      buffer
        ..writeln(
          '    # Every file declared under requires.files, read-only. A file '
          'delivered to',
        )
        ..writeln(
          '    # the server and not mounted here is a file the application '
          'does not have.',
        )
        ..writeln('    volumes:');
      for (final name in files) {
        if (!dwIsSecretFileName(name)) {
          throw StateError(
            'requires.files entry "$name" is not a file name and cannot be '
            'mounted.',
          );
        }
        buffer.writeln(
          '      - ${_q('${_target.runtimeConfigDir}/$name:'
          '${DwStack.secretFilesDir}/$name:ro')}',
        );
      }
    }
    buffer
      ..writeln('    depends_on:')
      ..writeln('      ${DwStack.postgresService}:')
      ..writeln('        condition: service_healthy');
    if (storage) {
      buffer
        ..writeln('      ${DwStack.storageInitService}:')
        ..writeln('        condition: service_completed_successfully');
    }
    buffer.writeln();

    // --- web
    buffer
      ..writeln('  ${DwStack.webService}:')
      ..writeln('    build:')
      ..writeln('      context: ${_q(buildContext)}')
      ..writeln('      dockerfile: ${_q('${stack.flutterPackage}/Dockerfile')}')
      ..writeln('      args:')
      ..writeln(
        '        # The app calls its own origin: /dw/ and /health on it '
        'reach the server.',
      )
      ..writeln('        DW_BACKEND_URL: ${_q(stack.appOrigin)}')
      ..writeln(
        '        # Where this build answers, for the Studio binding: it '
        'admits a Studio',
      )
      ..writeln(
        '        # whose access token was issued for this address and no '
        'other. An app',
      )
      ..writeln(
        '        # without the binding declares no such ARG and Docker drops '
        'it.',
      )
      ..writeln('        STUDIO_APP_ORIGIN: ${_q(stack.appOrigin)}')
      ..writeln('    restart: unless-stopped')
      ..writeln('    expose:')
      ..writeln('      - "80"')
      ..writeln('    healthcheck:')
      ..writeln(
        '      test: ["CMD", "wget", "-q", "-O", "/dev/null", '
        '"http://127.0.0.1/"]',
      )
      ..writeln('      interval: 10s')
      ..writeln('      timeout: 5s')
      ..writeln('      retries: 3')
      ..writeln();

    // --- storage
    if (storage) {
      buffer
        ..writeln('  ${DwStack.storageService}:')
        ..writeln('    image: ${_q(_image(DwStack.storageImage))}')
        ..writeln('    restart: unless-stopped')
        ..writeln('    command: ["/data"]')
        ..writeln('    environment:')
        ..writeln(
          '      RUSTFS_ACCESS_KEY: ${_q(_secret(DwStack.storageAccessKey))}',
        )
        ..writeln(
          '      RUSTFS_SECRET_KEY: ${_q(_secret(DwStack.storageSecretKey))}',
        )
        ..writeln(
          '      # No console on a deployment: nothing here is ever meant to '
          'be browsed by',
        )
        ..writeln(
          '      # a person, and the port is not published even with it on '
          '— belt and braces.',
        )
        ..writeln('      RUSTFS_CONSOLE_ENABLE: "false"')
        ..writeln('    volumes:')
        ..writeln('      - ${_q('${DwStack.storageDataVolume}:/data')}')
        ..writeln('    expose:')
        ..writeln('      - "9000"')
        ..writeln('    healthcheck:')
        ..writeln(
          '      test: ["CMD", "curl", "-fsS", "-o", "/dev/null", '
          '"http://127.0.0.1:9000/health"]',
        )
        ..writeln('      interval: 5s')
        ..writeln('      timeout: 5s')
        ..writeln('      retries: 30')
        ..writeln()
        ..writeln('  ${DwStack.storageInitService}:')
        ..writeln('    image: ${_q(_image(DwStack.storageInitImage))}')
        ..writeln('    restart: "no"')
        ..writeln('    depends_on:')
        ..writeln('      ${DwStack.storageService}:')
        ..writeln('        condition: service_healthy')
        ..writeln('    environment:')
        ..writeln(
          '      AWS_ACCESS_KEY_ID: ${_q(_secret(DwStack.storageAccessKey))}',
        )
        ..writeln(
          '      AWS_SECRET_ACCESS_KEY: '
          '${_q(_secret(DwStack.storageSecretKey))}',
        )
        ..writeln('      AWS_DEFAULT_REGION: "us-east-1"')
        ..writeln('    entrypoint: ["/bin/sh", "-c"]')
        ..writeln(
          '    # Idempotent: an existing bucket is kept, objects and all, and '
          'its access is',
        )
        ..writeln(
          '    # set again on every deploy — the public bucket reads objects '
          'to anyone and',
        )
        ..writeln(
          '    # lists to no one, the private one reads nothing unsigned; the '
          'CORS rule is',
        )
        ..writeln(
          '    # what a browser needs for a presigned PUT from the app, on '
          'both buckets.',
        )
        ..writeln(
          '    # The probe object in each is what the outside check reads '
          'without credentials.',
        )
        ..writeln('    command:')
        ..writeln('      - ${_q(_storageInit)}')
        ..writeln();
    }

    // --- nginx
    buffer
      ..writeln('  ${DwStack.nginxService}:')
      ..writeln('    image: ${_q(_image(DwStack.nginxImage))}')
      ..writeln('    restart: unless-stopped')
      ..writeln('    ports:');
    switch (stack.front) {
      case DwTlsFront():
        buffer
          ..writeln('      - "80:80"')
          ..writeln('      - "443:443"');
      case DwPlainHttpFront(:final port):
        buffer.writeln('      - ${_q('127.0.0.1:$port:$port')}');
    }
    buffer
      ..writeln('    volumes:')
      ..writeln('      - "./nginx.conf:/etc/nginx/conf.d/default.conf:ro"')
      ..writeln('      - "./nginx.d:/etc/nginx/dartway:ro"');
    if (_tls) {
      buffer
        ..writeln('      - "certbot_data:/etc/letsencrypt:ro"')
        ..writeln('      - "certbot_www:/var/www/certbot:ro"');
    }
    if (site != null && site.deployed) {
      buffer.writeln('      - ${_q('${_context(site.source!)}:/srv/site:ro')}');
    }
    buffer
      ..writeln('    depends_on:')
      ..writeln('      - ${DwStack.serverService}')
      ..writeln('      - ${DwStack.webService}');
    if (storage) {
      buffer
        ..writeln('      - ${DwStack.storageService}')
        ..writeln(
          '    # The server reaches storage by the same URL a browser signs '
          'for: inside',
        )
        ..writeln(
          '    # the network that host is this proxy, so there is no second '
          'address to',
        )
        ..writeln('    # configure and no hairpin through the public IP.')
        ..writeln('    networks:')
        ..writeln('      default:')
        ..writeln('        aliases:')
        ..writeln('          - ${_q(_target.storageDomain!)}');
    }
    buffer.writeln();

    // --- certbot
    if (_tls) {
      buffer
        ..writeln('  ${DwStack.certbotService}:')
        ..writeln('    image: ${_q(_image(DwStack.certbotImage))}')
        ..writeln('    restart: unless-stopped')
        ..writeln('    volumes:')
        ..writeln('      - "certbot_data:/etc/letsencrypt"')
        ..writeln('      - "certbot_www:/var/www/certbot"')
        ..writeln('    entrypoint: /bin/sh')
        ..writeln('    command:')
        ..writeln('      - -c')
        ..writeln(
          r'      # $$ is how Compose passes a literal dollar down instead of '
          'substituting a variable.',
        )
        ..writeln(
          r'      - "trap exit TERM; while :; do certbot renew --webroot -w '
          r'/var/www/certbot; sleep 12h & wait $${!}; done"',
        )
        ..writeln();
    }

    buffer
      ..writeln('volumes:')
      ..writeln('  ${DwStack.postgresDataVolume}:');
    if (storage) buffer.writeln('  ${DwStack.storageDataVolume}:');
    if (_tls) {
      buffer
        ..writeln('  certbot_data:')
        ..writeln('  certbot_www:');
    }
    return buffer.toString();
  }

  /// The script of `storage-init`: both buckets, their access and CORS, and
  /// the probe object in each.
  ///
  /// A generic S3 client (`amazon/aws-cli`, [DwStack.storageInitImage]) rather
  /// than the storage's own: RustFS ships no client of its own that speaks
  /// bucket policy and CORS the way this needs, and `aws` reads its
  /// credentials straight from `AWS_ACCESS_KEY_ID`/`AWS_SECRET_ACCESS_KEY`, so
  /// nothing here has to quote or escape the secret store's values for a
  /// shell, the way setting up a named alias used to (#331).
  ///
  /// The public policy is the framework's (`DwFileStorageSetup`): anonymous
  /// `s3:GetObject` and nothing else — never a canned ACL, which would also
  /// grant `s3:ListBucket` and let anyone enumerate every public file.
  String get _storageInit {
    final public = stack.publicBucketName;
    final private = stack.privateBucketName;
    final endpoint = 'http://${DwStack.storageService}:9000';
    final policy = jsonEncode({
      'Version': '2012-10-17',
      'Statement': [
        {
          'Sid': 'DartWayPublicRead',
          'Effect': 'Allow',
          'Principal': {
            'AWS': ['*'],
          },
          'Action': ['s3:GetObject'],
          'Resource': ['arn:aws:s3:::$public/*'],
        },
      ],
    });
    final cors = jsonEncode({
      'CORSRules': [
        {
          'AllowedOrigins': [stack.appOrigin],
          'AllowedMethods': ['GET', 'PUT'],
          'AllowedHeaders': ['*'],
          'MaxAgeSeconds': 3000,
        },
      ],
    });
    String aws(String rest) => 'aws --endpoint-url $endpoint $rest';
    return [
      'set -e',
      for (final bucket in [public, private]) aws('s3 mb s3://$bucket'),
      "printf '%s' '$policy' > /tmp/dw-public-read.json",
      aws(
        's3api put-bucket-policy --bucket $public '
        '--policy file:///tmp/dw-public-read.json',
      ),
      aws('s3api delete-bucket-policy --bucket $private'),
      "printf '%s' '$cors' > /tmp/dw-cors.json",
      for (final bucket in [public, private])
        aws(
          's3api put-bucket-cors --bucket $bucket '
          '--cors-configuration file:///tmp/dw-cors.json',
        ),
      for (final bucket in [public, private])
        "printf '%s\\n' '${DwStack.visibilityProbeText}' "
            '| ${aws('s3 cp - s3://$bucket/${DwStack.visibilityProbeKey}')} '
            '>/dev/null',
      'echo "bucket $public reads objects anonymously, bucket $private does '
          'not"',
    ].join('; ');
  }

  /// The largest request body the proxy accepts on the server's hosts.
  ///
  /// Above the server's own default limit (1 MiB) on purpose: the server
  /// refuses an oversized call with its own answer, which a client reads, while
  /// a refusal here would be an nginx HTML page no client can decode. Uploads
  /// never come this way — they go to storage directly (D-034) — so a call body
  /// past this is a mistake, not a use case; a project that means it raises
  /// the limit in a `nginx.d/app` or `nginx.d/api` snippet.
  static const String bodyLimit = '16m';

  /// Where the certificate of every served host lives. One lineage, named
  /// after the API host.
  String get _certificateDirectory =>
      '/etc/letsencrypt/live/${_target.apiDomain}';

  String get nginxFile {
    final buffer = StringBuffer()
      ..writeln(
        '# Rendered by "dartway deploy setup" from deploy/config.yaml '
        '[${_target.environment}].',
      )
      ..writeln(
        '# Project additions belong in deploy/nginx.d/{http,api,app}/*.conf.',
      )
      ..writeln()
      ..writeln(
        '# Connection: upgrade only on a real upgrade; close for an ordinary '
        'request.',
      )
      ..writeln(r'map $http_upgrade $connection_upgrade {')
      ..writeln('    default upgrade;')
      ..writeln('    ""      close;')
      ..writeln('}')
      ..writeln()
      ..writeln('include /etc/nginx/dartway/http/*.conf;')
      ..writeln();

    final servedNames = _target.servedDomains.join(' ');
    if (_tls) {
      buffer
        ..writeln('server {')
        ..writeln('    listen 80;')
        ..writeln('    server_name $servedNames;')
        ..writeln()
        ..writeln('    location /.well-known/acme-challenge/ {')
        ..writeln('        root /var/www/certbot;')
        ..writeln('    }')
        ..writeln()
        ..writeln('    location / {')
        ..writeln(r'        return 301 https://$host$request_uri;')
        ..writeln('    }')
        ..writeln('}')
        ..writeln();
    }

    // --- app
    _openServer(buffer, _target.appDomain);
    buffer
      ..writeln('    client_max_body_size $bodyLimit;')
      ..writeln()
      ..writeln(
        '    # Caching of the app is decided inside the web image and passed '
        'through.',
      )
      ..writeln(
        '    # Do not add an `expires` in a snippet: a Flutter build reuses '
        'every file',
      )
      ..writeln(
        '    # name, so it would freeze the files every deploy changes.',
      )
      ..writeln('    include /etc/nginx/dartway/app/*.conf;')
      ..writeln()
      ..writeln(
        '    # The live socket: an upgrade, and a connection that stays open '
        'far longer',
      )
      ..writeln(
        '    # than a call. The server pings every 20 s; the timeout only ends '
        'a dead one.',
      )
      ..writeln('    location = /dw/live {');
    _live(buffer);
    buffer
      ..writeln('    }')
      ..writeln()
      ..writeln('    # Calls, on the app\'s own origin: no CORS, no preflight.')
      ..writeln('    location /dw/ {');
    _proxy(buffer);
    buffer
      ..writeln('    }')
      ..writeln()
      ..writeln('    location = /health {');
    _proxy(buffer);
    buffer
      ..writeln('    }')
      ..writeln()
      ..writeln('    location / {')
      ..writeln('        proxy_pass http://${DwStack.webService}:80;')
      ..writeln(r'        proxy_set_header Host $http_host;')
      ..writeln(r'        proxy_set_header X-Forwarded-Proto $scheme;')
      ..writeln('    }')
      ..writeln('}')
      ..writeln();

    // --- api
    _openServer(buffer, _target.apiDomain);
    buffer
      ..writeln('    client_max_body_size $bodyLimit;')
      ..writeln()
      ..writeln('    location = /dw/live {');
    _live(buffer);
    buffer
      ..writeln('    }')
      ..writeln()
      ..writeln('    location / {')
      ..writeln(
        '        # Inside the location: what a project adds here — a '
        'webhook\'s longer',
      )
      ..writeln(
        '        # timeout, a header — only has an effect on the proxied '
        'request itself.',
      )
      ..writeln('        include /etc/nginx/dartway/api/*.conf;');
    _proxy(buffer);
    buffer
      ..writeln('    }')
      ..writeln('}')
      ..writeln();

    // --- site
    final site = _target.site;
    if (site != null && site.deployed) {
      _openServer(buffer, site.domain);
      buffer
        ..writeln('    root /srv/site;')
        ..writeln('    index index.html;')
        ..writeln('    etag on;')
        ..writeln()
        ..writeln(
          '    # Static files served from the checkout as the deployed '
          'revision has them.',
        )
        ..writeln(
          '    # Revalidated, because nothing here knows which names carry a '
          'content hash.',
        )
        ..writeln('    location / {')
        ..writeln(r'        try_files $uri $uri/ =404;')
        ..writeln('        add_header Cache-Control "no-cache";')
        ..writeln('    }')
        ..writeln('}')
        ..writeln();
    }

    // --- storage
    if (_target.storage == DwStorageMode.bundled) {
      _openServer(buffer, _target.storageDomain!);
      buffer
        ..writeln(
          '    # Browsers upload here directly. The presigned URL bounds the '
          'size, so the',
        )
        ..writeln(
          '    # proxy does not, and streams the body instead of spooling it '
          'to disk.',
        )
        ..writeln('    client_max_body_size 0;')
        ..writeln('    proxy_request_buffering off;')
        ..writeln('    proxy_buffering off;')
        ..writeln()
        ..writeln('    location / {')
        ..writeln('        proxy_pass http://${DwStack.storageService}:9000;')
        ..writeln('        proxy_http_version 1.1;')
        ..writeln(r'        proxy_set_header Connection "";')
        ..writeln(
          '        # The signature covers the host exactly as the client '
          'sent it, port included.',
        )
        ..writeln(r'        proxy_set_header Host $http_host;')
        ..writeln(r'        proxy_set_header X-Real-IP $remote_addr;')
        ..writeln(
          r'        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;',
        )
        ..writeln(r'        proxy_set_header X-Forwarded-Proto $scheme;')
        ..writeln('    }')
        ..writeln('}')
        ..writeln();
    }

    return buffer.toString();
  }

  void _openServer(StringBuffer buffer, String domain) {
    buffer.writeln('server {');
    switch (stack.front) {
      case DwTlsFront():
        buffer
          ..writeln('    listen 443 ssl;')
          ..writeln('    server_name $domain;')
          ..writeln(
            '    ssl_certificate     $_certificateDirectory/fullchain.pem;',
          )
          ..writeln(
            '    ssl_certificate_key $_certificateDirectory/privkey.pem;',
          );
      case DwPlainHttpFront(:final port):
        buffer
          ..writeln('    listen $port;')
          ..writeln('    server_name $domain;');
    }
    buffer.writeln();
  }

  /// Headers of a proxied request to the server.
  ///
  /// `Host` is `$http_host`, port included: the live socket admits a browser
  /// whose `Origin` is the host the upgrade was sent to, and an origin carries
  /// its port.
  static void _proxy(StringBuffer buffer) {
    buffer
      ..writeln(
        '        proxy_pass http://${DwStack.serverService}:${DwStack.serverPort};',
      )
      ..writeln('        proxy_http_version 1.1;')
      ..writeln(r'        proxy_set_header Upgrade $http_upgrade;')
      ..writeln(r'        proxy_set_header Connection $connection_upgrade;')
      ..writeln(r'        proxy_set_header Host $http_host;')
      ..writeln(r'        proxy_set_header X-Real-IP $remote_addr;')
      ..writeln(
        r'        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;',
      )
      ..writeln(r'        proxy_set_header X-Forwarded-Proto $scheme;');
  }

  static void _live(StringBuffer buffer) {
    _proxy(buffer);
    buffer
      ..writeln('        proxy_read_timeout 1h;')
      ..writeln('        proxy_send_timeout 1h;')
      ..writeln('        proxy_buffering off;');
  }

  File? get composeOverride {
    final root = projectRoot;
    if (root == null) return null;
    final file = File(p.join(root.path, 'deploy', 'compose.override.yml'));
    return file.existsSync() ? file : null;
  }

  /// Extra Nginx snippets, keyed by their path under `deploy/nginx.d/`.
  Map<String, File> get nginxSnippets {
    final root = projectRoot;
    if (root == null) return const {};
    final dir = Directory(p.join(root.path, 'deploy', 'nginx.d'));
    if (!dir.existsSync()) {
      return const {};
    }
    final snippets = <String, File>{};
    for (final entity in dir.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.conf')) {
        continue;
      }
      final relative = p
          .relative(entity.path, from: dir.path)
          .replaceAll(r'\', '/');
      snippets[relative] = entity;
    }
    return snippets;
  }
}
