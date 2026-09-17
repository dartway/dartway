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
  static const String minioService = 'minio';
  static const String minioInitService = 'minio-init';
  static const String nginxService = 'nginx';
  static const String certbotService = 'certbot';

  /// Data-bearing images are pinned: a moved tag under a volume is a data
  /// directory the new binary may refuse, and that is not a failure a deploy
  /// should be able to cause by running on a later day. Postgres 17 is pinned
  /// to its major, which is what its on-disk format follows.
  static const String postgresImage = 'postgres:17-alpine';

  /// MinIO's community edition stopped publishing images after this release,
  /// so an unpinned tag names nothing that will ever change — pinned to say so.
  /// From quay.io: MinIO removed its repositories from Docker Hub, and a
  /// deploy pinned there fails at the pull.
  static const String minioImage =
      'quay.io/minio/minio:RELEASE.2025-09-07T16-13-09Z';
  static const String minioClientImage =
      'quay.io/minio/mc:RELEASE.2025-08-13T08-35-41Z';

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

  /// Turns a server start into a one-off migration that serves nothing — the
  /// name `DwAppServer.migrateOnlyVariable` reads in `dartway_core_server`.
  static const String migrateOnlyVariable = 'DW_MIGRATE_ONLY';

  /// The mount point of `requires.files` inside the server container.
  static const String secretFilesDir = '/run/secrets';

  /// The rendered environment file, beside the compose file in the checkout.
  static const String envFile = '.env';

  /// The one generated database secret.
  static const String databasePasswordKey = 'DW_DATABASE_PASSWORD';
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

  /// Database and role name. The package prefix is already a Dart identifier,
  /// which is what Postgres wants of an unquoted one.
  String get databaseName => projectPrefix;

  /// The public bucket — objects readable by anyone, listing by no one: the
  /// prefix with dashes, which is what a bucket name allows, and `-public`.
  String get publicBucketName => '${projectPrefix.replaceAll('_', '-')}-public';

  /// The private bucket — nothing readable without a signature.
  String get privateBucketName =>
      '${projectPrefix.replaceAll('_', '-')}-private';

  /// The object `minio-init` writes into both buckets, and the outside probe
  /// reads without credentials: the key and text the server's own startup
  /// check uses (`_dartway/visibility-probe`).
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
  Map<String, String> get serverEnvironment => {
    'PORT': '$serverPort',
    'DW_DATABASE_HOST': postgresService,
    'DW_DATABASE_PORT': '5432',
    'DW_DATABASE_NAME': databaseName,
    'DW_DATABASE_USER': databaseName,
    // The database is a container on the stack's private network, and the
    // image serves no TLS; the driver requires it unless told otherwise.
    'DW_DATABASE_SSL': 'false',
    if (target.storage == DwStorageMode.minio) ...{
      storageEndpointKey: storageOrigin!,
      storagePublicBucketKey: publicBucketName,
      storagePublicBaseUrlKey: publicBaseUrl!,
      storagePrivateBucketKey: privateBucketName,
      'DW_STORAGE_REGION': 'us-east-1',
      'DW_STORAGE_PATH_STYLE': 'true',
      // The server reaches this MinIO only through the proxy's storage host,
      // and the proxy starts after the server — on a first deploy it does not
      // exist yet, and its certificate even less. So the server does not
      // check its buckets while it starts: `minio-init` sets their access on
      // every deploy, and the outside probe reads both without credentials
      // once the stack is up.
      storageVerifyBucketsKey: 'false',
    },
  };

  /// Names the store must not hold, because the compose file sets them.
  Set<String> get reservedSecretKeys => serverEnvironment.keys.toSet();

  /// Secrets generated on the server, with their length in random bytes.
  ///
  /// Random strings nobody issues: generating them in place means the value
  /// never exists anywhere but the server that uses it.
  Map<String, int> get generatedSecrets => {
    databasePasswordKey: 32,
    if (target.storage == DwStorageMode.minio) ...{
      // MinIO takes the access key as the root user name; hex keeps it within
      // the characters every S3 client accepts.
      storageAccessKey: 10,
      storageSecretKey: 32,
    },
  };

  /// Every secret the stack cannot start without, generated or delivered.
  List<String> get requiredSecretKeys => {
    ...generatedSecrets.keys,
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
