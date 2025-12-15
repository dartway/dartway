import 'package:dartway_serverpod_core_server/dartway_serverpod_core_server.dart';

class DwCloudStorageConfig {
  final String region;
  final String endPoint;
  final int port;
  final bool useSSL;
  final String accessKey;
  final String secretKey;
  final String bucket;

  DwCloudStorageConfig({
    required this.region,
    required this.endPoint,
    required this.port,
    required this.useSSL,
    required this.accessKey,
    required this.secretKey,
    required this.bucket,
  });

  factory DwCloudStorageConfig.fromEnv(Map<String, String> env) {
    return DwCloudStorageConfig(
      region: env[DwConfigurationKeys.dwCloudStorageRegion]!,
      endPoint: env[DwConfigurationKeys.dwCloudStorageEndpoint]!,
      port: int.parse(env[DwConfigurationKeys.dwCloudStoragePort] ?? '443'),
      useSSL:
          env[DwConfigurationKeys.dwCloudStorageUseSSL]?.toLowerCase() ==
          'true',
      accessKey: env[DwConfigurationKeys.dwCloudStorageAccessKey]!,
      secretKey: env[DwConfigurationKeys.dwCloudStorageSecretKey]!,
      bucket: env[DwConfigurationKeys.dwCloudStorageBucket]!,
    );
  }
}
