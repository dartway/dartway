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
  static const String minioImage = 'minio/minio:RELEASE.2025-09-07T16-13-09Z';
  static const String minioClientImage =
      'minio/mc:RELEASE.2025-08-13T08-35-41Z';

  /// Stateless, and following upstream security fixes is worth more here than
  /// reproducing yesterday's proxy.
  static const String nginxImage = 'nginx:alpine';
  static const String certbotImage = 'certbot/certbot:latest';

  /// The mount point of `requires.files` inside the server container.
  static const String secretFilesDir = '/run/secrets';

  /// The rendered environment file, beside the compose file in the checkout.
  static const String envFile = '.env';

  /// The one generated database secret.
  static const String databasePasswordKey = 'DW_DATABASE_PASSWORD';
  static const String storageEndpointKey = 'DW_STORAGE_ENDPOINT';
  static const String storageBucketKey = 'DW_STORAGE_BUCKET';
  static const String storageAccessKey = 'DW_STORAGE_ACCESS_KEY';
  static const String storageSecretKey = 'DW_STORAGE_SECRET_KEY';

  /// The project prefix: the server package without `_server`.
  String get projectPrefix => serverPackage.endsWith('_server')
      ? serverPackage.substring(0, serverPackage.length - '_server'.length)
      : serverPackage;

  /// Database and role name. The package prefix is already a Dart identifier,
  /// which is what Postgres wants of an unquoted one.
  String get databaseName => projectPrefix;

  /// The bucket: the prefix with dashes, which is what a bucket name allows.
  String get bucketName => projectPrefix.replaceAll('_', '-');

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
      storageBucketKey: bucketName,
      'DW_STORAGE_REGION': 'us-east-1',
      'DW_STORAGE_PATH_STYLE': 'true',
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
    if (target.storage == DwStorageMode.external) ...[
      storageEndpointKey,
      storageBucketKey,
      storageAccessKey,
      storageSecretKey,
    ],
    ...target.requiredSecrets,
  }.toList();
}
