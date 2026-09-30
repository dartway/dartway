import 'package:dartway_core_server/dartway_core_server.dart';
import 'package:dartway_starter_server/src/core/files.dart';

/// Everything the server is configured with, read once as it starts: the
/// framework's variables and the app's own, typed.
///
/// The one place in the package that reads the environment — a
/// `Platform.environment` anywhere else in `lib/` is an error of
/// `dartway check`. Every variable is read here, at start, so a deploy
/// missing three hears about all three at once instead of one per first use:
/// `DwEnvironmentReader.read` throws `DwEnvironmentException` listing every
/// missing and malformed value, and never repeats a secret.
///
/// A variable of the app's own is a field of a sub-config, named after what
/// it configures, and read in [read]:
///
/// ```dart
/// final class AppSmsEnvironment {
///   const AppSmsEnvironment({required this.login, required this.password});
///
///   final String login;
///   final String password;
/// }
///
/// // in read():
/// sms: AppSmsEnvironment(
///   login: read.required('SMS_LOGIN'),
///   password: read.required('SMS_PASSWORD'),
/// ),
/// ```
///
/// A value the server cannot start without also belongs under
/// `requires.secrets` in `deploy/config.yaml`, so a deployment missing it
/// refuses to begin. `bin/server.dart` hands a sub-config to
/// `DartwayStarterServer.build`, which gives it to what uses it — a test
/// builds the server with values of its own.
final class AppEnvironment {
  const AppEnvironment({required this.server});

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
        ),
      );

  /// The framework's variables: the database, the file storage, the port,
  /// the browser origins (`DwServerEnvironment`).
  final DwServerEnvironment server;
}
