/// This build, as `pubspec.yaml` names it: `<semver>+<build>`.
///
/// Sent to the server on every call; a build below the server's
/// `DW_MIN_APP_BUILD` is shown the "update the app" screen. Written out here
/// because a build cannot read its own pubspec, and kept equal to it by
/// `test/app_version_test.dart`.
const String appBuildVersion = '1.0.0+1';
