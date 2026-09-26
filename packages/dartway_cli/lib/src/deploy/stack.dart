import 'deploy_target.dart';

/// How the front proxy meets the outside world.
sealed class DwFrontMode {
  const DwFrontMode();

  /// Scheme of every public URL.
  String get scheme;

  /// The port in a public URL, or null when it is the scheme's default.
  int? get publicPort;
}

/// A real server: TLS on 443, plain HTTP on 80 only for the ACME challenge and
/// a redirect.
final class DwTlsFront extends DwFrontMode {
  const DwTlsFront();

  @override
  String get scheme => 'https';

  @override
  int? get publicPort => null;
}

/// Plain HTTP on one loopback port, for proving a rendered stack on a
/// development machine where no certificate can be issued.
///
/// The proxy listens on the same port inside the network as outside it. A
/// presigned storage URL signs its host *with* the port, and the server reaches
/// storage by that very URL through a network alias of the proxy — so the port
/// has to mean the same thing on both sides, exactly as 443 does in production.
final class DwPlainHttpFront extends DwFrontMode {
  const DwPlainHttpFront(this.port);

  final int port;

  @override
  String get scheme => 'http';

  @override
  int? get publicPort => port;
}

/// Everything the rendered stack derives from an environment and a project:
/// names, the server's environment, and which secrets it cannot start without.
///
/// One place, because each of these facts is read by more than one party — the
/// renderer, the secret store, the deploy steps and the checks — and a fact
/// computed twice is two facts that agree by coincidence.
class DwStack {
  DwStack({
    required this.target,
    required this.serverPackage,
    required this.flutterPackage,
    this.front = const DwTlsFront(),
  });

  final DwDeployTarget target;
  final String serverPackage;
  final String flutterPackage;
  final DwFrontMode front;

  /// The one port the server listens on inside the network. Never published:
  /// the proxy is the only way in.
  static const int serverPort = 8080;

  static const String serverService = 'server';
  static const String webService = 'web';
  static const String postgresService = 'postgres';
  static const String storageService = 'storage';
  static const String storageInitService = 'storage-init';
  static const String nginxService = 'nginx';
  static const String certbotService = 'certbot';

  /// The volume Compose names in the rendered `volumes:` key — read here and
  /// nowhere else, so the renderer's compose file and [dataVolumeNames] (what
  /// `checkDataVolumes` looks for on the server) can never name it two
  /// different ways.
  static const String postgresDataVolume = 'postgres_data';
  static const String storageDataVolume = 'storage_data';

  /// Data-bearing images are pinned: a moved tag under a volume is a data
  /// directory the new binary may refuse, and that is not a failure a deploy
  /// should be able to cause by running on a later day. Postgres 17 is pinned
  /// to its major, which is what its on-disk format follows.
  static const String postgresImage = 'postgres:17-alpine';

  /// The bundled storage. Pinned for the same reason as Postgres above, and
  /// because it is the second time this stack has pinned a storage image for
  /// that reason (D-094, dartway/dartway#331): the previous one stopped
  /// publishing images, and every registry that used to serve them answered
  /// an anonymous pull with 401. RustFS is Apache-2.0 and pulls anonymously
  /// from Docker Hub.
  static const String storageImage = 'rustfs/rustfs:1.0.0';

  /// Creates both buckets and sets their access on every deploy —
  /// [storageInitService]'s image. Not RustFS's own client (it does not ship
  /// one that speaks bucket policy and CORS the way the framework needs); a
  /// generic, pinned S3 client instead.
  static const String storageInitImage = 'amazon/aws-cli:2.31.13';

  /// Pinned too, though stateless: a redeploy weeks later must not pull a
  /// different proxy and call the regression "the deploy broke", and a
  /// client's list of third-party software needs a version, not "latest as
  /// of that day" (#269). nginx on its stable line; both raised deliberately,
  /// with a framework release that says so.
  static const String nginxImage = 'nginx:1.30.5-alpine';
  static const String certbotImage = 'certbot/certbot:v5.8.0';

  /// Whether `registry_mirror` can serve [image]: an official Docker Hub image
  /// (`postgres`, `nginx`) — what `mirror.gcr.io` and a Hub library cache
  /// hold. An image of another registry or of a Hub organisation is pulled
  /// from where it lives; prefixed with the mirror it would name nothing.
  static bool mirrorServes(String image) =>
      !image.split(':').first.contains('/');

  /// [image] as the renderer and every check that pulls it resolve it:
  /// through `registry_mirror` when the mirror can serve it (see
  /// [mirrorServes]). One function, so a diagnostic pull (the
  /// `database-reachable` check's one-off Postgres client) asks the same
  /// registry `deploy run` would.
  String resolvedImage(String image) => switch (target.registryMirror) {
    final mirror? when mirrorServes(image) => '$mirror/$image',
    _ => image,
  };

