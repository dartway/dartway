/// Keys DartWay reads from the server's `passwords.yaml`.
///
/// The values are the literal key names an app writes in that file — renaming
/// one breaks every deployment that already has it.
class DwConfigurationKeys {
  static const dwCloudStorageRegion = 'dwCloudStorageRegion';
  static const dwCloudStorageEndpoint = 'dwCloudStorageEndpoint';
  static const dwCloudStoragePort = 'dwCloudStoragePort';
  static const dwCloudStorageUseSSL = 'dwCloudStorageUseSSL';
  static const dwCloudStorageAccessKey = 'dwCloudStorageAccessKey';
  static const dwCloudStorageSecretKey = 'dwCloudStorageSecretKey';
  static const dwCloudStorageBucket = 'dwCloudStorageBucket';

  static const dwAuthKeySaltKey = 'dwAuthKeySalt';
  static const dwVerificationCodeSaltKey = 'dwVerificationCodeSalt';
}
