/// This build, as `pubspec.yaml` names it: `<semver>+<build>`.
///
/// Sent to the server on every call, where it labels the session key the
/// app signs in with — whether the app may call is its contract version's
/// question, not the build's. Written out here
/// because a build cannot read its own pubspec, and kept equal to it by
/// `test/app_version_test.dart`.
const String appBuildVersion = '1.0.0+1';