  /// Turns a server start into a one-off migration that serves nothing — the
  /// name `DwAppServer.migrateOnlyVariable` reads in `dartway_core_server`.
  static const String migrateOnlyVariable = 'DW_MIGRATE_ONLY';

  /// The mount point of `requires.files` inside the server container.
  static const String secretFilesDir = '/run/secrets';

  /// The rendered environment file, beside the compose file in the checkout.
  static const String envFile = '.env';

  /// `DW_DATABASE_*` — generated for the bundled Postgres, delivered for an
  /// external one (`database: external`); see [serverEnvironment] and
  /// [requiredSecretKeys].
  static const String databaseHostKey = 'DW_DATABASE_HOST';
  static const String databasePortKey = 'DW_DATABASE_PORT';
  static const String databaseNameKey = 'DW_DATABASE_NAME';
  static const String databaseUserKey = 'DW_DATABASE_USER';
  static const String databasePasswordKey = 'DW_DATABASE_PASSWORD';

  /// Optional even with `database: external` — the server defaults SSL to
  /// `true` (`SslMode.require`) and the pool to 10 connections.
  static const String databaseSslKey = 'DW_DATABASE_SSL';
  static const String databaseMaxConnectionsKey = 'DW_DATABASE_MAX_CONNECTIONS';
  static const String storageEndpointKey = 'DW_STORAGE_ENDPOINT';
  static const String storagePublicBucketKey = 'DW_STORAGE_PUBLIC_BUCKET';
  static const String storagePublicBaseUrlKey = 'DW_STORAGE_PUBLIC_BASE_URL';
  static const String storagePrivateBucketKey = 'DW_STORAGE_PRIVATE_BUCKET';
  static const String storageVerifyBucketsKey = 'DW_STORAGE_VERIFY_BUCKETS';
  static const String storageAccessKey = 'DW_STORAGE_ACCESS_KEY';
  static const String storageSecretKey = 'DW_STORAGE_SECRET_KEY';

  /// The project prefix: the server package without `_server`.
  String get projectPrefix => serverPackage.endsWith('_server')
      ? serverPackage.substring(0, serverPackage.length - '_server'.length)
      : serverPackage;

  /// Database and role name of the bundled Postgres. The package prefix is
  /// already a Dart identifier, which is what Postgres wants of an unquoted
  /// one. An external database names both through `DW_DATABASE_NAME` and
  /// `DW_DATABASE_USER` in the secret store instead — a managed provider
  /// assigns its own.
  String get databaseName => projectPrefix;

  /// The public bucket — objects readable by anyone, listing by no one: the
  /// prefix with dashes, which is what a bucket name allows, and `-public`.
  String get publicBucketName => '${projectPrefix.replaceAll('_', '-')}-public';

  /// The private bucket — nothing readable without a signature.
  String get privateBucketName =>
      '${projectPrefix.replaceAll('_', '-')}-private';

  /// The object `storage-init` writes into both buckets, and the outside
  /// probe reads without credentials: the key and text the server's own
  /// startup check uses (`_dartway/visibility-probe`).
  static const String visibilityProbeKey = '_dartway/visibility-probe';
  static const String visibilityProbeText =
      'DartWay checks at startup that this bucket is exactly as public as it '
      'is declared.';

  /// Where public files are read: the public bucket on the storage host,
  /// path-style.
  String? get publicBaseUrl => switch (storageOrigin) {
    final origin? => '$origin/$publicBucketName',
    null => null,
  };

  /// The public URL of [domain] under [front].
  String originOf(String domain) {
    final port = front.publicPort;
    return '${front.scheme}://$domain${port == null ? '' : ':$port'}';
  }

  String get appOrigin => originOf(target.appDomain);
  String get apiOrigin => originOf(target.apiDomain);

  String? get storageOrigin => switch (target.storageDomain) {
    final domain? => originOf(domain),
    null => null,
  };

  String? get siteOrigin => switch (target.site) {
    final site? when site.deployed => originOf(site.domain),
    _ => null,
  };

