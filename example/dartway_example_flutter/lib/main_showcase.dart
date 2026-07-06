import 'dartway_example_app.dart';
import 'showcase/showcase_shell_scope.dart';

/// Showcase target (web): the example app presents itself — the live app in
/// a device frame, zone navigation on top, the screen passport on the right.
/// Run with a seeded local dev backend:
///   flutter run -d chrome -t lib/main_showcase.dart
void main() {
  DartwayExampleApp(
    backendUrl: 'http://localhost:8080/',
    appVersion: 'showcase',
    showcaseShellBuilder: (context, appChild) =>
        ShowcaseShellScope(appChild: appChild),
  ).run();
}
