import 'package:dartway_core_server/dartway_core_server.dart';

import 'files.dart';

/// Everything the club's server is configured with, read once as it starts:
/// the framework's variables and the club's own, typed.
///
/// The one place in the package that reads the environment — a
/// `Platform.environment` anywhere else in `lib/` is an error of
/// `dartway check`. `DwEnvironmentReader.read` stops the start with
/// `DwEnvironmentException`, listing every missing and malformed variable at
/// once and never repeating a secret.
final class AppEnvironment {
  const AppEnvironment({required this.server, required this.push});

  /// [variables] — the process environment, through
  /// `DwLocalEnvironment.overlay` on a developer's machine — read whole.
  static AppEnvironment read(Map<String, String> variables) =>
      DwEnvironmentReader.read(
        variables,
        (read) => AppEnvironment(
          server: DwServerEnvironment.read(
            read,
            defaultPublicBucket: AppFiles.defaultPublicBucket,
            defaultPrivateBucket: AppFiles.defaultPrivateBucket,
          ),
          push: AppPushEnvironment.read(read),
        ),
      );

  /// The framework's variables: the database, the file storage, the port,
  /// the browser origins (`DwServerEnvironment`).
  final DwServerEnvironment server;

  /// The push providers' credentials.
  final AppPushEnvironment push;
}

/// The push providers the environment enables; none without their variables,
/// and then devices are recorded as having no provider (`AppPush.providers`).
final class AppPushEnvironment {
  const AppPushEnvironment({
    this.fcmServiceAccountFile,
    this.fcmWebLinkBase,
    this.ruStore,
  });

  static AppPushEnvironment read(DwEnvironmentReader read) {
    final projectId = read.optional('RUSTORE_PUSH_PROJECT_ID');
    final serviceToken = read.optional('RUSTORE_PUSH_SERVICE_TOKEN');
    if ((projectId == null) != (serviceToken == null)) {
      read.report(
        'RuStore push needs both RUSTORE_PUSH_PROJECT_ID and '
        'RUSTORE_PUSH_SERVICE_TOKEN, or neither',
      );
    }
    final webLinkBase = read.optional('FCM_WEB_LINK_BASE');
    final webLink = webLinkBase == null ? null : Uri.tryParse(webLinkBase);
    if (webLinkBase != null && webLink?.scheme != 'https') {
      read.report('FCM_WEB_LINK_BASE must be an https URL, got "$webLinkBase"');
    }
    return AppPushEnvironment(
      fcmServiceAccountFile: read.optional('FCM_SERVICE_ACCOUNT_FILE'),
      fcmWebLinkBase: webLink,
      ruStore: projectId != null && serviceToken != null
          ? (projectId: projectId, serviceToken: serviceToken)
          : null,
    );
  }

  /// `FCM_SERVICE_ACCOUNT_FILE`: the path of the Firebase service account
  /// JSON file.
  final String? fcmServiceAccountFile;

  /// `FCM_WEB_LINK_BASE`: the web app's https origin, for web clicks.
  final Uri? fcmWebLinkBase;

  /// `RUSTORE_PUSH_PROJECT_ID` and `RUSTORE_PUSH_SERVICE_TOKEN`, both or
  /// neither.
  final ({String projectId, String serviceToken})? ruStore;
}