  /// The server's environment that is derived rather than secret. Rendered
  /// into the compose file, where it is readable and overrides anything of the
  /// same name in `.env` — which is why the secret store refuses these names.
  ///
  /// With `database: external` nothing about the database is derived at all:
  /// `DW_DATABASE_HOST/PORT/NAME/USER/PASSWORD` are delivered secrets, read
  /// from `.env` exactly as the server would read them from any other
  /// environment — a managed provider names its own host, port, database and
  /// role, so there is nothing here to derive them from.
  Map<String, String> get serverEnvironment => {
    'PORT': '$serverPort',
    if (target.database == DwDatabaseMode.bundled) ...{
      databaseHostKey: postgresService,
      databasePortKey: '5432',
      databaseNameKey: databaseName,
      databaseUserKey: databaseName,
      // The database is a container on the stack's private network, and the
      // image serves no TLS; the driver requires it unless told otherwise.
      databaseSslKey: 'false',
    },
    if (target.storage == DwStorageMode.bundled) ...{
      storageEndpointKey: storageOrigin!,
      storagePublicBucketKey: publicBucketName,
      storagePublicBaseUrlKey: publicBaseUrl!,
      storagePrivateBucketKey: privateBucketName,
      'DW_STORAGE_REGION': 'us-east-1',
      'DW_STORAGE_PATH_STYLE': 'true',
      // The server reaches this storage only through the proxy's storage
      // host, and the proxy starts after the server — on a first deploy it
      // does not exist yet, and its certificate even less. So the server does
      // not check its buckets while it starts: `storage-init` sets their
      // access on every deploy, and the outside probe reads both without
      // credentials once the stack is up.
      storageVerifyBucketsKey: 'false',
    },
  };

  /// Every base image this stack pulls rather than builds, labelled for a
  /// report and resolved through [target]'s `registry_mirror` exactly as the
  /// renderer resolves them into the compose file (see [mirrorServes]): what
  /// `deploy check` asks a registry to resolve is what `deploy run` actually
  /// pulls, not the upstream name behind a mirror that serves it instead
  /// (#331).
  List<(String, String)> get pinnedImages => [
    if (target.database == DwDatabaseMode.bundled)
      ('Postgres', resolvedImage(postgresImage)),
    ('nginx', resolvedImage(nginxImage)),
    if (front is DwTlsFront) ('certbot', resolvedImage(certbotImage)),
    if (target.storage == DwStorageMode.bundled) ...[
      ('storage', resolvedImage(storageImage)),
      ('storage-init', resolvedImage(storageInitImage)),
    ],
  ];

  /// The data volumes this stack's compose file declares — the ones a
  /// restart must never start empty, because Postgres and the bundled
  /// storage keep their whole state on them and nowhere else. Certbot's own
  /// volumes are deliberately not here: a lineage reissues itself, so losing
  /// it costs a certificate request, not data.
  ///
  /// Named with the compose project's prefix already applied
  /// ([DwDeployTarget.projectName] — the checkout directory's name, which is
  /// what Compose derives its volume names from), because that is the form
  /// `docker volume ls` answers in and the form [checkDataVolumes] compares
  /// against.
  Set<String> get dataVolumeNames => {
    if (target.database == DwDatabaseMode.bundled)
      '${target.projectName}_$postgresDataVolume',
    if (target.storage == DwStorageMode.bundled)
      '${target.projectName}_$storageDataVolume',
  };

  /// Names the store must not hold, because the compose file sets them.
  Set<String> get reservedSecretKeys => serverEnvironment.keys.toSet();

  /// Secrets generated on the server, with their length in random bytes.
  ///
  /// Random strings nobody issues: generating them in place means the value
  /// never exists anywhere but the server that uses it. An external
  /// database's password is not among them — it is a managed provider's
  /// credential, delivered with `dartway secret set`, never invented here.
  Map<String, int> get generatedSecrets => {
    if (target.database == DwDatabaseMode.bundled) databasePasswordKey: 32,
    if (target.storage == DwStorageMode.bundled) ...{
      // Hex keeps the generated key within the characters every S3 client
      // accepts, and within what RustFS takes as an access key.
      storageAccessKey: 10,
      storageSecretKey: 32,
    },
  };

  /// Every secret the stack cannot start without, generated or delivered.
  List<String> get requiredSecretKeys => {
    ...generatedSecrets.keys,
    // An external database's coordinates are a managed provider's own — host,
    // port, database and role name all differ from what the bundled
    // container would derive — so every one of them is delivered rather than
    // rendered. DW_DATABASE_SSL (default true) and _MAX_CONNECTIONS (default
    // 10) stay optional: the server already defaults both sensibly.
    if (target.database == DwDatabaseMode.external) ...[
      databaseHostKey,
      databasePortKey,
      databaseNameKey,
      databaseUserKey,
      databasePasswordKey,
    ],
    // Which buckets an external storage needs is the project's rules'
    // business — DW_STORAGE_PUBLIC_BUCKET with _PUBLIC_BASE_URL for public
    // purposes, DW_STORAGE_PRIVATE_BUCKET for private ones — and the server
    // names a missing one when it starts.
    if (target.storage == DwStorageMode.external) ...[
      storageEndpointKey,
      storageAccessKey,
      storageSecretKey,
    ],
    ...target.requiredSecrets,
  }.toList();
}
